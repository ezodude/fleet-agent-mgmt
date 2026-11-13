#!/bin/bash
# check-cutover.sh lead | worker [<name>]
# Proof that the fleet runs on this clone. Prints "lead: ok" / "worker: ok" and exits 0;
# red or not-yet prints what failed, exit 1; a source that cannot be read prints
# "<mode>: unknown (<why>)", exit 1.
#   lead   : >=3 "pass lead-1" lines in checks/lead-1/state-gate.log after migrate/install-stamp,
#            one of them after a commit in FLEET_HOME made after the stamp, and the old
#            LEDGER.md still hashing to migrate/ledger-sha256, and the roster's lead-1 cwd
#            being $FLEET_HOME/Leads/lead-1 ("lead: red: roster lead-1 cwd <x>" otherwise).
#   worker : a checks/<name>/STATE.md (any name but lead-1, or the one named) whose file mtime
#            is after the stamp and whose launch receipt (checks/<name>/launch, written by agent-up.sh) is newer than the stamp and names this clone, not the old AgentMgmt.
set -u
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/paths.sh"
MODE="${1:-}"
case "$MODE" in lead|worker) ;; *) echo "usage: check-cutover.sh lead | worker [<name>]" >&2; exit 2 ;; esac
M="$FLEET_HOME/migrate"
LEDGER_REL="Leads/lead-1/LEDGER.md"
unknown() { echo "$MODE: unknown ($1)"; exit 1; }
[ -f "$M/install-stamp" ] || unknown "no install stamp"
STAMP="$(head -1 "$M/install-stamp")"
[ -n "$STAMP" ] || unknown "no install stamp"
[ -f "$M/agentmgmt-path" ] || unknown "no migrate/agentmgmt-path"
OLD="$(cat "$M/agentmgmt-path")"

# epoch of an ISO time (Z or +hh:mm); empty when unparseable
epoch() {
  python3 -c '
import sys, datetime
s = sys.argv[1].strip()
if s.endswith("Z"): s = s[:-1] + "+00:00"
try:
    d = datetime.datetime.fromisoformat(s)
    if d.tzinfo is None: d = d.replace(tzinfo=datetime.timezone.utc)
    print(int(d.timestamp()))
except Exception:
    pass' "$1"
}
SE="$(epoch "$STAMP")"
[ -n "$SE" ] || unknown "install stamp unreadable"

if [ "$MODE" = lead ]; then
  top="$(git -C "$FLEET_HOME" rev-parse --show-toplevel 2>/dev/null)" || unknown "FLEET_HOME is not a git repo"
  [ "$top" = "$(cd -P "$FLEET_HOME" && pwd)" ] || unknown "FLEET_HOME is not a git repo"
  [ -f "$M/ledger-sha256" ] || unknown "no migrate/ledger-sha256"
  [ -f "$FLEET_HOME/roster.md" ] || unknown "no roster at $FLEET_HOME/roster.md"
  rcwd="$(awk '/^```fleet/{f=1;next} /^```/{f=0} f && NF>=2 {split($0,a,"\t"); if (a[1]=="lead-1") {print a[2]; exit}}' "$FLEET_HOME/roster.md")"
  want_cwd="$FLEET_HOME/Leads/lead-1"
  if [ "$rcwd" != "$want_cwd" ]; then
    r1="$(cd -P "$rcwd" 2>/dev/null && pwd)"; r2="$(cd -P "$want_cwd" 2>/dev/null && pwd)"
    if [ -z "$rcwd" ] || [ -z "$r1" ] || [ "$r1" != "$r2" ]; then echo "lead: red: roster lead-1 cwd ${rcwd:-none}"; exit 1; fi
  fi
  OLDL="$OLD/$LEDGER_REL"; COPY="$FLEET_HOME/$LEDGER_REL"
  [ -f "$OLDL" ] || unknown "no old ledger"
  [ -f "$COPY" ] || unknown "no copied ledger"
  commits="$(git -C "$FLEET_HOME" log --format=%cI 2>/dev/null)"
  log="$FLEET_HOME/checks/lead-1/state-gate.log"
  passes=""; [ -f "$log" ] && passes="$(awk '$2=="pass" && $3=="lead-1" {print $1}' "$log")"
  res="$(PASSES="$passes" COMMITS="$commits" python3 -c '
