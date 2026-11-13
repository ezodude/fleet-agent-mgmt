#!/bin/bash
# Tests for shared/ledger/ledger-add.sh and shared/ledger/ledger_add.py, against a copy of a
# ledger in a temp git repo. Never touches Leads/lead-1/LEDGER.md.
#   shared/tests/test-ledger-add.sh            prints one line per case, then "N pass, M fail"; exit 1 on any fail
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }

# a small ledger with the real anchors: state block, held table, log
mkdir -p "$T/repo/Leads/lead-1"; cd "$T/repo"; git init -q; git config user.email t@t; git config user.name t
cat > Leads/lead-1/LEDGER.md <<'EOF'
# lead-1 ledger

```state
session: lead-1
head: 0000000 (ledger commit follows)
updated: 2026-10-13 09:00 BST
awaiting: none
```

## held  (grill: atlas paused at Q2 since 2026-10-12)

  TIME   IC        LANE      KIND   GLYPH  CLOCK  CHECK
  10:10  atlas-ic  ATL-42    STOP   ·      0:40   -
  10:20  nova-ic   NOV-7     STOP   ·      0:30   -

## Fleet

one line about the fleet

## Log (newest first)

### +41 (2026-10-13 09:00 BST, 08:00Z) earlier entry

body of 41

EOF
git add Leads/lead-1/LEDGER.md; git commit -q -m init

# a clean fleet home and a clean tree to scan, so every case runs the fleet
# check (shared/fleet/fleet-check.sh) against temp dirs, never ~/.fleet-agent-mgmt
F="$T/fleet"; mkdir -p "$F/records/atlas/atl-41-r1" "$F/profiles" "$F/checks/atlas-ic" "$T/scan/shared"
git -C "$F" init -q; git -C "$F" config user.email t@t; git -C "$F" config user.name t
printf 'closed\n' > "$F/records/atlas/atl-41-r1/close.md"; printf 'brief\n' > "$F/records/atlas/atl-41-r1/brief.md"
printf 'profile\n' > "$F/profiles/atlas.md"
cat > "$F/checks/atlas-ic/STATE.md" <<'EOF'
```state
session: atlas-ic
role: ic
rung: ATL-42 r1
handoff: none
repo: none
branch: none
head: none
pushed: no
dirty: 0
stop: none
awaiting: none
notice: none
next: none
updated: 2026-10-13 09:00 BST
evidence: none
```

## log
EOF
git -C "$F" add records profiles; git -C "$F" commit -q -m init
printf 'states live in ~/.fleet-agent-mgmt/checks\n' > "$T/scan/shared/roster.md"
# the roster the state gate's shape() reads for the names an awaiting line may open with
printf '**owner: Robin** (the owner)\n\n```fleet\nlead-1\t/x\natlas-ic\t/y\ndbx-ic\t/z\n```\n' > "$T/roster.md"
export FLEET_HOME="$F" FLEET_CHECK_SCAN="$T/scan" FLEET_ROSTER="$T/roster.md"
export LEDGER_REPO="$T/repo" LEDGER_SIGN=--no-gpg-sign
L="$T/repo/Leads/lead-1/LEDGER.md"
add() { "$HERE/ledger/ledger-add.sh" "$@"; }
lines() { wc -l < "$L" | tr -d ' '; }
held_rows() { sed -n '/^## held/,/^## Fleet/p' "$L" | grep -c '^  [0-9]'; }

# 1 entry only: numbering, stamp, head, commit
out="$(echo "body 42" | add "first title" 2>&1)"
check "entry: prints +N and the sha" "$(echo "$out" | tail -1 | cut -d' ' -f1)" "+42"
check "entry: inserted after the log anchor" "$(grep -c '^### +42 (.* BST, ..:..Z) first title$' "$L")" "1"
check "entry: head rewritten with the pre-commit sha" "$(grep -c '^head: [0-9a-f]\{7\} (ledger commit follows)$' "$L")" "1"
check "entry: one commit, by path" "$(git log --oneline | head -1 | cut -d' ' -f2-)" "chore: ledger +42 first title"
check "entry: tree clean after" "$(git status --short | wc -l | tr -d ' ')" "0"

