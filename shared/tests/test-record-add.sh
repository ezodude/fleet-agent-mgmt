#!/bin/bash
# Tests for shared/records/record-add.sh and shared/records/record_add.py, against a record folder and a worktree in a
# temp dir. Never touches ~/.fleet-agent-mgmt. Jev is never called: JEV_STUB answers, JEV_ENV names no key
# file and JEV_URL is a closed port.
#   shared/tests/test-record-add.sh            prints one line per case, then "N pass, M fail"; exit 1 on any fail
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }
export JEV_ENV="$T/nokey" JEV_URL="http://127.0.0.1:9/" FLEET_RECORDS="$T/records" JEV_STUB_OK=1   # the audit counts stubbed receipts (tests only)
R="$T/records/atlas/atl-42-r1"; W="$T/wt"; mkdir -p "$R" "$W"
git -C "$W" init -q

# the freeze, by hand: rules.md and gate.md, the spec they froze from committed in the worktree,
# stop1.log naming that commit, frozen.sha256 over the two files (as shared/records/freeze-rules.sh leaves them)
printf 'rules · ATL-42 r1 · frozen at 9b2e7c1\n\nTERMS\n  none\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n  any run against the shared dev database   [gate block]\n\nDECIDED  never change:\n  none\n\nREJECTED  do not come back to:\n  none\n' > "$R/rules.md"
printf 'gate · ATL-42 r1 · frozen at 9b2e7c1 · 2026-10-08 09:00\n\nGATE BLOCK\n  proves done   make test\n  pass          exit 0\n' > "$R/gate.md"
mkdir -p "$W/docs/specs"
printf '# ATL-42: retry failed nightly imports\n\n## Terms\n\n```\nTERMS\n  none\n```\n\n## One-way\n\n```\nONE-WAY  stop and ask before:\n  any run against the shared dev database   [gate block]\n```\n\n## Decided\n\n```\nDECIDED  never change:\n  none\n```\n\n## Rejected\n\n```\nREJECTED  do not come back to:\n  none\n```\n\n## Checks\n\n```\n  proves done   make test\n  pass          exit 0\n  on main       ok\n```\n\n---\n\n## Amendments\n\nnone\n' > "$W/docs/specs/atl-42.md"
git -C "$W" add docs/specs/atl-42.md; git -C "$W" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m spec
A="$(git -C "$W" rev-parse HEAD)"; hx(){ shasum -a 256 "$1" | cut -d' ' -f1; }
printf '2026-10-08 08:50 · STOP 1 · spec docs/specs/atl-42.md @ %s · test-ic · session s1\n' "$A" > "$R/stop1.log"
printf 'frozen · ATL-42 r1 · 2026-10-08 09:00\nspec      docs/specs/atl-42.md\napproved  %s\nsha256    %s  rules.md\nsha256    %s  gate.md\n' "$A" "$(hx "$R/rules.md")" "$(hx "$R/gate.md")" > "$R/frozen.sha256"
printf '{"model":"jev-stub","answers":{"standing-1":{"type":"noul","noul":0.05},"standing-2":{"type":"noul","noul":0.03},"oneway-8":{"type":"noul","noul":0.02}}}' > "$T/stub-ok.json"
printf '{"model":"jev-stub","answers":{"standing-1":{"type":"noul","noul":0.91},"standing-2":{"type":"noul","noul":0.03},"oneway-8":{"type":"noul","noul":0.02}}}' > "$T/stub-push.json"
export JEV_STUB="$T/stub-ok.json"
D="$R/decision-record.md"; E="$R/evidence.md"
add() { (cd "$W" && "$HERE/records/record-add.sh" "$@"); }
dr_body() { printf '%s\n  plan        5 "push the branch"\n  question    -\n  decided     %s\n  instead of  -\n  because     receipt 13:40 green\n  undo        git push --delete origin feat/atl-42\n  evidence    E7\n  review      -\n' "$1" "$2"; }
same() { cmp -s "$1" "$2" && echo same || echo changed; }

