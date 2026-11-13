#!/usr/bin/env python3
"""Append one entry to a rung's decision record or evidence file, and the IC's Edit guard on both.

Called by shared/records/record-add.sh, which gathers the body (stdin) and the stamp, then runs the Jev
check and the audit for a DR or UAT entry. Everything that touches the file is here, so it can be
read, dumped and tested. The guard is called by shared/hooks/artefact-gate.sh (PreToolUse, IC only).

Why: an IC's Edit adding DR3 anchored on UAT1's undo line, so DR3 landed above UAT1's jev line; the
dr-check hook read that jev line as DR3's, re-checked UAT1, never checked DR3, and the audit failed at
the push. An entry is only ever added at the end of the file.

Usage
  record_add.py <file> dr|uat|e [--dump]   append the entry in RA_BODY, stamped RA_NOW; print its id
  record_add.py <file> --jev "<entry id>"  print the jev line of that entry, or nothing
  record_add.py --guard                    hook JSON on stdin; print the reason to deny, or nothing
  record_add.py --bash <records root>      an IC's Bash command on stdin; print the verdict line, then the command
                                           with every quoted record-add.sh heredoc body taken out (shared/hooks/
                                           push-gate.sh); the records root is no longer read: the file name is enough

The file and its header (the first line that is not blank; nothing is added to a file without it)
  dr, uat   decision-record.md   # <lane> rung <n> · decision record · <IC>     (recording-a-decision rule 2)
  e         evidence.md          # <lane> rung <n> · evidence · <IC>            (recording-evidence rule 6)

The body: a first line, then the entry's lines at two spaces, in the skill's order
  dr    first line: what goes between the id and the time, e.g. `task 5` (required)
  uat   first line: none, or `UAT`
  e     first line: what was run, five words
  The first line may also be a whole header (`ATL-42 DR4 · task 5 · 2026-09-16 13:42 · atlas-ic`,
  `## E7 gate run · 2026-09-16 13:40`): a number in it must be the next one, the lane the file's;
  An id at the start of the first line counts whatever follows it (`DR7 push`, `ATL-42 DR3: push`).
  Its time is replaced by the stamp; an IC named after the time must be the header's IC.

The entry as written
  dr    <lane> DR<n> · <first line> · <now> · <IC>          n: the highest DR in the file, plus one
  uat   <lane> UAT<n> · <now> · <IC>                        n: the highest UAT in the file, plus one
  e     ## E<n> <first line> · <now>                        n: the highest E in the file, plus one
  then the body's lines as given; one blank line above the entry, the file's own text untouched
  (the entry is appended, never inserted). Read back after the write: the file must be its text
  before, the blank and the entry.

Refused (exit 1, nothing written)
  no file, or no header first; a number, a lane or an IC in the body that is not the next one or the file's;
  a line after the first that is not indented two spaces; a blank line inside a DR or UAT entry (the
  dr-check hook reads an entry up to its first line that is not indented, so a blank ends it);
  a `jev` line (the check writes it) or a `review` line other than `-` (lead-1 writes it);
  a DR with no `decided` line, a UAT with no `words` or `done` line, an E with no `ran` or `exit` line.

The guard (IC only, decision-record.md and evidence.md in a record folder, the path resolved and the name
in any case: macOS ignores case, and /./, // or a link to the folder name the same file)
  Edit, MultiEdit  allowed only when each edit appends: old_string matches once, at the end of the file
                   (only blank space after it), new_string starts with old_string, and the text it adds
                   passes the appended-text rules below. An old_string that matches nowhere is denied too:
                   the Edit tool may still match it with its quotes made straight, anywhere in the file.
  Write            denied over a file that has text; creating it is allowed when the first line is the
                   header (or the content is empty) and the rest passes the appended-text rules.
  Appended text    starts on a new line (text added to the end of the last line edits a written entry);
                   once the file has an entry, its first line that is not blank is at the left edge (an
                   indented line joins the entry above, after that entry's check); every line at the left
                   edge is the header of the next entry, `<lane> DR<n> ·` or `<lane> UAT<n> ·` with the next
                   number of its kind and the file's lane, or `## E<n>` with the next number; no `jev` line
                   and no `review` line other than `-`. Before the first entry, other lines at the left edge
                   are the header block.

The Bash command (best effort, as push-gate.sh's FROZEN WRITE GATE)
  The body of a quoted heredoc that record-add.sh itself reads is data: it is taken out before any check
  reads the command, so a DR whose `undo` reads `git push --delete ...` is not read as a push, nor its
  words as a write. Only a line with one heredoc, in a simple command whose program is record-add.sh, counts:
  `X=record-add.sh bash <<'EOF'` or `bash -s record-add.sh <<'EOF'` feeds bash, and its body stays. Then
  the verdict, the first that applies:
  unquoted      record-add.sh reads a heredoc whose delimiter is not quoted: the shell runs any $(...) or
                backtick in the body before the entry is written
  write         the command names a record file (decision-record.md, evidence.md or a -jev-*.json receipt,
                in any case, quotes and backslashes taken out) with a write form: a > >> >| <> or &> into
                it; tee, cp, mv, rm, ln, truncate, dd, install, rsync, chmod, patch, ed, ex, vi, vim, nvim,
                emacs, osascript, swift, by name or by path; sed with -i among its flags; awk -i inplace; or a
                python, perl, ruby or node run (a python run of dr_check.py, the audit or --dump, is a read).
                The records root is not needed in the command: a cd, a glob or a link leaves only the name.
  add dr|uat|e  each kind record-add.sh writes in the command (not a --dump run); the hook checks the skill
                was invoked for each
  (empty)       none of these
  Not seen: a glob on the file name itself, a script file, a variable holding the name, `git apply
  --directory`. The Edit guard, the dr-check hook and the audit after each write cover what this misses.
  Denied in error: a cp with a record file as its source, a python read of a receipt, a pipe into python.

Exit  0 written · 1 refused (message on stderr) · 2 usage
"""
import json, os, re, sys