import os, sys, datetime
def ep(s):
    s = s.strip()
    if s.endswith("Z"): s = s[:-1] + "+00:00"
    try:
        d = datetime.datetime.fromisoformat(s)
        if d.tzinfo is None: d = d.replace(tzinfo=datetime.timezone.utc)
        return d.timestamp()
    except Exception:
        return None
stamp = ep(sys.argv[1])
ps = [x for x in (ep(l) for l in os.environ["PASSES"].splitlines()) if x is not None and x > stamp]
cs = [x for x in (ep(l) for l in os.environ["COMMITS"].splitlines()) if x is not None and x > stamp]
after = bool(cs) and any(p > min(cs) for p in ps)
print(len(ps), "yes" if after else "no")' "$STAMP")"
  n="${res% *}"; aft="${res#* }"
  fails=""
  [ "$n" -ge 3 ] || fails="$n of 3 passes after the install stamp"
  [ "$aft" = yes ] || fails="${fails:+$fails; }no pass after a commit made since the install stamp"
  want="$(cat "$M/ledger-sha256")"
  got="$(shasum -a 256 "$OLDL" | cut -d' ' -f1)"
  if [ "$got" != "$want" ]; then
    fails="${fails:+$fails; }old ledger changed since the copy"
    diff "$COPY" "$OLDL" | sed -n 's/^> /new old-ledger line: /p'
  fi
  if [ -n "$fails" ]; then echo "lead: red ($fails)"; exit 1; fi
  echo "lead: ok"; exit 0
fi

# ---- worker ----
shift
# does <line> contain <path> as a whole path (not a prefix of a sibling)?
names() { LINE="$1" python3 -c '
import os, re, sys
print("y" if re.search(re.escape(sys.argv[1]) + r"(?![A-Za-z0-9._-])", os.environ["LINE"]) else "n")' "$2"; }

if [ $# -ge 1 ]; then names_list="$1"
else
  names_list=""
  for d in "$FLEET_HOME"/checks/*/; do
    [ -f "${d}STATE.md" ] || continue
    n="$(basename "$d")"; [ "$n" = lead-1 ] || names_list="$names_list $n"
  done
fi
[ -n "${names_list# }" ] || { echo "worker: not yet (no worker STATE.md under $FLEET_HOME/checks)"; exit 1; }
okn=""; why=""
for n in $names_list; do
  st="$FLEET_HOME/checks/$n/STATE.md"
  if [ ! -f "$st" ]; then why="$why$n: no STATE.md; "; continue; fi
  mt="$(stat -f %m "$st" 2>/dev/null || stat -c %Y "$st" 2>/dev/null)"
  if [ -z "$mt" ] || [ "$mt" -le "$SE" ]; then why="$why$n: STATE.md not newer than the install stamp; "; continue; fi
  rc="$FLEET_HOME/checks/$n/launch"
  if [ ! -f "$rc" ]; then why="$why$n: no launch receipt; "; continue; fi
  rt="$(epoch "$(sed -n 1p "$rc")")"
  if [ -z "$rt" ] || [ "$rt" -le "$SE" ]; then why="$why$n: launch receipt not newer than the install stamp; "; continue; fi
  line="$(sed -n 2p "$rc")"
  if [ "$(names "$line" "$OLD")" = y ]; then why="$why$n: launch receipt names the old AgentMgmt; "; continue; fi
  if [ "$(names "$line" "$FLEET_REPO")" != y ]; then why="$why$n: launch receipt does not name this clone; "; continue; fi
  okn="$okn $n"
done
if [ -n "$okn" ]; then echo "worker qualifies:$okn"; echo "worker: ok"; exit 0; fi
echo "worker: not yet (${why%; })"; exit 1
