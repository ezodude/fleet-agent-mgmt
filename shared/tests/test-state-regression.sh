#!/bin/bash
# Regression: the STATE.md shape stays accepted after a change to the state
# gate, state-set.sh or fleet-check.sh. Runs on FIXTURES only: eleven invented
# STATE.md files (invented names, owner Robin) generated into a temp fleet
# home under a temp HOME; no live folder is read, nothing outside the temp
# folders is written. For each file:
#   a  shape(), from this tree's gate, reports no fault (the fixture roster's
#      names and owner)
#   b  with no marker, this tree's gate gives the same exit code and the same
#      stderr as the gate at 282b949, on a sandbox: a temp roster row
#      for the IC pointing at a temp git repo, the copy as its STATE.md, once
#      with the newest commit older than the copy (pass) and once newer
#      (bounce); and the same again with a marker older than the copy. The
#      default base is 282b949, the last commit before the marker and the
#      sub-folder match, so the comparison still means something after the
#      merge (main's gate is then this gate).
#      The intended changes, on the same copies: a sub-folder of the repo gets
#      the row's verdict; a marker newer than the copy bounces once with the
#      marker instruction, stop_hook_active lets it end, and a touch of the
#      copy clears it.
#   c  state-set.sh on a copy, setting every key to its current value: exit 0,
#      the result passes shape(), the copy's bytes are the head of the result
#      (one "- superseded" line per key after them), mtime kept; and setting
#      next: to a new value changes that line only
# Then, once:
#   d  fleet-check.sh with this tree's gate reports 0 faults on the fixture
#      fleet home (a git repo holding the states and one closed, committed
#      record folder), and 0 faults, 0 warnings on a temp fleet home holding
#      only the copies
#   shared/tests/test-state-regression.sh        prints one line per case, then "N pass, M fail"; exit 1 on any fail
# The old gate (commit 282b949) is vendored as fixtures/state-gate.282b949.sh,
# its home paths rewritten to /fixture/; history is never read.
# This tree's scripts are always the ones tested.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
GATE="$HERE/hooks/state-gate.sh"; SET="$HERE/ledger/state-set.sh"; FCHECK="$HERE/fleet/fleet-check.sh"
BASE=282b949; OLD_FIXTURE="$HERE/tests/fixtures/state-gate.$BASE.sh"
unset STATE_CHECKS FLEET_ROSTER FLEET_STATE_GATE FLEET_HOME FLEET_MD_CHECK
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
sha() { shasum -a 256 < "$1" 2>/dev/null || sha256sum < "$1"; }
g() { git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
FIX_HOME="$T/fixhome"; FIX_ROSTER="$FIX_HOME/roster.md"
# eleven invented ICs; the fixture states are generated, never copied from a real fleet
names="atlas-ic-1 atlas-ic-2 atlas-ic-3 orbit-ic-1 orbit-ic-2 orbit-ic-3 delta-ic-1 delta-ic-2 nova-ic-1 nova-ic-2 pixel-ic-1"
mkdir -p "$FIX_HOME/checks"
{ printf '**owner: Robin** (the person the skills call the owner)\n\n```fleet\nlead-1\t%s/Leads/lead-1\n' "$FIX_HOME"
  for n in $names; do printf '%s\t%s/work/%s\n' "$n" "$FIX_HOME" "$n"; done; printf '```\n'; } > "$FIX_ROSTER"
i=0
for n in $names; do
  i=$((i+1)); mkdir -p "$FIX_HOME/checks/$n"
  if [ $((i % 2)) -eq 0 ]; then aw="owner: merge the PR; lead-1: audit after the push"; else aw="none"; fi
  cat > "$FIX_HOME/checks/$n/STATE.md" <<EOS
\`\`\`state
session: $n
role: ic
rung: ATL-$((40+i)) r1, route the invented sample files to the sample table
handoff: $FIX_HOME/records/atlas/atl-$((40+i))-r1/handoff.md
repo: $FIX_HOME/work/$n
branch: feat/atl-$((40+i))/sample-routing
head: c0ffee$i
pushed: yes 17:11, origin/feat/atl-$((40+i))/sample-routing tracks; PR #$((100+i))
dirty: $((i % 3))
stop: STOP 2 reached 17:05; report SENT to lead-1
awaiting: $aw
notice: none
next: green receipt at HEAD, then push and open the draft PR
updated: 2026-10-23 10:40 BST (09:40Z)
evidence: $FIX_HOME/checks/$n/
\`\`\`

## log

- superseded 2026-10-23: awaiting: none; fixture note for $n
- superseded 2026-10-23: updated: 2026-10-13 17:58 BST (16:58Z)
EOS
  touch -t 202610231040 "$FIX_HOME/checks/$n/STATE.md"
done
# one closed, committed record folder so the fixture fleet home has something to check
mkdir -p "$FIX_HOME/records/atlas/atl-41-r1"
printf '# ATL-41 rung 1 close\n' > "$FIX_HOME/records/atlas/atl-41-r1/close.md"
lives=()
for f in "$FIX_HOME"/checks/*/STATE.md; do [ -f "$f" ] && lives+=("$f"); done
before=""; for f in "${lives[@]}"; do before="$before$(sha "$f")$(mt "$f")"; done

cp "$OLD_FIXTURE" "$T/old-gate.sh" 2>/dev/null && chmod +x "$T/old-gate.sh"
check "old gate read from $BASE" "$([ -s "$T/old-gate.sh" ] && echo read)" "read"
eval "$(sed -n '/^shape() {$/,/^}$/p' "$GATE")"
check "shape() read from this tree's gate" "$(declare -F shape >/dev/null && echo read)" "read"
owner="$(grep -m1 '^\*\*owner: ' "$FIX_ROSTER")"
rows="$(sed -n '/^```fleet$/,/^```$/p' "$FIX_ROSTER" | sed '1d;$d' | cut -f1)"
check "fixture roster read ($FIX_ROSTER)" "$([ -n "$owner" ] && [ -n "$rows" ] && echo read)" "read"
echo "      ${#lives[@]} fixture STATE.md files under $FIX_HOME/checks"

# run a gate on the sandbox: "<exit>|<stderr>"; $2 the cwd (default the row), $3 extra JSON
# The schema path in a bounce is the gate's own tree (old gate: its own tree, this gate: this clone), so both read <schema>.
run_gate() { local e rc; e="$(printf '{"cwd":"%s"%s}' "${2:-$R/repo}" "${3:-}" | FLEET_ROSTER="$R/roster.md" STATE_CHECKS="$R/checks" "$1" 2>&1 >/dev/null)"; rc=$?
  echo "$rc|$(printf '%s' "$e" | sed -e "s|$HERE/hooks/STATE-schema.md|<schema>|g" -e 's|[^ ]*/shared/hooks/STATE-schema.md|<schema>|g')"; }

for f in "${lives[@]}"; do
  name="$(basename "$(dirname "$f")")"
  R="$T/sb/$name"; mkdir -p "$R/checks/$name" "$R/repo" "$R/set/$name" "$R/next/$name"
  C="$R/copy.md"; cp -p "$f" "$C"

  # a
  check "$name a: shape() no fault" "$(FLEET_ROSTER="$FIX_ROSTER" shape "$C" ic)" ""

  # b: a temp roster with every fixture name (so shape() reads the same names), this IC's row at the temp repo
  { printf '%s\n\n```fleet\n' "$owner"
    printf '%s\n' "$rows" | grep -vxF "$name" | while IFS= read -r n; do printf '%s\t%s\n' "$n" "$R/none/$n"; done
    printf '%s\t%s\n```\n' "$name" "$R/repo"; } > "$R/roster.md"
  S="$R/checks/$name/STATE.md"; cp -p "$C" "$S"
  g "$R/repo" init -q; echo a > "$R/repo/a"; mkdir -p "$R/repo/sub"; echo s > "$R/repo/sub/s"; g "$R/repo" add a sub
  GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" g "$R/repo" commit -q -m "older than the copy"
  o="$(run_gate "$T/old-gate.sh")"; n="$(run_gate "$GATE")"
  check "$name b: commit older, new gate = old gate" "$n" "$o"
  check "$name b: commit older passes" "${n%%|*}" "0"
  rm -f "$R/checks/$name/state-gate.log"; run_gate "$GATE" >/dev/null
  check "$name b: pass_logged, one line <utc> pass <name> in its checks folder" "$(grep -cE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z pass $name\$" "$R/checks/$name/state-gate.log" 2>/dev/null)" "1"
  touch -t 202001010000 "$R/checks/$name/.last-prompt"
  check "$name b: commit older, marker older than the copy, new gate = old gate" "$(run_gate "$GATE")" "$o"
  check "$name b: commit older, a sub-folder gets the row's verdict" "$(run_gate "$GATE" "$R/repo/sub")" "$n"
  touch "$R/checks/$name/.last-prompt"
  m="$(run_gate "$GATE")"
  check "$name b: marker newer than the copy bounces with the marker instruction" \
    "${m%%|*}|$(printf '%s' "$m" | grep -c 'wrote in this pane since .* was last written')" "2|1"
  check "$name b: marker newer, from a sub-folder, the same bounce" "$(run_gate "$GATE" "$R/repo/sub")" "$m"
  check "$name b: marker newer, stop_hook_active lets the turn end" "$(run_gate "$GATE" "$R/repo" ',"stop_hook_active":true')" "0|"
  cp -p "$S" "$R/kept"; touch "$S"
  check "$name b: marker newer, a touch of the copy clears it" "$(run_gate "$GATE")" "0|"
  touch -r "$R/kept" "$S"
  check "$name b: the touch changed the mtime only" "$(cmp -s "$S" "$C" && echo same)" "same"
  rm -f "$R/checks/$name/.last-prompt"
  touch -t 202001010000 "$S"; echo b > "$R/repo/a"; g "$R/repo" commit -q -am "newer than the copy"
  o="$(run_gate "$T/old-gate.sh")"; n="$(run_gate "$GATE")"
  check "$name b: commit newer, new gate = old gate" "$n" "$o"
  check "$name b: commit newer bounces" "${n%%|*}" "2"
  check "$name b: commit newer, a sub-folder gets the row's verdict" "$(run_gate "$GATE" "$R/repo/sub")" "$n"
  touch -t 201901010000 "$R/checks/$name/.last-prompt"
  check "$name b: commit newer, marker older than the copy, new gate = old gate" "$(run_gate "$GATE")" "$o"

  # c: every key set to its current value
  W="$R/set/$name/STATE.md"; cp -p "$C" "$W"
  keys=0; rcs=""; skipped=""
  while IFS= read -r line; do
    k="${line%%:*}"
    case "$line" in "$k: "*) ;; *) skipped="$skipped $k"; continue;; esac
    STATE_CHECKS="$R/set" FLEET_ROSTER="$FIX_ROSTER" "$SET" "$name" "$k=${line#"$k: "}" >/dev/null 2>&1; rcs="$rcs$?"; keys=$((keys+1))
  done < <(sed '/^## log/,$d' "$C" | grep -vE '^```|^[[:space:]]*$|^#')
  [ -n "$skipped" ] && echo "      $name c: not \"key: value\", so not set:$skipped"
  check "$name c: state-set exit 0 on each of $keys keys" "$(printf '%s' "$rcs" | tr -d 0)" ""
  check "$name c: the result passes shape()" "$(FLEET_ROSTER="$FIX_ROSTER" shape "$W" ic)" ""
  check "$name c: the copy's bytes are the head of the result" "$(head -c "$(wc -c < "$C" | tr -d ' ')" "$W" | cmp -s - "$C" && echo same)" "same"
  if grep -q '^## log' "$C"; then
    check "$name c: every line above ## log byte-identical" "$(cmp -s <(sed '/^## log/,$d' "$C") <(sed '/^## log/,$d' "$W") && echo same)" "same"
  fi
  check "$name c: one superseded line per key, at the end" "$(tail -n "$keys" "$W" | grep -c '^- superseded [0-9-]*: ')" "$keys"
  check "$name c: mtime kept" "$(mt "$W")" "$(mt "$C")"
  # c: next: to a new value changes that line only
  if grep -q '^next: ' "$C"; then
    X="$R/next/$name/STATE.md"; cp -p "$C" "$X"
    STATE_CHECKS="$R/next" FLEET_ROSTER="$FIX_ROSTER" "$SET" "$name" next="regression probe" >/dev/null 2>&1
    check "$name c: next= exit 0, shape() no fault" "$?|$(FLEET_ROSTER="$FIX_ROSTER" shape "$X" ic)" "0|"
    check "$name c: next= changes that line only above ## log" \
      "$(diff <(sed '/^## log/,$d' "$C" | sed 's/^next: .*/NEXT/') <(sed '/^## log/,$d' "$X" | sed 's/^next: .*/NEXT/') >/dev/null && grep -c '^next: regression probe$' "$X")" "1"
  fi
  mkdir -p "$T/fh/checks/$name"; cp -p "$C" "$T/fh/checks/$name/STATE.md"
