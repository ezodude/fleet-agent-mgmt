#!/usr/bin/env python3
# fleet-board live (lead-ux F1, v3): one process, standard library only, run with python3 -I.
# Replaces fleet-board-push.py and panewatch.py. Two inputs, one render path:
#  - the board's source files, watched with kqueue (a change, then a 150 ms settle, counts once);
#  - the Claude panes, one read-only `tmux list-panes -a` every LIVE_POLL s, capture-pane only when a pane moved,
#    went quiet, is new or has an unconfirmed state; classified into $D/live, and every session name into $D/sessions.
# On any change it runs `<board> list`, then `<board> header`, and POSTs to fzf's --listen only the parts that changed.
# Its only tmux calls are list-panes and capture-pane: it never types into a pane or changes any tmux state.
# It writes only under $FLEET_HOME/board-state: view, header, live, sessions, kick, live.log.
# Exit status: 0 when the board, its socket or its fzf is gone (or the socket answers 401: not this board's fzf);
# anything else is a crash, and the board's launch loop starts it again.
# usage: fleet-board-live.py <board script> <unix:PATH|tcp:HOST:PORT> <tick secs> <board bash pid>
#        fleet-board-live.py once        classify every candidate pane once and print it; writes nothing
# env:   FZF_API_KEY, HOME, FLEET_HOME, LIVE_POLL (1), LIVE_SKIP ("fleet-board lead-ux"), LIVE_ONLY (a session prefix, tests)
import os, re, sys, glob, time, shlex, socket, select, resource, subprocess

HOME = os.environ["HOME"]
FLEET = os.environ.get("FLEET_HOME") or os.path.join(HOME, ".fleet-agent-mgmt")
D = os.path.join(FLEET, "board-state")
POLL = float(os.environ.get("LIVE_POLL") or 1)
SKIP = set((os.environ.get("LIVE_SKIP") if os.environ.get("LIVE_SKIP") is not None else "fleet-board lead-ux").split())
ONLY = os.environ.get("LIVE_ONLY", "")
SETTLE = 0.15           # writers often touch a file twice; one change
CONFIRM = min(POLL, 0.5)  # a pending state is re-read this soon; a change needs two readings in a row
BUSY_RECAP = 3.0        # a busy pane that keeps redrawing is re-captured at most this often
UNREAD_AFTER = 30.0     # unreadable this long without a break: state ?
LOG_MAX = 1 << 20
FD_SPARE = 64           # fds kept free for live.log, the sockets and the render's pipes


def raise_fd_limit():
    """tmux sessions here start with ulimit -n 256; one watched path holds one fd. Raise the soft limit."""
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    for want in (8192, 4096, 2048, 1024) + ((hard,) if hard != resource.RLIM_INFINITY else ()):
        if soft >= want:
            break
        if hard != resource.RLIM_INFINITY and want > hard:
            continue
        try:
            resource.setrlimit(resource.RLIMIT_NOFILE, (want, hard))
            break
        except (ValueError, OSError):
            continue
    return resource.getrlimit(resource.RLIMIT_NOFILE)[0]

# ---------------------------------------------------------------- classifier (Claude Code 2.1.x pane layout)
ESC = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][A-Za-z0-9]|\x1b[=>78]")
LEAD_SGR = re.compile(r"^(?:\x1b\[[0-9;]*m)*")
INPUT = "\u276f\u00a0"                  # the input line: ❯ then a no-break space
DIM = "\x1b[2m"                         # a suggested prompt, not typed text
USER_TURN = "\x1b[48;5;255m"            # a past user turn in the scrollback
BUSY = re.compile(r"^\S{1,2} \S+… \((.*\b\d+s\b.*)$")
TIMER = re.compile(r"\b(?:(\d+)h\s*)?(?:(\d+)m\s*)?(\d+)s\b")
IDLE = re.compile(r"^✻ \S+ for [0-9hms ]+ · done (\d\d:\d\d)")
DIALOG = re.compile(r"Do you want to|Enter to select|Esc to cancel|❯ 1\. ")
REPLY = re.compile(r"Reply:\s*(.*)$")