HEADER = {
    "decision-record.md": re.compile(r"^# (\S+) rung .*· decision record · (\S+)\s*$"),
    "evidence.md": re.compile(r"^# (\S+) rung .*· evidence · (\S+)\s*$"),
}
FILE = {"dr": "decision-record.md", "uat": "decision-record.md", "e": "evidence.md"}
STAMP = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}Z?$")
NEEDS = {"dr": ("decided",), "uat": ("words", "done"), "e": ("ran", "exit")}
HOW = ("Write the entry with shared/records/record-add.sh <record folder> dr|uat|e <<'EOF' ... EOF, run from the worktree: "
       "it appends at the end, numbers the entry from the file and, for a DR or UAT, runs the Jev check and the audit.")


def fail(msg):
    print(f"record-add: {msg}", file=sys.stderr)
    sys.exit(1)


def header(text, name):
    """(lane, IC) from the file's first line that is not blank, or None."""
    first = next((l for l in text.split("\n") if l.strip()), "")
    m = HEADER[name].match(first)
    return (m.group(1), m.group(2)) if m else None


def numbers(text, kind):
    """Every number used by this kind of entry in the file."""
    if kind == "e":
        return [int(n) for n in re.findall(r"^## E(\d+)\b", text, re.M)]
    word = "DR" if kind == "dr" else "UAT"
    return [int(n) for n in re.findall(rf"^\S+ {word}(\d+) ·", text, re.M)]