# 2 held+= with a state key in the same call and commit
before=$(lines)
out="$(echo "body 43" | add "held add" awaiting="atlas-ic: STOP 2" held+="11:00  dbx-ic   ATL-1     STOP   ·      0:05   -" 2>&1)"
check "held+: row sits directly under the header" "$(sed -n '/^  TIME   IC/{n;p;}' "$L")" "  11:00  dbx-ic   ATL-1     STOP   ·      0:05   -"
check "held+: three rows now" "$(held_rows)" "3"
check "held+: state key in the same write" "$(grep -c '^awaiting: atlas-ic: STOP 2$' "$L")" "1"
check "held+: line count +entry(4)+row(1)" "$(( $(lines) - before ))" "5"
check "held+: one commit for all of it" "$(git log --oneline | wc -l | tr -d ' ')" "3"
out="$(echo "b" | add "no spaces" held+="12:00  x-ic  X-1  STOP  ·  0:01  -" 2>&1)"
check "held+: two spaces added to a bare row" "$(grep -c '^  12:00  x-ic' "$L")" "1"

# 3 held-= exactly one match
before=$(lines)
out="$(echo "body" | add "held remove" held-="nova-ic" 2>&1)"
check "held-: the row is gone" "$(grep -c 'nova-ic' "$L")" "0"
check "held-: the others stay" "$(held_rows)" "3"
check "held-: line count +4-1" "$(( $(lines) - before ))" "3"

# 4 held-= matching 0 rows: exit 1, nothing changed, no commit
cp "$L" "$T/snap"; n=$(git log --oneline | wc -l)
out="$(echo "body" | add "bad remove" held-="nobody-ic" 2>&1)"; rc=$?
check "held- 0 matches: exit 1" "$rc" "1"
check "held- 0 matches: names the count" "$(echo "$out" | grep -c 'matches 0 rows, not 1')" "1"
check "held- 0 matches: file untouched" "$(cmp -s "$L" "$T/snap" && echo same)" "same"
check "held- 0 matches: no commit" "$(git log --oneline | wc -l)" "$n"

# 5 held-= matching more than one row
out="$(echo "body" | add "bad remove" held-="STOP" 2>&1)"; rc=$?
check "held- many matches: exit 1" "$rc" "1"
check "held- many matches: names the count" "$(echo "$out" | grep -c 'matches 3 rows, not 1')" "1"
check "held- many matches: file untouched" "$(cmp -s "$L" "$T/snap" && echo same)" "same"

# 6 held-note=
out="$(echo "body" | add "note" held-note="grill: atlas resumed 13:00" 2>&1)"
check "held-note: heading rewritten" "$(grep -c '^## held  (grill: atlas resumed 13:00)$' "$L")" "1"
out="$(echo "body" | add "note off" held-note= 2>&1)"
check "held-note empty: bare heading" "$(grep -c '^## held$' "$L")" "1"
check "held-note: table rows untouched" "$(held_rows)" "3"

# 7 --dump: shows the change, writes nothing, commits nothing
cp "$L" "$T/snap"; n=$(git log --oneline | wc -l)
out="$(echo "body" | add --dump "dump title" held+="13:00  d-ic  D-1  STOP  ·  0:01  -" 2>&1)"
check "dump: names the entry and the row" "$(echo "$out" | grep -c 'entry       +.* dump title\|held +      13:00  d-ic')" "2"
check "dump: expected delta" "$(echo "$out" | grep -c '^lines       +5 (dump: nothing written)$')" "1"
check "dump: file untouched" "$(cmp -s "$L" "$T/snap" && echo same)" "same"
check "dump: no commit" "$(git log --oneline | wc -l)" "$n"

# 8 the guard: a write that drops lines is caught after the write, before git add
out="$(echo "body" | LEDGER_ADD_FAULT=drop add "faulty" 2>&1)"; rc=$?
check "guard: exit 1" "$rc" "1"
check "guard: names the line count" "$(echo "$out" | grep -c 'after the write.*line count went\|after the write.*entry count went')" "1"
check "guard: nothing staged, no commit" "$(git status --short | grep -c '^[MA]')|$(git log --oneline | wc -l | tr -d ' ')" "0|$(echo $n | tr -d ' ')"
git checkout -q -- Leads/lead-1/LEDGER.md
check "guard: ledger restored from git for the next case" "$(cmp -s "$L" "$T/snap" && echo same)" "same"

