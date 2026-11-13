#!/bin/bash
# check-live.sh [--old <old AgentMgmt>] [--claude-home <dir>] [--home <dir>]   count live old-repo paths
# check-live.sh --rehearsal     whole migration in a scratch home, then the count
# check-live.sh --rolled-back   the rehearsal, then this clone's install.sh --repo <AgentMgmt main>: new-repo count
#
# No flag only READS: <claude home>/settings.json (hook commands, env values), the targets of
# <claude home>/skills/* links, and `tmux list-panes -a` start commands. Old path = --old, else
# $FLEET_HOME/migrate/agentmgmt-path (written by copy.sh). A hit is the path followed by / ' " blank
# or end, so /x/AgentMgmt does not match /x/AgentMgmt2. Prints one line per hit (where, never content).
# CHECK_LIVE_TMUX_SOCKET=<name> reads that tmux socket instead of the default server.
# --rehearsal and --rolled-back write only inside their own mktemp folder and tmux socket fam-test.
set -u
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
MODE=count; OLD=""; HOME_DIR="$HOME"; CH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rehearsal) MODE=rehearsal ;;
    --rolled-back) MODE=rolled ;;
    --old) OLD="${2:?--old needs a path}"; shift ;;
    --home) HOME_DIR="${2:?--home needs a folder}"; shift ;;
    --claude-home) CH="${2:?--claude-home needs a folder}"; shift ;;
    *) echo "usage: check-live.sh [--old <path>] [--claude-home <dir>] [--home <dir>] | --rehearsal | --rolled-back" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$CH" ] || CH="$HOME_DIR/.claude"

# count_paths <path> <claude home> <tmux socket or ""> <label>: hit lines, then "<label>: N"; exit 1 when N>0.
# A source that cannot be read prints "<label>: unknown (why)" and exits 1: never a silent 0.
# tmux: only "no server running" (or no socket to connect to) counts as 0 panes; any other error is unknown.
count_paths() {
python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, os, re, subprocess, sys
old, ch, sock, label = sys.argv[1:5]
old = old.rstrip("/")
rx = re.compile(re.escape(old) + r"""(?=[/'"\s]|$)""")
n = 0
def unknown(why):
    print("%s: unknown (%s)" % (label, why))
    sys.exit(1)
def hit(where, text):
    global n
    for _ in rx.finditer(text):
        n += 1
        print("hit: " + where)
if not os.path.isdir(ch):
    unknown("claude home missing")
try:
    s = json.load(open(os.path.join(ch, "settings.json")))
    if not isinstance(s, dict):
        raise ValueError("not an object")
except (OSError, ValueError):
    unknown("settings.json unreadable")
sk = os.path.join(ch, "skills")
if not os.path.isdir(sk):
    unknown("skills folder missing")
cmd = ["tmux"] + (["-L", sock] if sock else []) + ["list-panes", "-a", "-F", "#{pane_start_command}"]
try:
    r = subprocess.run(cmd, capture_output=True, text=True)
except OSError:
    unknown("tmux not found")
if r.returncode != 0:
    err = r.stderr
    if not ("no server running" in err or ("error connecting to" in err and "No such file or directory" in err)):
        unknown("tmux list-panes failed")
    out = ""
else:
    out = r.stdout
for k, v in (s.get("env") or {}).items():
    if isinstance(v, str):
        hit("settings.json env.%s" % k, v)
for ev, entries in (s.get("hooks") or {}).items():
    for e in entries if isinstance(entries, list) else []:
        for h in e.get("hooks", []):
            if isinstance(h.get("command"), str):
                hit("settings.json hooks.%s command" % ev, h["command"])
for name in sorted(os.listdir(sk)):
    p = os.path.join(sk, name)
    if os.path.islink(p):
        hit("skills/%s link target" % name, os.readlink(p))
for i, line in enumerate(out.splitlines(), 1):
    hit("tmux pane %d start command" % i, line)
print("%s: %d" % (label, n))
sys.exit(1 if n else 0)
PY
}

if [ "$MODE" = count ]; then
  if [ -z "$OLD" ]; then
    FH="${FLEET_HOME:-$HOME_DIR/.fleet-agent-mgmt}"
    [ -f "$FH/migrate/agentmgmt-path" ] && OLD="$(head -1 "$FH/migrate/agentmgmt-path")"
  fi
  if [ -z "$OLD" ]; then echo "old-repo paths: unknown (no migrate/agentmgmt-path)"; exit 1; fi
  count_paths "$OLD" "$CH" "${CHECK_LIVE_TMUX_SOCKET:-}" "old-repo paths"
  exit $?