def first_line(kind, line, lane, ic, n):
    """What the body's first line leaves for the header: the text between the id and the time (dr, uat),
    or the five words (e). A number or lane that disagrees is refused."""
    if kind == "e":
        m = re.match(r"^(?:##\s*)?(?:E(\d*)(?:[\s:.,]+|$))?(.*)$", line.strip())
        given, rest = m.group(1), m.group(2)
        rest = re.sub(r"\s*·\s*\d{4}-\d{2}-\d{2} \d{2}:\d{2}Z?\s*$", "", rest).strip()
        if given and int(given) != n:
            fail(f"the body says E{given}; the next entry in the file is E{n}")
        if not rest:
            fail("an E entry's first line says what was run, five words")
        return rest
    word = "DR" if kind == "dr" else "UAT"
    # an id at the start, with or without a lane, whatever follows it: `DR7 push`, `ATL-42 DR3: push`
    # (a bare DR or UAT with no number counts only before a `·` or alone: `UAT feedback` is text)
    m = re.match(r"^(?:([A-Za-z][A-Za-z0-9]*-\d+) )?(DR|UAT|REVIEW)(?:\s*(\d+)(?=[\s·:.,]|$)[\s:.,]*|(?=\s*·|\s*$))"
                 r"\s*(?:·\s*)?(.*)$", line.strip())
    if m:
        if m.group(1) and m.group(1) != lane:
            fail(f"the body names lane {m.group(1)}; the file's header names {lane}")
        if m.group(2) != word:
            fail(f"the body is a {m.group(2)} entry; `{kind}` writes a {word}")
        if m.group(3) and int(m.group(3)) != n:
            fail(f"the body says {word}{m.group(3)}; the next entry in the file is {word}{n}")
        rest = m.group(4)
    else:
        rest = line.strip()
    parts = [p.strip() for p in rest.split("·") if p.strip()]
    stamp = next((k for k, p in enumerate(parts) if STAMP.match(p)), None)
    if stamp is not None:   # a whole header: what follows its time is the IC, and only the file's IC writes here
        for p in parts[stamp + 1:]:
            if p != ic:
                fail(f"the body names IC {p}; the file's header names {ic}")
        parts = parts[:stamp]
    parts = [p for p in parts if p != ic]
    middle = " · ".join(parts)
    if kind == "dr" and not middle:
        fail("a DR's first line says what goes between the id and the time, e.g. `task 5` "
             "(the plan's task, or `push`)")
    return middle


def entry_for(text, kind, body, now, lane, ic):
    """The entry as it will land, and its id."""
    lines = body.strip("\n").split("\n")
    if not lines or not lines[0].strip():
        fail("empty body")
    if lines[0].startswith("  "):
        if kind != "uat":
            fail("the body starts with an indented line; its first line is "
                 + ("what goes between the id and the time, e.g. `task 5`" if kind == "dr" else "what was run, five words"))
        lines = [""] + lines
    n = max(numbers(text, kind), default=0) + 1
    middle = first_line(kind, lines[0], lane, ic, n)
    rest = [l.rstrip() for l in lines[1:]]
    fields = set()
    for i, l in enumerate(rest, 2):
        if not l.strip():
            if kind != "e":
                fail(f"body line {i} is blank; the dr-check hook reads an entry up to its first blank line, so the "
                     "lines after it would not be read. One entry, no blank lines")
            continue
        if not l.startswith("  "):
            fail(f"body line {i} is not indented two spaces: {l[:60]!r}. One entry per call; its lines at two spaces")
        m = re.match(r"^  (\S+(?: \S+)?)\s{2,}(.*)$", l)   # the field shape dr_check.py reads
        if m:
            fields.add(m.group(1))
        if kind != "e" and re.match(r"^  jev\b", l):
            fail("the body has a `jev` line; the Jev check writes it, under the entry, after the write")
        if kind == "dr" and re.match(r"^  review\b", l) and l.split(None, 1)[1:] != ["-"]:
            fail("the body has a `review` line other than `-`; lead-1 writes it at the audit")
    missing = [f for f in NEEDS[kind] if f not in fields]
    if missing:
        fail(f"no `{'`, `'.join(missing)}` line; the entry's lines are in "
             + ("recording-evidence" if kind == "e" else "recording-a-decision"))
    if kind == "e":
        eid = f"E{n}"
        head = f"## E{n} {middle} · {now}"
    else:
        eid = f"{lane} {'DR' if kind == 'dr' else 'UAT'}{n}"
        head = " · ".join([eid] + ([middle] if middle else []) + [now, ic])
    while rest and not rest[-1].strip():
        rest.pop()
    return "\n".join([head] + rest) + "\n", eid


