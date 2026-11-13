#!/bin/bash
# check-frozen.sh [<AgentMgmt>]
# Is the old AgentMgmt still as it was at the ledger copy? Prints "frozen: ok" or
# "frozen: changed (<what>)" or "frozen: unknown (<why>)", exit 0 only for ok.
# When the old ledger exists, also prints "old ledger: read-only|writable" (information only).
set -u
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/paths.sh"
LEDGER_REL="Leads/lead-1/LEDGER.md"
M="$FLEET_HOME/migrate"
unknown() { echo "frozen: unknown ($1)"; [ -n "${lstate:-}" ] && echo "old ledger: $lstate"; exit 1; }

lstate=""
if [ $# -ge 1 ]; then
  AM="$1"
else
  [ -f "$M/agentmgmt-path" ] || unknown "no migrate/agentmgmt-path"
  AM="$(cat "$M/agentmgmt-path")"
fi
[ -d "$AM" ] || unknown "no such AgentMgmt folder"
LED="$AM/$LEDGER_REL"
[ -f "$LED" ] || unknown "no old ledger"
if [ -w "$LED" ]; then lstate=writable; else lstate=read-only; fi
for f in agentmgmt-head ledger-sha256; do
  [ -f "$M/$f" ] || unknown "no migrate/$f"
done
want_head="$(cat "$M/agentmgmt-head")"
want_sha="$(cat "$M/ledger-sha256")"
head="$(git -C "$AM" rev-parse HEAD 2>/dev/null)" || unknown "cannot read HEAD"
sha="$(shasum -a 256 "$LED" | cut -d' ' -f1)"
tracked="$(git -C "$AM" status --porcelain --untracked-files=no 2>/dev/null)" || unknown "git status failed"

bad=""
[ "$head" = "$want_head" ] || bad="HEAD differs"
[ -z "$bad" ] && [ -n "$tracked" ] && bad="tracked change"
[ -z "$bad" ] && [ "$sha" != "$want_sha" ] && bad="ledger hash differs"
if [ -n "$bad" ]; then
  echo "frozen: changed ($bad)"
  echo "old ledger: $lstate"
  exit 1
fi
echo "frozen: ok"
echo "old ledger: $lstate"