# 1 a DR: numbered from the file, stamped, at the end, checked, audited
printf '# ATL-42 rung 1 · decision record · test-ic\ngoal: x\nrules: 9b2e7c1\nplan: p\n\nATL-42 DR1 · task 2 · 2026-10-08 11:00 · test-ic\n  plan        2 "x"\n  decided     wrap scheduler.nightly()\n  undo        git revert a\n' > "$D"
(cd "$W" && python3 "$HERE/hooks/dr_check.py" "$D" --worktree "$W" >/dev/null)   # DR1's jev line and receipt, as the hook leaves them
out="$(dr_body "task 5" "push feat/atl-42 to origin" | add "$R" dr 2>&1)"; rc=$?
check "dr: exit 0" "$rc" "0"
check "dr: prints the entry id" "$(echo "$out" | head -1)" "record-add: ATL-42 DR2 appended to $D"
check "dr: header numbered, stamped, lane and IC from the file header" "$(grep -c '^ATL-42 DR2 · task 5 · 20[0-9-]* [0-9:]* · test-ic$' "$D")" "1"
check "dr: one blank line above the entry" "$(grep -B1 '^ATL-42 DR2 ·' "$D" | head -1)" ""
check "dr: the jev line lands under the new entry, last line of the file" "$(tail -1 "$D")" "  jev         continue, max yes 0.05 · jev-stub"
check "dr: prints the jev line" "$(echo "$out" | grep -c '^  jev         continue, max yes 0.05 · jev-stub$')" "1"
check "dr: prints the check's note with the receipt" "$(echo "$out" | grep -c '^jev · ATL-42 DR2: continue.*Receipt: .*-jev-DR2.json')" "1"
check "dr: prints the audit result" "$(echo "$out" | tail -1)" "audit: exit 0, every jev line in decision-record.md has its receipt"
check "dr: a receipt for the entry" "$(ls "$R"/receipts/*-jev-DR2.json | wc -l | tr -d ' ')" "1"

# 2 a UAT: no first line needed, its own numbering
printf '  words       "the alert names the file" (test-ic pane, 10:04)\n  done        alert message names the file\n  commit      c3d4e5f\n  undo        git revert c3d4e5f\n' | add "$R" uat >/dev/null 2>&1
check "uat: numbered UAT1, header with no middle part" "$(grep -c '^ATL-42 UAT1 · 20[0-9-]* [0-9:]* · test-ic$' "$D")" "1"
out="$(printf 'UAT\n  words       "and the run id" (test-ic pane, 10:30)\n  done        alert message names the run id too\n  commit      d4e5f6a\n  undo        git revert d4e5f6a\n' | add "$R" uat 2>&1)"
check "uat: a bare UAT first line is accepted, numbered UAT2" "$(echo "$out" | head -1)" "record-add: ATL-42 UAT2 appended to $D"

# 3 the incident: entries already checked above, a new DR lands at the end and is the one checked
dr_body "task 6" "open PR 88 as a draft" | add "$R" dr >/dev/null 2>&1
check "incident: each jev line sits under its own entry" "$(awk '/^ATL-42 (DR|UAT)[0-9]+ ·/{e=$2} /^  jev/{print e}' "$D" | tr '\n' ' ')" "DR1 DR2 UAT1 UAT2 DR3 "
check "incident: every entry has a receipt" "$(ls "$R"/receipts/ | sed 's/.*-jev-//; s/\.json//' | sort | tr '\n' ' ')" "DR1 DR2 DR3 UAT1 UAT2 "

# 4 a whole header line in the body: its number must agree; its time is replaced
out="$(dr_body "ATL-42 DR4 · task 7 · 2026-01-01 00:00 · test-ic" "tag nothing" | add "$R" dr 2>&1)"; rc=$?
check "header in body: an agreeing number is taken, exit 0" "$rc" "0"
check "header in body: the time is the stamp, not the body's" "$(grep -c '^ATL-42 DR4 · task 7 · 2026-01-01' "$D")" "0"