done

# d: fleet-check with this tree's gate, on the fixture fleet home and on the copies alone
g "$FIX_HOME" init -q; g "$FIX_HOME" add -A; g "$FIX_HOME" commit -q -m fixture
out="$(FLEET_HOME="$FIX_HOME" FLEET_STATE_GATE="$GATE" FLEET_ROSTER="$FIX_ROSTER" "$FCHECK" 2>&1)"; rc=$?
last="$(printf '%s\n' "$out" | tail -1)"
printf '%s\n' "$out" | grep '^WARN ' | sed 's/^/      fixture /'
check "d: fleet-check, fixture fleet home, this gate: 0 faults" "$rc|$(printf '%s' "$last" | grep -c '^fleet-check: 0 faults, ')" "0|1"
printf '%s\n' "$out" | grep -A1 '^FAIL ' | sed 's/^/      /'
g "$T/fh" init -q; mkdir -p "$T/scan"
out="$(FLEET_HOME="$T/fh" FLEET_CHECK_SCAN="$T/scan" FLEET_STATE_GATE="$GATE" FLEET_ROSTER="$FIX_ROSTER" "$FCHECK" 2>&1)"; rc=$?
check "d: fleet-check, the copies alone: 0 faults, 0 warnings" "$rc|$(printf '%s\n' "$out" | tail -1)" "0|fleet-check: 0 faults, 0 warnings"

after=""; for f in "${lives[@]}"; do after="$after$(sha "$f")$(mt "$f")"; done
check "fixture STATE.md files unchanged (sha256 and mtime)" "$after" "$before"

echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ]