# 9 a missing state key fails before any write
cp "$L" "$T/snap"
out="$(echo "body" | add "bad key" nosuchkey=1 2>&1)"; rc=$?
check "state: unknown key exits 1 and names it" "$rc $(echo "$out" | grep -c 'state key not found: nosuchkey')" "1 1"
check "state: file untouched" "$(cmp -s "$L" "$T/snap" && echo same)" "same"

# 9b awaiting= follows the STATE schema: none | owner: | lead-1: | <roster name>:, checked before any write
cp "$L" "$T/snap"; n=$(git log --oneline | wc -l | tr -d ' ')
for v in 'nothing. idle' 'Robin: the S5 word' 'lead-1/Robin: rulings' 'lead-1 and Robin: merge' 'next rung; idle' 'none; owner merge' 'nova-ic: not on the roster' 'lead-1: S5; owner: merge' \
         'lead-1: S5 ruling; Robin: merge' 'lead-1: S5 ruling; Owner: merge' 'atlas-ic: STOP 2; lead-1/Robin: rulings' \
         'Owner: merge' 'OWNER: merge' 'Lead-1: S5' 'Atlas-ic: STOP 2'; do
  out="$(echo "body" | add "bad awaiting" awaiting="$v" 2>&1)"; rc=$?
  check "awaiting= \"$v\": refused, names the value, nothing written or committed" \
    "$rc|$(echo "$out" | grep -cF "ledger-add: awaiting=$v: ")|$(echo "$out" | grep -c '^ledger-add: refused: fix the awaiting= value')|$(cmp -s "$L" "$T/snap" && echo same)|$(git log --oneline | wc -l | tr -d ' ')" "1|1|1|same|$n"
done
check "awaiting= the owner by name after lead-1: names the owner first rule" "$(echo body | add "bad" awaiting="lead-1: S5 ruling; Robin: merge" 2>&1 | grep -cF 'ledger-add: awaiting=lead-1: S5 ruling; Robin: merge: "awaiting" names the owner (Robin:) after lead-1:, write owner: first')" "1"
check "awaiting= old form: the reason states the rule" "$(echo body | add "bad" awaiting="nothing. idle" 2>&1 | grep -c 'open it with none (the whole value), owner:, lead-1: or a roster name')" "1"
out="$(echo "body" | add --dump "dump awaiting" awaiting="Robin: x" 2>&1)"; rc=$?
check "awaiting= --dump: exit 0, the fault and the dump shown, nothing written" "$rc|$(echo "$out" | grep -c '^ledger-add: awaiting=Robin: x: ')|$(echo "$out" | grep -c '(dump: nothing written)')|$(cmp -s "$L" "$T/snap" && echo same)" "0|1|1|same"
for v in 'none' 'owner: PR ready and merge; lead-1: S5 ruling' 'lead-1: the audit' 'atlas-ic: STOP 2 report' "lead-1: relay Robin's ruling to atlas-ic"; do
  out="$(echo "body" | add "good awaiting" awaiting="$v" 2>&1)"; rc=$?
  check "awaiting= \"$v\": written" "$rc|$(grep -cxF "awaiting: $v" "$L")" "0|1"
done
# (the fleet check refuses first without shape(); --dump runs past it to show this check's own line)
check "awaiting= no shape(): a fault, not a pass" "$(echo body | FLEET_STATE_GATE="$T/none.sh" add --dump "no shape" awaiting="none" 2>&1 | grep -c "^ledger-add: awaiting=none: cannot read shape() from $T/none.sh$")" "1"

# 10 a file staged elsewhere stays out of the ledger commit (a4bf65d, 2026-10-14)
echo x > other.txt; git add other.txt
out="$(echo "body" | add "with a staged file" 2>&1)"
check "by path: the commit holds only the ledger" "$(git show --name-only --format= HEAD)" "Leads/lead-1/LEDGER.md"
check "by path: the other file is still staged" "$(git diff --cached --name-only)" "other.txt"
git restore --staged other.txt; rm other.txt

