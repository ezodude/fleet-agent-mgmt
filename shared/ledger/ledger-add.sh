#!/bin/bash
# Append one entry to lead-1's ledger and commit it, in one short call.
#   shared/ledger/ledger-add.sh "<title>" [key=value ...] <<'EOF'
#   <entry body, markdown>
#   EOF
# Numbers the entry (+N, newest first, after "## Log (newest first)"), stamps
# it "(YYYY-MM-DD HH:MM BST, HH:MMZ)", rewrites any state keys given as
# key=value (awaiting=..., stop=..., next=...), sets head: to the current
# HEAD "(ledger commit follows)" and updated: to now, commits
# "chore: ledger +N <title>" and prints "+N <hash>".
# Held rows go through the same call and the same commit:
#   held+="<row>"     one row under the header of "## held" (newest first)
#   held-="<text>"    the one row containing <text>; 0 or 2+ matches: exit 1, nothing changes
#   held-note="<t>"   the heading's parenthetical
# The file logic is shared/ledger/ledger_add.py (read it for the guard and --dump).
#   shared/ledger/ledger-add.sh --dump "<title>" [key=value ...] < body    shows what would land; no write, no commit
# A failed check leaves the ledger as it was and nothing is added or committed.
# The fleet check runs first (shared/fleet/fleet-check.sh; tests point it at temp dirs
# through its FLEET_* env): any FAIL refuses the entry, nothing written or
# committed; a WARN is printed and the entry goes on. --dump prints the check
# and dumps anyway, since it writes nothing. An awaiting= value is checked
# the same way against the STATE schema's rule (shared/hooks/STATE-schema.md):
# none, or owner:, lead-1: or a roster name then the text.
set -euo pipefail
. "$(cd -P "$(dirname "$0")" && pwd)/../lib/paths.sh"
REPO="${LEDGER_REPO:-$FLEET_HOME}"
LEDGER="${LEDGER_FILE:-Leads/lead-1/LEDGER.md}"
SIGN="${LEDGER_SIGN:-}"          # empty: git config decides signing (commit.gpgsign); a test may set --no-gpg-sign
dump=""; [ "${1:-}" = "--dump" ] && { dump="--dump"; shift; }
title="${1:?usage: ledger-add.sh [--dump] \"<title>\" [key=value ...] < body}"; shift
if ! "$(dirname "$0")/../fleet/fleet-check.sh" >&2; then
  [ -n "$dump" ] || { echo "ledger-add: refused by shared/fleet/fleet-check.sh: fix each FAIL above, then add the entry again. Nothing was written or committed." >&2; exit 1; }
fi
# awaiting=<v> is checked by the state gate's own shape(), the rule the stop
# gate applies to the state fence, before anything is written.
for a in "$@"; do
  case "$a" in awaiting=*) ;; *) continue;; esac
  gate="${FLEET_STATE_GATE:-$(dirname "$0")/../hooks/state-gate.sh}"
  eval "$(sed -n '/^shape() {$/,/^}$/p' "$gate" 2>/dev/null)"
  if ! declare -F shape >/dev/null; then why="cannot read shape() from $gate"
  else
    t="$(mktemp)"; printf '```state\nawaiting: %s\n```\n' "${a#awaiting=}" > "$t"
    why="$(shape "$t" lead | sed 's/^line [0-9]* //')"; rm -f "$t"
  fi
  [ -z "$why" ] && continue
  echo "ledger-add: $a: $why" >&2
  [ -n "$dump" ] || { echo "ledger-add: refused: fix the awaiting= value, then add the entry again. Nothing was written or committed." >&2; exit 1; }
done
body="$(cat)"
cd "$REPO"
now="$(date '+%Y-%m-%d %H:%M')"; z="$(TZ=UTC date '+%H:%M')Z"
n=$(( $(grep -o '^### +[0-9]*' "$LEDGER" | tr -dc '0-9\n' | sort -n | tail -1) + 1 ))
head="$(git rev-parse --short HEAD)"
LA_TITLE="$title" LA_BODY="$body" LA_NOW="$now" LA_Z="$z" LA_N="$n" LA_HEAD="$head" \
  python3 "$(dirname "$0")/ledger_add.py" "$LEDGER" $dump "$@"
[ -n "$dump" ] && exit 0
git add "$LEDGER"
git commit $SIGN -q -m "chore: ledger +$n $title" -- "$LEDGER"   # by path: a file staged elsewhere stays staged, never rides in
echo "+$n $(git rev-parse --short HEAD)"