def add(path, kind, dump=False):
    name = FILE[kind]
    if os.path.basename(path) != name:
        fail(f"`{kind}` writes {name}, not {os.path.basename(path)}")
    try:
        text = open(path, encoding="utf-8").read()
    except FileNotFoundError:
        fail(f"no {path}. The first write of the file is its header, with the Write tool "
             f"(`# <lane> rung <n> · {'decision record' if name != 'evidence.md' else 'evidence'} · <IC>`)")
    h = header(text, name)
    if not h:
        fail(f"{path} does not start with its header (`# <lane> rung <n> · "
             f"{'decision record' if name != 'evidence.md' else 'evidence'} · <IC>`); no entry before the header")
    for k in ("RA_BODY", "RA_NOW"):
        if k not in os.environ:
            fail(f"env {k} not set")
    entry, eid = entry_for(text, kind, os.environ["RA_BODY"], os.environ["RA_NOW"], *h)
    sep = "" if text.endswith("\n\n") or not text else ("\n" if text.endswith("\n") else "\n\n")
    if dump:
        print(entry, end="")
        print(f"(dump: {eid}, {entry.count(chr(10))} lines, nothing written)")
        return 0
    with open(path, "a", encoding="utf-8") as f:
        f.write(sep + entry)
    back = open(path, encoding="utf-8").read()
    if back != text + sep + entry:
        fail(f"after the write {path} is not its text before plus the entry; another write landed at the same "
             "time. Read the file's end before anything else")
    print(eid)
    return 0


def jev_of(path, eid):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hooks"))
    import dr_check
    for e in dr_check.read_entries(open(path, encoding="utf-8").read().split("\n")):
        if e.id == eid and e.checked:
            print(f"  jev         {e.fields['jev']}")
    return 0


# ---------- the guard: an IC's Write, Edit or MultiEdit on decision-record.md or evidence.md ----------

def added_why(name, before, added, p):
    """The reason the text `added` after `before` is not one or more new entries, or ''.

    The text must start on a line of its own (a last line extended in place is an edit of a written entry),
    its first line that is not blank must be at the left edge (an indented line joins the entry above,
    after that entry's check), and every line at the left edge must be the header of the next entry:
    `<lane> DR<n> ·` or `<lane> UAT<n> ·` with the next number (decision-record.md), `## E<n>` with the next
    number (evidence.md). No `jev` line (the check writes it) and no `review` line other than `-` (lead-1's).
    While the file has no entry yet, other lines at the left edge are the header block and pass."""
    if not added.strip():
        return ""
    if before and not before.endswith("\n") and not added.startswith("\n"):
        return (f"APPEND ONLY: this write on {p} adds text to the end of the file's last line instead of a new line; "
                f"an entry is never edited after it is written (recording-a-decision rule 1). {HOW}")
    h = header(before + added, name)
    lane = h[0] if h else None
    dr = name == "decision-record.md"
    nxt = ({"DR": max(numbers(before, "dr"), default=0) + 1, "UAT": max(numbers(before, "uat"), default=0) + 1}
           if dr else {"E": max(numbers(before, "e"), default=0) + 1})
    entries = bool(re.search(r"^\S+ (DR|UAT)\d+ ·" if dr else r"^## E\d+\b", before, re.M))
    lines = added.split("\n")
    first = next((l for l in lines if l.strip()), "")
    if entries and first[:1].isspace():
        return (f"APPEND ONLY: this write on {p} adds the indented line `{first.strip()[:60]}` under the last entry, "
                f"which joins that entry after its check. A new entry starts with its own header. {HOW}")
    for l in lines:
        if not l.strip():
            continue
        if l[:1].isspace():
            if dr and re.match(r"^\s+jev\b", l):
                return f"APPEND ONLY: this write on {p} carries a `jev` line; only the Jev check writes one. {HOW}"
            if dr and re.match(r"^\s+review\b", l) and l.split(None, 1)[1:] != ["-"]:
                return (f"APPEND ONLY: this write on {p} carries a `review` line other than `-`; lead-1 writes it "
                        f"at the audit. {HOW}")
            continue
        m = (re.match(r"^(\S+) (DR|UAT)(\d+) ·", l) if dr else re.match(r"^## (E)(\d+)\b", l))
        if not m:
            if not entries:
                continue   # the header block, before the first entry
            return (f"APPEND ONLY: this write on {p} adds `{l[:60]}`, which is not the header of the next entry "
                    f"({'`<lane> DR<n> · ...` or `<lane> UAT<n> · ...`' if dr else '`## E<n> ...`'}). {HOW}")
        entries = True
        kind, n = (m.group(2), int(m.group(3))) if dr else ("E", int(m.group(2)))
        if dr and lane and m.group(1) != lane:
            return f"APPEND ONLY: this write on {p} adds an entry for lane {m.group(1)}; the file's header names {lane}. {HOW}"
        if n != nxt[kind]:
            return (f"APPEND ONLY: this write on {p} adds {kind}{n}; the next entry in the file is {kind}{nxt[kind]} "
                    f"(an id written twice, or a gap, reads as another entry's check). {HOW}")
        nxt[kind] += 1
    return ""