# 5 refusals: exit 1, the file untouched
cp "$D" "$T/snap"
refused() {  # <case> <kind> <message part>   body on stdin, fed with < <(...) so the count stays in this shell
  local o r; o="$(add "$R" "$2" 2>&1)"; r=$?
  check "refused: $1" "$r $(echo "$o" | grep -c -- "$3") $(same "$D" "$T/snap")" "1 1 same"
}
refused "a number that disagrees" dr "the body says DR9; the next entry in the file is DR5" < <(dr_body "ATL-42 DR9 · task 7" "x")
refused "another lane" dr "the body names lane ATL-1" < <(dr_body "ATL-1 DR5 · task 7" "x")
refused "a UAT body under dr" dr "the body is a UAT entry" < <(dr_body "UAT · task 7" "x")
refused "a DR with no first line" dr "starts with an indented line" < <(printf '  plan        5 "x"\n  decided     x\n')
refused "a jev line in the body" dr "the Jev check writes it" < <(printf 'task 5\n  plan        5 "x"\n  decided     x\n  jev         continue, max yes 0.01 · jev-stub\n')
refused "a review line in the body" dr "lead-1 writes it" < <(printf 'task 5\n  plan        5 "x"\n  decided     x\n  review      ok\n')
refused "a blank line inside a DR" dr "body line 3 is blank" < <(printf 'task 5\n  plan        5 "x"\n\n  decided     x\n')
refused "two entries in one body" dr "body line 3 is not indented" < <(printf 'task 5\n  plan        5 "x"\nATL-42 DR6 · task 6\n  decided     y\n')
refused "an id then a word, no separator (DR7 push)" dr "the body says DR7; the next entry in the file is DR5" < <(dr_body "DR7 push" "x")
refused "a lane and an id with a colon (ATL-42 DR3: push)" dr "the body says DR3; the next entry in the file is DR5" < <(dr_body "ATL-42 DR3: push" "x")
refused "another IC's name after the stamp" dr "the body names IC other-ic; the file's header names test-ic" < <(dr_body "ATL-42 DR5 · task 7 · 2026-01-01 00:00 · other-ic" "x")
refused "a DR with no decided line" dr 'no `decided` line' < <(printf 'task 5\n  plan        5 "x"\n  because     y\n')
refused "a UAT with no done line" uat 'no `done` line' < <(printf '  words       "x"\n  commit      a\n')
check "refused: the snapshot still matches after every refusal" "$(same "$D" "$T/snap")" "same"
check "refused: no receipt for a refused entry" "$(ls "$R"/receipts/ | grep -c -- '-jev-DR5')" "0"

# 6 evidence: E numbering from the file, no Jev check
printf '# ATL-42 rung 1 · evidence · test-ic\n\n## E1 make test on origin/main · 2026-10-14 10:00\n  ran       make test\n  exit      0\n\n## E3 probe · 2026-10-14 10:05\n  ran       x\n  exit      0' > "$E"
out="$(printf 'make test after task 2\n  ran       make test\n  where     %s · feat/atl-42 · HEAD abc1234\n  exit      0\n  output    148 passed, 0 failed\n  proves    the suite\n  does not  prove the retry\n' "$W" | add "$R" e 2>&1)"; rc=$?
check "e: exit 0, numbered past the highest E" "$rc $(echo "$out" | head -1)" "0 record-add: E4 appended to $E"
check "e: header stamped" "$(grep -c '^## E4 make test after task 2 · 20[0-9-]* [0-9:]*$' "$E")" "1"
check "e: a file with no trailing newline gets one blank line above the entry" "$(grep -B2 '^## E4' "$E" | head -2 | tr '\n' '|')" "  exit      0||"
check "e: no Jev check, no jev line" "$(grep -c '^  jev' "$E"; echo "$out" | grep -c 'audit')" "0
0"
cp "$E" "$T/esnap"
o="$(printf '## E2 rerun · 2026-10-14 11:00\n  ran       x\n  exit      0\n' | add "$R" e 2>&1)"; r=$?
check "e: a number that disagrees is refused" "$r $(echo "$o" | grep -c 'the body says E2; the next entry in the file is E5') $(same "$E" "$T/esnap")" "1 1 same"
o="$(printf 'rerun\n  ran       x\n  output    y\n' | add "$R" e 2>&1)"; r=$?
check "e: no exit line is refused" "$r $(echo "$o" | grep -c 'no `exit` line')" "1 1"
printf 'probe with a blank\n  ran       x\n  exit      0\n  output    a\n\n            b\n' | add "$R" e >/dev/null 2>&1
check "e: a blank line inside an E entry is kept (evidence is read by its ## headers)" "$(grep -c '^## E5 probe with a blank' "$E")" "1"