# 11 the fleet check: each fault refuses the entry, nothing written or committed;
# once fixed, the entry is written. snap/refused/written compare against the snap.
fleet_n() { git -C "$F" log --oneline | wc -l | tr -d ' '; }
snap() { cp "$L" "$T/snap"; n=$(git log --oneline | wc -l | tr -d ' '); fn=$(fleet_n); }
refused() {  # $1 case name, $2 the FAIL text expected in $out, $3 the exit code
  check "$1: exit 1" "$3" "1"
  check "$1: names the fault" "$(echo "$out" | grep -c "^FAIL .*$2")" "1"
  check "$1: names the fix" "$(echo "$out" | grep -A1 "^FAIL .*$2" | grep -c '^     fix: ')" "1"
  check "$1: says refused" "$(echo "$out" | grep -c '^ledger-add: refused by shared/fleet/fleet-check.sh')" "1"
  check "$1: ledger untouched, no commit, fleet home not committed" \
    "$(cmp -s "$L" "$T/snap" && echo same)|$(git log --oneline | wc -l | tr -d ' ')|$(fleet_n)" "same|$n|$fn"
}
written() {  # $1 case name; the entry from the last add landed
  check "$1: entry written and committed" "$(git log --oneline | wc -l | tr -d ' ')|$(grep -c "^### +.* $1\$" "$L")" "$((n + 1))|1"
}
old_path() { local p="$HOME/.claude"; printf 'see %s/checks/atlas-ic\n' "$p"; }   # built, so this file does not name the old path itself
age() { python3 -c 'import os,sys,time; t=time.time()-5*86400; [os.utime(p,(t,t)) for p in sys.argv[1:]]' "$@"; }

snap
out="$(echo body | add "fleet clean" 2>&1)"
check "fleet clean: prints the check line" "$(echo "$out" | grep -c '^fleet-check: 0 faults, 0 warnings$')" "1"
written "fleet clean"

# a: a folder with close.md that is not fully committed
mkdir -p "$F/records/atlas/atl-42-r1"; printf 'closed\n' > "$F/records/atlas/atl-42-r1/close.md"
snap; out="$(echo body | add "fault a" 2>&1)"; rc=$?
refused "a close.md uncommitted" "records/atlas/atl-42-r1: has close.md, 1 file not committed" "$rc"
git -C "$F" add records/atlas/atl-42-r1; git -C "$F" commit -q -m "atl-42 close"
snap; out="$(echo body | add "fixed a" 2>&1)"; written "fixed a"

# b: a committed folder changed since: a modified file, then an untracked one (no close.md)
printf 'more\n' >> "$F/records/atlas/atl-41-r1/brief.md"
snap; out="$(echo body | add "fault a2" 2>&1)"; rc=$?
refused "a closed then modified" "records/atlas/atl-41-r1: has close.md, 1 file not committed (1 modified" "$rc"
git -C "$F" checkout -q -- records/atlas/atl-41-r1/brief.md
mkdir -p "$F/records/atlas/atl-43-r1"; printf 'x\n' > "$F/records/atlas/atl-43-r1/brief.md"
git -C "$F" add records/atlas/atl-43-r1; git -C "$F" commit -q -m "atl-43 brief"
printf 'more\n' >> "$F/records/atlas/atl-43-r1/brief.md"
snap; out="$(echo body | add "fault b" 2>&1)"; rc=$?
refused "b modified" "records/atlas/atl-43-r1: committed record changed since, 1 file not committed (1 modified or staged, 0 untracked)" "$rc"
git -C "$F" checkout -q -- records/atlas/atl-43-r1/brief.md
printf 'y\n' > "$F/records/atlas/atl-43-r1/plan.md"
snap; out="$(echo body | add "fault b2" 2>&1)"; rc=$?
refused "b untracked" "records/atlas/atl-43-r1: committed record changed since, 1 file not committed (0 modified or staged, 1 untracked)" "$rc"
git -C "$F" add records/atlas/atl-43-r1; git -C "$F" commit -q -m "atl-43 plan"
snap; out="$(echo body | add "fixed b" 2>&1)"; written "fixed b"