fi

# ---- rehearsal ----
SOCK=fam-test
W="$(mktemp -d)" || exit 1
cleanup() { tmux -L "$SOCK" kill-server >/dev/null 2>&1; rm -rf "$W"; }
trap cleanup EXIT
W="$(cd -P "$W" && pwd)"
fail() { echo "$*"; exit 1; }
command -v tmux >/dev/null && command -v jq >/dev/null && command -v python3 >/dev/null || fail "rehearsal: needs tmux, jq and python3"
unset TMUX FLEET_REPO FLEET_HOME
B="$W/with space"; mkdir -p "$B"
AM="$B/old AgentMgmt"; RH="$B/home"; RCH="$RH/.claude"; FH="$RH/.fleet-agent-mgmt"
mkdir -p "$AM" "$RH/atlas"
# the old repo is main's shared/ tree (main has no install.sh and no lib/paths.sh); only shared/ so no owner data is archived
git -C "$REPO" archive main shared | tar -x -C "$AM" || fail "rehearsal: cannot archive main"
mkdir -p "$AM/Leads/lead-1" "$AM/lead-ux/notes"
echo "invented board" > "$AM/Leads/lead-1/board.md"
echo "invented note" > "$AM/lead-ux/notes/n.md"
{ for k in session role rung handoff repo branch head pushed dirty stop notice next updated evidence; do echo "$k: rehearsal"; done; } > "$W/state-keys"
{ echo "# invented ledger"; echo '```state'; cat "$W/state-keys"; echo "awaiting: none"; echo '```'; } > "$AM/Leads/lead-1/LEDGER.md"
printf '**owner: Robin**\n\n```fleet\nlead-1\t%s\natlas-ic-1\t%s\n```\n' "$AM/Leads/lead-1" "$RH/atlas" > "$AM/shared/roster.md"

# the old roster, as on the owner's machine: lead-1 sits under the old AgentMgmt (copy.sh rewrites it)
# today's machine: settings and links point at the fixture AgentMgmt
bash "$HERE/install.sh" --repo "$AM" --home "$RH" --claude-home "$RCH" >/dev/null 2>&1 || fail "rehearsal: seed install failed"
seeded="$(count_paths "$AM" "$RCH" "$SOCK" seeded | tail -1)"
case "$seeded" in "seeded: "[1-9]*) ;; *) fail "rehearsal: seed holds no readable old-repo path, the counter cannot be trusted ($seeded)" ;; esac
echo "rehearsal $seeded"

# the old repo is a git repo, as on the owner's machine (copy.sh records its HEAD)
git -C "$AM" init -q && git -C "$AM" add -A \
  && git -C "$AM" -c commit.gpgsign=false -c user.name=rehearsal -c user.email=rehearsal@example.test commit -q -m "invented old repo" \
  || fail "rehearsal: cannot make the fixture old repo a git repo"
# the migration: copy, then install from this clone
bash "$HERE/copy.sh" "$AM" "$FH" >/dev/null 2>&1 || fail "rehearsal: copy.sh failed"
bash "$HERE/copy.sh" --ledger "$AM" "$FH" >/dev/null 2>&1 || fail "rehearsal: copy.sh --ledger failed"
# the roster copy.sh wrote must now name lead-1 in the state folder, not the old repo
[ "$(awk '/^```fleet/{f=1;next} /^```/{f=0} f && NF>=2 {split($0,a,"\t"); if (a[1]=="lead-1") print a[2]}' "$FH/roster.md")" = "$FH/Leads/lead-1" ] \
  || fail "rehearsal: copy.sh did not move lead-1's roster row to $FH/Leads/lead-1"
# lead-1's folder is its own git repo with LEDGER.md committed, as on the owner's machine
git -C "$FH/Leads/lead-1" init -q && git -C "$FH/Leads/lead-1" add -A \
  && git -C "$FH/Leads/lead-1" -c commit.gpgsign=false -c user.name=rehearsal -c user.email=rehearsal@example.test commit -q -m "invented ledger" \
  || fail "rehearsal: cannot commit the scratch ledger"
bash "$HERE/install.sh" --repo "$REPO" --home "$RH" --claude-home "$RCH" >/dev/null 2>&1 || fail "rehearsal: install.sh failed"

