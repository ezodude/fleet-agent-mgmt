#!/bin/bash
# Append one entry to a rung's decision record or evidence file, at the end, in one short call.
#   shared/records/record-add.sh <record folder> dr|uat|e <<'EOF'
#   task 5                              (dr: what goes between the id and the time; e: what was run, five words; uat: none)
#     plan        5 "push the branch and open a draft PR at a green gate receipt"
#     decided     ...
#   EOF
# Run from the worktree, as gate-run.sh is. dr and uat write decision-record.md, e writes
# evidence.md. Numbers the entry from the file (the next DR<n>, UAT<n> or E<n>), stamps it
# "YYYY-MM-DD HH:MM" and takes the lane and the IC from the file's header. For dr and uat it
# then runs the dr-check hook's Jev check (shared/hooks/dr_check.py, with this worktree as
# --worktree, as the hook passes the session's cwd), so the jev line lands under the new entry,
# and then dr_check.py --audit. Prints the entry id, the jev line, the check's note and the
# audit's result.
# The file logic, the refusals and the IC's Edit guard are shared/records/record_add.py (read it).
#   shared/records/record-add.sh --dump <record folder> dr|uat|e < body    shows the entry as it would land; no write, no check
# The check runs in this shell's environment. A receipt made with JEV_STUB, another JEV_URL or DR_STANDING
# set records it, and the audit at "ready for push" and at the push (run in the hook's environment) does not
# count it; the script says so when one is set.
# Exit 0 written (and, for dr and uat, checked with a clean audit) · 1 refused, nothing written · 2 usage ·
#      3 written, but no jev line landed under it or the audit names an entry it does not pass.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
usage="usage: record-add.sh [--dump] <record folder> dr|uat|e < body"
dump=""; [ "${1:-}" = "--dump" ] && { dump="--dump"; shift; }
[ $# -eq 2 ] || { echo "$usage" >&2; exit 2; }
rec="${1%/}"; kind="$2"
case "$kind" in dr|uat) file=decision-record.md ;; e) file=evidence.md ;; *) echo "$usage" >&2; exit 2 ;; esac
[ -d "$rec" ] || { echo "record-add: no record folder $rec" >&2; exit 1; }
path="$rec/$file"
body="$(cat)"
now="$(date '+%Y-%m-%d %H:%M')"
eid="$(RA_BODY="$body" RA_NOW="$now" python3 "$HERE/record_add.py" "$path" "$kind" $dump)" || exit $?
[ -n "$dump" ] && { printf '%s\n' "$eid"; exit 0; }
echo "record-add: $eid appended to $path"
[ "$kind" = e ] && exit 0
# the Jev check on the new entry (and any entry still without a jev line), as the dr-check hook runs it
set_vars="$(env | sed -nE 's/^(JEV_STUB|JEV_URL|DR_STANDING)=.*/\1/p' | tr '\n' ' ')"
[ -n "$set_vars" ] && echo "record-add: ${set_vars}set in this shell: the receipt records it, and the audit at ready for push and at the push does not count it."
ctx="$(python3 "$HERE/../hooks/dr_check.py" "$path" --worktree "$PWD" \
  | python3 -c 'import json,sys; t=sys.stdin.read().strip(); print(json.loads(t)["hookSpecificOutput"]["additionalContext"] if t else "")')" || ctx=""
jev="$(python3 "$HERE/record_add.py" "$path" --jev "$eid")"
rc=0
if [ -n "$jev" ]; then printf '%s\n' "$jev"; else
  echo "record-add: no jev line under $eid: the check did not run. Put this entry to the owner in the pane before acting; do not grade it yourself."; rc=3; fi
[ -n "$ctx" ] && printf '%s\n' "$ctx"
if audit="$(python3 "$HERE/../hooks/dr_check.py" "$path" --audit)"; then
  echo "audit: exit 0, every jev line in $file has its receipt"
else
  echo "audit: exit 1 (the push and the ready-for-push report are refused until it is fixed; tell lead-1, never move or edit lines by hand):"
  printf '%s\n' "$audit"; rc=3
fi
exit $rc