def guard(hook):
    """The reason to deny, or ''."""
    tool, i = hook.get("tool_name") or "", hook.get("tool_input") or {}
    p = i.get("file_path") or ""
    name = os.path.basename(os.path.realpath(p)).lower() if p else ""
    if name not in HEADER:   # macOS ignores case: DECISION-RECORD.md is the same file
        return ""
    try:
        text = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        text = None
    head = ("# <lane> rung <n> · decision record · <IC>" if name == "decision-record.md"
            else "# <lane> rung <n> · evidence · <IC>")

    def created(content):
        if not content.strip():
            return ""
        if not header(content, name):
            return (f"HEADER FIRST: {p} starts with its header line, `{head}` "
                    f"({'recording-a-decision rule 2' if name == 'decision-record.md' else 'recording-evidence rule 6'}); "
                    f"no entry before it. Write the header first, then each entry with shared/records/record-add.sh.")
        return added_why(name, "", content, p)

    if tool == "Write":
        if text is None or not text.strip():
            return created(i.get("content") or "")
        return (f"APPEND ONLY: {p} exists; a Write replaces the whole file, and an entry is never edited after it "
                f"is written (recording-a-decision rule 1). {HOW}")
    if tool not in ("Edit", "MultiEdit"):
        return ""
    edits = (i.get("edits") or []) if tool == "MultiEdit" else [i]
    cur = text
    for n, e in enumerate(edits, 1):
        old, new = e.get("old_string") or "", e.get("new_string") or ""
        which = f"edit {n} of {len(edits)}" if tool == "MultiEdit" else "this Edit"
        if cur is None or not cur.strip():
            why = created(new)
            if why:
                return why
            cur = (cur or "") + new
            continue
        if not old:
            return f"APPEND ONLY: {which} on {p} has an empty old_string. {HOW}"
        k = cur.find(old)
        if k < 0:   # the Edit tool may still match it with its quotes made straight, anywhere in the file
            return (f"APPEND ONLY: {which} on {p}: old_string is not, character for character, the end of the file. "
                    f"{HOW} An Edit may only append: old_string the file's last lines exactly as they read.")
        if cur.count(old) > 1:
            return (f"APPEND ONLY: {which} on {p}: old_string matches {cur.count(old)} places, so it does not name the "
                    f"end of the file (two jev lines can read the same). {HOW} An Edit may only append: old_string the "
                    f"file's last lines, enough of them to match once, new_string starting with them.")
        after = cur[k + len(old):]
        if after.strip():
            line = cur[:k + len(old)].count("\n") + 1
            return (f"APPEND ONLY: {which} on {p} anchors on text that is not the end of the file (old_string ends at "
                    f"line {line} of {cur.count(chr(10)) + 1}). An entry added there lands above the entries and jev "
                    f"lines after it, and the dr-check hook then checks the wrong entry. {HOW} An Edit may only "
                    f"append: old_string the file's last line(s), new_string starting with them.")
        if not new.startswith(old):
            return (f"APPEND ONLY: {which} on {p} changes the file's last line(s) instead of appending after them "
                    f"(new_string does not start with old_string); an entry is never edited after it is written. {HOW}")
        why = added_why(name, cur[:k + len(old)], new[len(old):], p).replace("this write", which, 1)
        if why:
            return why
        cur = cur[:k] + new + after
    return ""


# ---------- the Bash command: an IC's write to the record files outside record-add.sh ----------

HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def record_add_heredoc(line):
    """(delimiter, quoted) when the line's one heredoc is read by record-add.sh itself, else None.

    The heredoc belongs to the simple command it stands in (the text after the last ; & | ( before it);
    that command's word, after any NAME=value, must be record-add.sh. `X=record-add.sh bash <<EOF`,
    `bash <<EOF # record-add.sh` and `bash -s record-add.sh <<EOF` feed bash, so their body is a script."""
    ms = list(HEREDOC.finditer(line))
    if len(ms) != 1:
        return None
    words = re.split(r"[;&|(]", line[:ms[0].start()])[-1].split()
    while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
        words.pop(0)
    if not words or os.path.basename(words[0].strip("'\"")) != "record-add.sh":
        return None
    return ms[0].group(2), bool(ms[0].group(1))


def strip_bodies(cmd):
    """The command with the body of every quoted heredoc record-add.sh reads taken out (the body is the entry:
    data). An unquoted one is kept: the shell expands $(...) and backticks in it, so it is a command."""
    lines, out, i = cmd.split("\n"), [], 0
    while i < len(lines):
        out.append(lines[i])
        h = record_add_heredoc(lines[i])
        i += 1
        if h and h[1]:
            while i < len(lines) and lines[i].lstrip("\t") != h[0]:
                i += 1
            i += 1   # the closing line
    return "\n".join(out)


def flat(cmd):
    """The command with quotes, backslashes and line continuations taken out, so `"decision-record".md`,
    decision\-record.md and a name split over a continued line read as the name."""
    return re.sub(r"[\"'\\]", "", cmd.replace("\\\n", " "))


NAMES = re.compile(r"(decision-record|evidence)\.md|-jev-\S*\.json", re.I)


def bash_verdict(cmd, records):
    if any(h and not h[1] for h in map(record_add_heredoc, cmd.split("\n"))):
        return "unquoted"
    if bash_write(cmd, records):
        return "write"
    f = flat(cmd)
    kinds = []
    for m in re.finditer(r"record-add\.sh\s+(--dump\s+)?\S+\s+(dr|uat|e)\b", f):
        if not m.group(1) and m.group(2) not in kinds:
            kinds.append(m.group(2))
    return ("add " + " ".join(kinds)) if kinds else ""


def bash_write(cmd, records):
    """A command naming a record file (decision-record.md, evidence.md, a receipts/*-jev-*.json) anywhere,
    in any case, with a write form. Not tied to the records root: a cd, a glob or a link to the folder
    leaves only the file name in the command."""
    f = flat(cmd)
    if not NAMES.search(f):
        return False
    reads = re.sub(r"python[\d.]*\s+\S*dr_check\.py\b", " ", f)   # the audit and --dump read the record
    tool = re.search(r"(^|[\s;&|(`/])(tee|cp|mv|rm|ln|truncate|dd|install|rsync|chmod|python[\d.]*|perl|ruby|node"
                     r"|patch|ed|ex|vi|vim|nvim|emacs|osascript|swift)(\s|$)"
                     r"|\bsed\b[^\n;&|]*\s(-[a-zA-Z]*i|--in-place)|\bg?awk\b[^\n;&|]*\s-i\s*inplace", reads)
    into = re.search(r"(>>?|>\||<>|&>>?)\s*[^\s;|&]*((decision-record|evidence)\.md|-jev-[^\s;|&]*\.json)", f, re.I)
    return bool(tool or into)


def main(argv):
    if argv[1:2] == ["--bash"] and len(argv) == 3:
        cmd = strip_bodies(sys.stdin.read())
        print(bash_verdict(cmd, argv[2]))
        sys.stdout.write(cmd)
        return 0
    if argv[1:2] == ["--guard"]:
        try:
            hook = json.load(sys.stdin)
        except ValueError:
            return 0
        why = guard(hook)
        if why:
            print(why)
        return 0
    if len(argv) >= 4 and argv[2] == "--jev":
        return jev_of(argv[1], argv[3])
    if len(argv) < 3 or argv[2] not in FILE:
        print(__doc__, file=sys.stderr)
        return 2
    return add(argv[1], argv[2], "--dump" in argv[3:])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