# c: profiles/ untracked, then modified
printf 'new\n' > "$F/profiles/nova.md"
snap; out="$(echo body | add "fault c" 2>&1)"; rc=$?
refused "c untracked" "profiles/: 1 file not committed (0 modified or staged, 1 untracked)" "$rc"
git -C "$F" add profiles; git -C "$F" commit -q -m profiles
printf 'edit\n' >> "$F/profiles/atlas.md"
snap; out="$(echo body | add "fault c2" 2>&1)"; rc=$?
refused "c modified" "profiles/: 1 file not committed (1 modified" "$rc"
git -C "$F" add profiles; git -C "$F" commit -q -m profiles
snap; out="$(echo body | add "fixed c" 2>&1)"; written "fixed c"

# d: a STATE.md that breaks the shape, then one with a <word> md-check flags; a wide line alone passes
S="$F/checks/atlas-ic/STATE.md"; cp "$S" "$T/state.good"
awk '{ print } /^next: none$/ { print "prose that is not a key" }' "$T/state.good" > "$S"
snap; out="$(echo body | add "fault d" 2>&1)"; rc=$?
refused "d shape" "checks/atlas-ic/STATE.md: breaks the state shape: line 15 is not one of the 15 keys" "$rc"
cp "$T/state.good" "$S"; printf -- '- waiting on <reply> from atlas\n' >> "$S"
snap; out="$(echo body | add "fault d2" 2>&1)"; rc=$?
refused "d md-check" "checks/atlas-ic/STATE.md: md-check line [0-9]*: vanishes: <reply>" "$rc"
cp "$T/state.good" "$S"; printf -- '- %0200d\n' 0 >> "$S"
snap; out="$(echo body | add "fixed d" 2>&1)"; written "fixed d"
check "d: a wide line is not a fault" "$(echo "$out" | grep -c '^FAIL')" "0"
cp "$T/state.good" "$S"

# d: the awaiting line in an IC's STATE.md (shape() from the gate, roster from FLEET_ROSTER)
sed 's/^awaiting: none$/awaiting: nothing. idle/' "$T/state.good" > "$S"
snap; out="$(echo body | add "fault d awaiting" 2>&1)"; rc=$?
refused "d awaiting old form" 'checks/atlas-ic/STATE.md: breaks the state shape: line 12 "awaiting" opens "nothing. idle": open it with none' "$rc"
check "d awaiting: the fix names the rule" "$(echo "$out" | grep -c '^     fix: .*awaiting opens with none, owner:, lead-1: or a roster name and a colon, owner: first')" "1"
sed 's/^awaiting: none$/awaiting: nova-ic: not on the roster/' "$T/state.good" > "$S"
snap; out="$(echo body | add "fault d name" 2>&1)"; rc=$?
refused "d awaiting unknown name" 'checks/atlas-ic/STATE.md: breaks the state shape: line 12 "awaiting" opens "nova-ic: not on the roster"' "$rc"
sed 's/^awaiting: none$/awaiting: dbx-ic: the fixture; Robin: merge PR #9/' "$T/state.good" > "$S"
snap; out="$(echo body | add "fault d owner second" 2>&1)"; rc=$?
refused "d awaiting owner by name second" 'checks/atlas-ic/STATE.md: breaks the state shape: line 12 "awaiting" names the owner (Robin:) after dbx-ic:' "$rc"
sed 's/^awaiting: none$/awaiting: owner: merge PR #9; dbx-ic: the fixture/' "$T/state.good" > "$S"
snap; out="$(echo body | add "fixed d awaiting" 2>&1)"; written "fixed d awaiting"
cp "$T/state.good" "$S"

# d: shape() or md-check that cannot run is a fault, not a pass
snap; out="$(echo body | FLEET_STATE_GATE="$T/none.sh" add "fault d3" 2>&1)"; rc=$?
refused "d no shape" "cannot read shape() from $T/none.sh" "$rc"
snap; out="$(echo body | FLEET_MD_CHECK="$T/none.sh" add "fault d4" 2>&1)"; rc=$?
refused "d no md-check" "md-check did not run on the STATE.md files" "$rc"