def clean(s, n):
    s = re.sub(r"[\t\r\n·]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:n].rstrip()


def reply_words(rest):
    rest = rest.strip()
    if rest.startswith("`"):
        w = rest[1:].split("`", 1)[0]
    else:
        w = re.split(r"\.\s|\.$|\s·\s|\s—\s", rest)[0]
    return clean(w.replace("`", "").strip(" \"'"), 60)


def classify(raw, height=0):
    """(state, detail, elapsed secs) or None when the frame cannot be read. The input line is looked for on the
    visible screen only (the last <height> lines): a cleared screen leaves old input lines in the history."""
    L = raw.split("\n")
    if L and L[-1] == "":
        L.pop()
    plain = [ESC.sub("", l) for l in L]
    while plain and not plain[-1].strip() and len(L) > 1:   # trailing blank rows of the screen
        if height:
            height -= 1
        L.pop(); plain.pop()
    inp = -1
    lo = max(0, len(L) - height) if height > 0 else 0
    for i in range(len(L) - 1, lo - 1, -1):
        if INPUT in L[i]:
            inp = i
            break
    if inp < 0:
        hits = [l.strip() for l in plain[-25:] if DIALOG.search(l)]
        if hits:
            ask = [h for h in hits if "Do you want to" in h]
            return ("dialog", clean((ask or hits)[0], 40) or "dialog", 0)
        return None
    after = L[inp].split(INPUT, 1)[1]
    text = ESC.sub("", after).strip()
    suggest = text if DIM in LEAD_SGR.match(after).group(0) else ""
    top = inp - 1                      # the rule above the input box
    for l in reversed(plain[max(0, top - 6):max(0, top)]):
        m = BUSY.match(l.strip())
        if m:
            t = TIMER.search(m.group(1))
            secs = 0
            if t:
                secs = int(t.group(1) or 0) * 3600 + int(t.group(2) or 0) * 60 + int(t.group(3))
            return ("busy", "%dm" % (secs // 60) if secs >= 60 else "<1m", secs)
    for i in range(top - 1, max(-1, top - 9), -1):
        m = IDLE.match(plain[i].strip())
        if not m:
            continue
        # the last assistant block: back to the previous turn's boundary, at most 40 lines. A boundary is a typed
        # user turn, an earlier turn's "✻ … done" line, or an input line left in the history by a cleared screen.
        # Without the last two, a Reply: from an earlier turn read as a fresh ask after an untyped turn.
        start = max(0, i - 40)
        for j in range(i - 1, start - 1, -1):
            if (USER_TURN in L[j] and "❯" in plain[j]) or INPUT in L[j] or IDLE.match(plain[j].strip()):
                start = j + 1
                break
        words = ""
        for l in plain[start:i]:
            r = REPLY.search(l)
            if r:
                w = reply_words(r.group(1))
                if w:
                    words = w
        if words:
            return ("waits", words, 0)
        return ("idle", "done " + m.group(1) + (" · suggests " + clean(suggest, 40) if suggest else ""), 0)
    return None


# ---------------------------------------------------------------- tmux, read only
def sh(*a):
    p = subprocess.run(a, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout


CAND = re.compile(r"^\d+\.\d+\.\d+$")


def candidates(rows):
    """every session name, and {session: (pane_id, window_activity)} for one Claude pane per session"""
    names, cands = set(), {}
    for r in rows.splitlines():
        f = r.split("\t")
        if len(f) != 5:
            continue
        s, pid, act, cmd, ht = f
        names.add(s)
        if s in cands or not (cmd in ("claude", "node") or CAND.match(cmd)):
            continue
        if s in SKIP:
            continue
        if ONLY:
            if not s.startswith(ONLY):
                continue
        elif s.startswith("v3test-"):
            continue
        cands[s] = (pid, act, int(ht) if ht.isdigit() else 0)
    return names, cands


def list_panes():
    return sh("tmux", "list-panes", "-a", "-F", "#{session_name}\t#{pane_id}\t#{window_activity}\t#{pane_current_command}\t#{pane_height}")


def capture(pid):
    return sh("tmux", "capture-pane", "-p", "-e", "-t", pid, "-S", "-60")[1]


def write_atomic(path, data):
    tmp = path + ".new"
    with open(tmp, "wb" if isinstance(data, bytes) else "w") as f:
        f.write(data)
    os.replace(tmp, path)


class Panes:
    def __init__(self):
        self.s = {}            # session -> dict
        self.names = None
        self.live_text = None

    def poll(self, now):
        """one list-panes; returns True when $D/live or $D/sessions changed"""
        rc, out = list_panes()
        if rc != 0:
            return False
        names, cands = candidates(out)
        changed = False
        if names != self.names:
            write_atomic(os.path.join(D, "sessions"), "".join(n + "\n" for n in sorted(names)))
            self.names = names
            changed = True
        for s in list(self.s):
            if s not in cands:
                del self.s[s]
        for s, (pid, act, ht) in cands.items():
            st = self.s.get(s)
            new = st is None
            if new:
                st = self.s[s] = {"act": None, "state": None, "detail": None, "since": None,
                                  "pending": None, "unread": None, "cap": 0.0}
            moved = st["act"] != act
            st["act"] = act
            cur = st["state"]
            need = new or moved or (cur == "busy" and not moved) or st["pending"] is not None \
                or (st["unread"] is not None and cur != "?")
            if cur == "busy" and moved and st["pending"] is None and now - st["cap"] < BUSY_RECAP:
                need = False    # busy and still drawing
            if not need:
                continue
            st["cap"] = now
            r = classify(capture(pid), ht)
            if r is None:       # unreadable frame: keep the state; ? after 30 s without a readable one
                if st["unread"] is None:
                    st["unread"] = now
                if now - st["unread"] >= UNREAD_AFTER and cur != "?":
                    st.update(state="?", detail="unreadable", since=int(now), pending=None)
                continue
            st["unread"] = None
            state, detail, secs = r
            if cur is None:     # first reading of a session: nothing to protect
                st.update(state=state, detail=detail, pending=None,
                          since=int(now - secs) if state == "busy" else (int(act) if act.isdigit() else int(now)))
            elif state == cur:
                st.update(detail=detail, pending=None)
            elif st["pending"] == state:
                st.update(state=state, detail=detail, pending=None,
                          since=int(now - secs) if state == "busy" else int(now))
            else:
                st["pending"] = state
        text = "".join("%s\t%s\t%s\t%d\n" % (s, v["state"], v["detail"], v["since"])
                       for s, v in sorted(self.s.items()) if v["state"] is not None)
        if text != self.live_text:
            write_atomic(os.path.join(D, "live"), text)
            self.live_text = text
            changed = True
        return changed

    def pending(self):
        return any(v["pending"] is not None or (v["unread"] is not None and v["state"] != "?") for v in self.s.values())


# ---------------------------------------------------------------- the board's source files, kqueue
def sources():
    c = os.path.join(FLEET, "checks")
    dirs = [c, os.path.join(c, "lead-1"), os.path.join(c, "lead-1", "cards"), os.path.join(c, "lead-1", "reports"),
            os.path.join(FLEET, "shaping")]
    dirs += glob.glob(os.path.join(c, "*", "")) + glob.glob(os.path.join(FLEET, "shaping", "*", ""))
    files = [os.path.join(c, "lead-1", "board.md"), os.path.join(D, "kick")]
    files += glob.glob(os.path.join(c, "*", "STATE.md")) + glob.glob(os.path.join(FLEET, "shaping", "*", "brief.md"))
    # cards last, newest first: past the fd budget the oldest cards are seen only through the cards/ folder and the tick
    cards = glob.glob(os.path.join(c, "lead-1", "cards", "*.md"))
    try:
        cards.sort(key=lambda p: -os.stat(p).st_mtime)
    except OSError:
        pass
    return [p for p in dict.fromkeys(dirs + files + cards) if os.path.exists(p)]


FLAGS = select.KQ_NOTE_WRITE | select.KQ_NOTE_EXTEND | select.KQ_NOTE_DELETE | select.KQ_NOTE_RENAME | select.KQ_NOTE_ATTRIB


class Files:
    def __init__(self, budget):
        self.kq = select.kqueue()
        self.fds = {}
        self.budget = budget
        self.over = 0           # paths left unwatched last rearm (over the fd budget)

    def rearm(self):
        # close and reopen every watch: catches new files and files replaced by an atomic rename
        for fd in self.fds:
            os.close(fd)
        self.fds.clear()
        evs = []
        src = sources()
        self.over = max(0, len(src) - self.budget)
        for p in src[:self.budget]:
            try:
                fd = os.open(p, os.O_RDONLY | getattr(os, "O_EVTONLY", 0x8000))
            except OSError:
                continue
            self.fds[fd] = p
            evs.append(select.kevent(fd, filter=select.KQ_FILTER_VNODE,
                                     flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR, fflags=FLAGS))
        self.kq.control(evs, 0, 0)

    def wait(self, timeout):
        """names of the changed paths, after the settle; empty on timeout"""
        evs = self.kq.control(None, 64, max(0.0, timeout))
        if not evs:
            return set()
        names = {self.name(e) for e in evs}
        end = time.time() + SETTLE
        while True:
            more = self.kq.control(None, 64, max(0.0, end - time.time()))
            if not more:
                break
            names |= {self.name(e) for e in more}
        return names

    def name(self, e):
        return os.path.basename(self.fds.get(e.ident, "?").rstrip("/"))


# ---------------------------------------------------------------- fzf
class Gone(Exception):
    pass


def post(target, key, body):
    b = body.encode()
    try:
        if target.startswith("unix:"):
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(3)
            s.connect(target[5:])
        else:
            h, p = target[4:].rsplit(":", 1)
            s = socket.create_connection((h, int(p)), timeout=3)
    except (ConnectionRefusedError, FileNotFoundError) as e:
        raise Gone(e.__class__.__name__)
    try:
        s.sendall(b"POST / HTTP/1.1\r\nHost: fzf\r\nx-api-key: " + key.encode() +
                  b"\r\nContent-Length: " + str(len(b)).encode() + b"\r\nConnection: close\r\n\r\n" + b)
        r = s.recv(128)
    finally:
        s.close()
    return r.split(b"\r\n", 1)[0].decode(errors="replace")


def ready(target, key):
    """True once fzf answers GET and has read its first list; an action sent earlier can be lost"""
    try:
        if target.startswith("unix:"):
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(2)
            s.connect(target[5:])
        else:
            h, p = target[4:].rsplit(":", 1)
            s = socket.create_connection((h, int(p)), timeout=2)
        s.sendall(b"GET /?limit=0 HTTP/1.1\r\nHost: fzf\r\nx-api-key: " + key.encode() + b"\r\nConnection: close\r\n\r\n")
        d = b""
        while True:
            c = s.recv(65536)
            if not c:
                break
            d += c
        s.close()
        return b" 200 " in d.split(b"\r\n", 1)[0] and b'"reading":false' in d.replace(b" ", b"")
    except OSError:
        return False


def gaps(view):
    """a blank list line becomes ' <TAB>gap<TAB>-<TAB>-<TAB>gapN': fzf 0.74.5 with --track --id-nth=2,5 stops
    taking actions after a reload while the cursor sits on an item with no fields (seen in testing)"""
    lines = view.split(b"\n")
    n = 0
    for i in range(len(lines) - 1):
        if lines[i] == b"":
            n += 1
            lines[i] = b" \tgap\t-\t-\tgap%d" % n
        elif lines[i].endswith(b"\t"):        # the green line when nothing builds: empty ids
            lines[i] += b"-"
    return b"\n".join(lines)


def preview_stale(run):
    """True when the details pane fzf shows is out of date. The board's preview subcommand saves its arguments, the
    pane width and what it printed in $D/pv.shown; this re-runs it (FB_PEEK: print only) and compares. A refresh
    throws the reader back to the top of a long card or report, so it is sent only when the text really changed."""
    try:
        with open(os.path.join(D, "pv.shown"), "rb") as f:
            data = f.read()
    except OSError:
        return False
    parts = data.split(b"\n", 5)
    if len(parts) < 6:
        return False
    cols, a2, a3, a4, a5, shown = parts
    env = dict(os.environ, FB_PEEK="1", FZF_PREVIEW_COLUMNS=cols.decode(errors="replace"))
    try:
        out = subprocess.run(run + ["preview", a2, a3, a4, a5], capture_output=True, env=env, timeout=5).stdout
    except subprocess.TimeoutExpired:
        return True
    return out != shown


AGE = re.compile(rb"\x1b\[[0-9;]*m[^\x1b\t]{1,16}\x1b\[0m(?=\t)")


def ages_out(view):
    """the view without the age column (the last coloured run before a row's first tab)"""
    return b"\n".join(AGE.sub(b"", l, count=1) for l in view.split(b"\n"))


def log(msg):
    path = os.path.join(D, "live.log")
    try:
        mode = "w" if os.path.getsize(path) > LOG_MAX else "a"
    except OSError:
        mode = "a"
    t = time.time()
    with open(path, mode) as f:
        f.write("%s.%03dZ %s\n" % (time.strftime("%H:%M:%S", time.gmtime(t)), int(t % 1 * 1000), msg))


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def main(script, target, every, bpid):
    nofile = raise_fd_limit()
    key = os.environ["FZF_API_KEY"]
    sock = target[5:] if target.startswith("unix:") else None
    os.makedirs(D, exist_ok=True)
    kick = os.path.join(D, "kick")
    open(kick, "a").close()
    run = [script] if os.access(script, os.X_OK) else ["bash", script]
    vpath, hpath = os.path.join(D, "view"), os.path.join(D, "header")
    # wait for fzf's socket (the board starts fzf right after this process)
    t_end = time.time() + 15
    while sock and not os.path.exists(sock):
        if time.time() > t_end or not alive(bpid):
            log("exit: no socket %s" % sock)
            return
        time.sleep(0.02)
    while not ready(target, key):
        if time.time() > t_end or not alive(bpid):
            log("exit: fzf not ready at %s" % target)
            return
        time.sleep(0.05)
    files, panes = Files(max(16, nofile - FD_SPARE)), Panes()
    files.rearm()
    log("start: watching %d paths (fd limit %d%s), target %s, poll %.1f s, tick %.0f s, only %r"
        % (len(files.fds), nofile, ", %d oldest cards by folder only" % files.over if files.over else "", target, POLL, every, ONLY))
    last_view = last_head = None
    first = True
    now = time.time()
    next_poll, next_tick = now, now + every
    dirty_files = dirty_live = tick = False
    reasons = set()
    while True:
        if not alive(bpid):
            log("exit: board pid %d gone" % bpid)
            return
        if sock and not os.path.exists(sock):
            log("exit: socket gone")
            return
        timeout = min(next_poll, next_tick, time.time() + 1.0) - time.time()
        names = files.wait(timeout)
        if names:
            files.rearm()
            dirty_files = True
            reasons.add("files:" + ",".join(sorted(names)))
        now = time.time()
        if now >= next_poll:
            if panes.poll(now):
                dirty_live = True
                reasons.add("panes")
            now = time.time()
            next_poll = now + (CONFIRM if panes.pending() else POLL)
        if now >= next_tick:
            files.rearm()
            tick = True
            reasons.add("tick")
            next_tick = now + every
        if not (first or dirty_files or dirty_live or tick):
            continue
        t0 = time.time()
        view = gaps(subprocess.run(run + ["list"], capture_output=True).stdout)
        head = subprocess.run(run + ["header"], capture_output=True).stdout   # after list: counts are this render's
        ms = (time.time() - t0) * 1000
        # fzf drops the actions that follow reload in one chain, so reload goes alone and last; the board's
        # load bind runs transform-header(cat header) once the new list is in (row and count in one frame).
        # The details pane is refreshed only when its text changed (preview_stale, after the post).
        parts, names_p = [], []
        reload = first or view != last_view
        # only the ages moved: fzf re-runs the preview on any reload and scrolls it to the top, so the board's
        # agereload subcommand skips the reload while the last key pressed scrolled the details pane (fix 5)
        age_only = reload and not first and ages_out(view) == ages_out(last_view)
        if first or head != last_head:
            write_atomic(hpath, head)
            if not reload or age_only:
                parts.append("transform-header(cat %s)" % shlex.quote(hpath))
            names_p.append("header")
        if age_only:
            write_atomic(vpath, view)
            parts.append("transform(%s agereload)" % " ".join(shlex.quote(a) for a in run))
            names_p.append("ages")
        elif reload:
            write_atomic(vpath, view)
            parts.append("reload(cat %s)" % shlex.quote(vpath))
            names_p.append("reload")
        status = "-"
        if parts:
            for attempt in range(50):
                try:
                    status = post(target, key, "+".join(parts))
                    break
                except Gone as e:
                    if first and not sock and attempt < 49:   # tcp: fzf may not listen yet
                        time.sleep(0.2)
                        continue
                    log("exit: fzf gone (%s)" % e)
                    return
                except socket.timeout:
                    status = "timeout"
                    break
            last_view, last_head = view, head
            if " 401 " in status:     # another board's fzf holds this socket now: not ours to drive
                log("exit: the socket answers 401, not this board's fzf")
                return
        if (dirty_files or dirty_live) and (age_only or not reload) and preview_stale(run):
            try:
                st2 = post(target, key, "refresh-preview")
            except Gone as e:
                log("exit: fzf gone (%s)" % e)
                return
            except socket.timeout:
                st2 = "timeout"
            names_p.append("preview")
            status = st2 if status == "-" else status
        why = "first" if first else " ".join(sorted(reasons))
        log("render %s · %d ms · %s · %s" % (why, ms, ",".join(names_p) or "nothing posted", status))
        first = dirty_files = dirty_live = tick = False
        reasons = set()


def once():
    rc, out = list_panes()
    if rc != 0:
        print("tmux list-panes failed")
        return
    names, cands = candidates(out)
    for s, (pid, act, ht) in sorted(cands.items()):
        t = time.time()
        r = classify(capture(pid), ht)
        ms = (time.time() - t) * 1000
        st, dt = (r[0], r[1]) if r else ("?", "unreadable")
        print("%-26s %-7s %-58s %4.0f ms" % (s, st, dt[:58], ms))


if __name__ == "__main__":
    if sys.argv[1:] == ["once"]:
        once()
    elif len(sys.argv) == 5:
        main(sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4]))
    else:
        sys.exit(__doc__ or "usage: fleet-board-live.py <board script> <unix:PATH|tcp:HOST:PORT> <tick secs> <board bash pid> | once")