# lead turns: a stub claude reads the Stop hook and the env from settings.json and runs them under the scratch HOME.
# Two sessions: lead-1 (roster row $FH/Leads/lead-1: gate reads the LEDGER.md state block and git log) and the IC atlas-ic-1
# (gate reads $FH/checks/atlas-ic-1/STATE.md). Each needs a "pass <name>" line in its checks folder's state-gate.log.
mkdir -p "$FH/checks/atlas-ic-1" "$FH/checks/lead-1"
{ echo '```state'; cat "$W/state-keys"; echo "awaiting: none"; echo '```'; } > "$FH/checks/atlas-ic-1/STATE.md"
TB="$W/turn-bin"; mkdir -p "$TB"
cat > "$TB/claude" <<'STUB'
#!/bin/bash
# stub lead turn: $1 = settings.json, $2 = session cwd
eval "$(python3 - "$1" <<'PY'
import json, shlex, sys
s = json.load(open(sys.argv[1]))
for k, v in s.get("env", {}).items():
    print("export %s=%s" % (k, shlex.quote(v)))
print("CMD=%s" % shlex.quote(s["hooks"]["Stop"][0]["hooks"][0]["command"]))
PY
)"
printf '{"cwd": "%s", "stop_hook_active": false}' "$2" | sh -c "$CMD"
STUB
chmod +x "$TB/claude"
lead="ok"
for sess in "lead-1:$FH/Leads/lead-1" "atlas-ic-1:$RH/atlas"; do
  nm="${sess%%:*}"; dir="${sess#*:}"
  (cd "$dir" && env -i PATH="$PATH" HOME="$RH" "$TB/claude" "$RCH/settings.json" "$dir") >"$W/turn-$nm.out" 2>&1 \
    || { lead="FAIL ($nm gate exited non-zero: $(head -c 200 "$W/turn-$nm.out" | tr '\n' ' '))"; break; }
  grep -q " pass $nm\$" "$FH/checks/$nm/state-gate.log" 2>/dev/null || { lead="FAIL ($nm gate did not log a pass)"; break; }
done

# launch: agent-up.sh on tmux -L fam-test with a stub claude that records its argv and env
LB="$W/launch-bin"; LG="$W/launch-logs"; mkdir -p "$LB" "$LG"
printf '#!/bin/bash\nexec "%s" -L %s "$@"\n' "$(command -v tmux)" "$SOCK" > "$LB/tmux"
cat > "$LB/claude" <<STUB
#!/bin/bash
name=x; prev=""
for a in "\$@"; do [ "\$prev" = "-n" ] && name="\$a"; prev="\$a"; done
{ for a in "\$@"; do echo "arg: \$a"; done; echo "FLEET_REPO=\${FLEET_REPO-unset}"; echo "FLEET_HOME=\${FLEET_HOME-unset}"; } > "$LG/\$name.log"
STUB
chmod +x "$LB/tmux" "$LB/claude"
tmux -L "$SOCK" kill-server >/dev/null 2>&1
launch="ok"
env -i PATH="$LB:$PATH" HOME="$RH" FLEET_HOME="$FH" bash "$REPO/shared/launch/agent-up.sh" atlas-ic-1 >"$W/up.out" 2>&1 || launch="FAIL (agent-up exited non-zero)"
i=0; while [ "$i" -lt 50 ] && [ ! -f "$LG/atlas-ic-1.log" ]; do sleep 0.2; i=$((i+1)); done
if [ "$launch" = ok ]; then
  { grep -q -x "FLEET_REPO=$REPO" "$LG/atlas-ic-1.log" && grep -q -x "FLEET_HOME=$FH" "$LG/atlas-ic-1.log" \
    && grep -q -x "arg: $REPO/shared/launch/ic-settings.json" "$LG/atlas-ic-1.log"; } 2>/dev/null || launch="FAIL (stub saw wrong or no launch line)"
fi

echo "rehearsal lead turn: $lead"
echo "rehearsal launch: $launch"
rc=0
[ "$lead" = ok ] && [ "$launch" = ok ] || rc=1
if [ "$MODE" = rehearsal ]; then
  count_paths "$AM" "$RCH" "$SOCK" "old-repo paths" || rc=1
  exit $rc
fi

# rolled back: install from the old repo again, the forward launch is over, then count this clone's path
tmux -L "$SOCK" kill-server >/dev/null 2>&1
bash "$HERE/install.sh" --repo "$AM" --home "$RH" --claude-home "$RCH" >/dev/null 2>&1 || fail "rehearsal: rollback install failed"
count_paths "$REPO" "$RCH" "$SOCK" "new-repo paths" || rc=1
exit $rc