# e: a live file names the old checks path; the ledger, other worktrees and recorded fixtures do not count
mkdir -p "$T/scan/Leads/lead-1" "$T/scan/.claude/worktrees/w1/shared" "$T/scan/mods/m/test/fixtures/run1" "$T/scan/TechLeads" "$T/scan/x/node_modules"
for f in Leads/lead-1/LEDGER.md .claude/worktrees/w1/shared/roster.md mods/m/test/fixtures/run1/s.json TechLeads/old.md x/node_modules/a.js; do
  old_path > "$T/scan/$f"; done
snap; out="$(echo body | add "skip e" 2>&1)"; written "skip e"
check "e: skipped paths raise nothing" "$(echo "$out" | grep -c '^FAIL')" "0"
old_path >> "$T/scan/shared/roster.md"
snap; out="$(echo body | add "fault e" 2>&1)"; rc=$?
refused "e old path" "shared/roster.md: names ~/.claude/check[s]" "$rc"
printf 'states live in ~/.fleet-agent-mgmt/checks\n' > "$T/scan/shared/roster.md"
snap; out="$(echo body | add "fixed e" 2>&1)"; written "fixed e"

# warn: an untracked folder with no close.md, newest file over 3 days old: printed, still written
mkdir -p "$F/records/atlas/atl-44-r1"; printf 'b\n' > "$F/records/atlas/atl-44-r1/brief.md"
snap; out="$(echo body | add "recent open" 2>&1)"; written "recent open"
check "warn: a recent untracked folder raises nothing" "$(echo "$out" | grep -c '^WARN\|^FAIL')" "0"
age "$F/records/atlas/atl-44-r1/brief.md"
snap; out="$(echo body | add "warn old" 2>&1)"; rc=$?
check "warn: exit 0" "$rc" "0"
check "warn: printed with its fix" "$(echo "$out" | grep -A1 '^WARN records/atlas/atl-44-r1: untracked, no close.md, newest file over 3 days old' | grep -c 'open.txt')" "1"
check "warn: counted" "$(echo "$out" | grep -c '^fleet-check: 0 faults, 1 warnings$')" "1"
written "warn old"
printf 'atlas/atl-44-r1, waits on the atlas owner\n' > "$F/records/open.txt"
snap; out="$(echo body | add "warn listed" 2>&1)"; written "warn listed"
check "warn: open.txt silences it" "$(echo "$out" | grep -c '^WARN')" "0"
printf 'atl-44-r1, bare name\n' > "$F/records/open.txt"
out="$(echo body | add "warn bare" 2>&1)"
check "warn: the bare folder name matches too" "$(echo "$out" | grep -c '^WARN')" "0"
rm -f "$F/records/open.txt"

# --dump with a fault: the check prints, the dump still shows, nothing written
printf 'new\n' > "$F/profiles/dump.md"
snap; out="$(echo body | add --dump "dump fault" 2>&1)"; rc=$?
check "dump with a fault: exit 0, FAIL shown, dump shown" "$rc|$(echo "$out" | grep -c '^FAIL profiles/')|$(echo "$out" | grep -c '(dump: nothing written)')" "0|1|1"
check "dump with a fault: ledger untouched, no commit" "$(cmp -s "$L" "$T/snap" && echo same)|$(git log --oneline | wc -l | tr -d ' ')" "same|$n"

# standalone: prints the faults, exit 1, writes nothing anywhere
st0="$(git -C "$F" status --porcelain -uall)"
out="$("$HERE/fleet/fleet-check.sh" 2>&1)"; rc=$?
check "standalone: exit 1 and the fault" "$rc|$(echo "$out" | grep -c '^FAIL profiles/')" "1|1"
check "standalone: fleet home and ledger unchanged" "$(git -C "$F" status --porcelain -uall)|$(cmp -s "$L" "$T/snap" && echo same)|$(fleet_n)" "$st0|same|$fn"
rm "$F/profiles/dump.md"

echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ]