# 7 no header, no file
R2="$T/records/atlas/atl-42-r2"; mkdir -p "$R2"
o="$(dr_body "task 1" "x" | add "$R2" dr 2>&1)"; r=$?
check "no file: refused, names the header" "$r $(echo "$o" | grep -c 'The first write of the file is its header')" "1 1"
printf 'ATL-42 DR1 · task 1 · 2026-10-08 11:00 · test-ic\n  decided     x\n' > "$R2/decision-record.md"; cp "$R2/decision-record.md" "$T/snap2"
o="$(dr_body "task 1" "x" | add "$R2" dr 2>&1)"; r=$?
check "no header first: refused, file untouched" "$r $(echo "$o" | grep -c 'does not start with its header') $(same "$R2/decision-record.md" "$T/snap2")" "1 1 same"
o="$(add "$R" dx </dev/null 2>&1)"; r=$?
check "usage: an unknown kind is exit 2" "$r" "2"

# 8 --dump: shows the entry, writes nothing, checks nothing
cp "$D" "$T/snap"; n="$(ls "$R"/receipts | wc -l)"
o="$(dr_body "task 8" "dump me" | add --dump "$R" dr 2>&1)"
check "dump: shows the header it would write" "$(echo "$o" | grep -c '^ATL-42 DR5 · task 8 · ')" "1"
check "dump: nothing written, no receipt" "$(same "$D" "$T/snap") $(ls "$R"/receipts | wc -l | tr -d ' ')" "same $(echo $n)"

# 9 the verdict and the audit are surfaced, and a failed audit is exit 3
o="$(dr_body "task 9" "force-push feat/atl-42" | JEV_STUB="$T/stub-push.json" add "$R" dr 2>&1)"
check "verdict: a stop and ask is printed with its note" "$(echo "$o" | grep -c '^jev · ATL-42 DR5: stop and ask, standing-1 0.91.*Ask in this pane')" "1"
printf '\nATL-42 DR6 · task 9 · 2026-10-14 12:00 · test-ic\n  decided     x\n  jev         continue, max yes 0.01 · jev-stub\n' >> "$D"   # a jev line written by hand, no receipt
o="$(dr_body "task 9" "push feat/atl-42" | add "$R" dr 2>&1)"; r=$?
check "audit: a jev line with no receipt is exit 3, named" "$r $(echo "$o" | grep -c '^ATL-42 DR6: jev')" "3 1"
check "audit: the new entry is still checked" "$(tail -1 "$D")" "  jev         continue, max yes 0.05 · jev-stub"

# 10 no key, no stub: the check did not run, said so; Jev never called
o="$(dr_body "task 10" "no key" | (cd "$W" && env -u JEV_STUB "$HERE/records/record-add.sh" "$R" dr) 2>&1)"
check "no key: stop and ask, no check, under the new entry" "$(tail -1 "$D")" "  jev         stop and ask, no check (no key)"

echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ]
