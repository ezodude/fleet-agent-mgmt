#!/bin/bash
# Tests for shared/ledger/state-set.sh, against a STATE.md in a temp checks folder.
# Never touches ~/.fleet-agent-mgmt.
#   shared/tests/test-state-set.sh            prints one line per case, then "N pass, M fail"; exit 1 on any fail
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
SET="$HERE/ledger/state-set.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }
export STATE_CHECKS="$T/checks" FLEET_ROSTER="$T/roster.md" FLEET_STATE_GATE="$HERE/hooks/state-gate.sh"
unset FLEET_MD_CHECK
printf '**owner: Robin** (x)\n\n```fleet\nlead-1\t/x\natlas-ic\t/y\n```\n' > "$T/roster.md"
mkdir -p "$T/checks/atlas-ic"
F="$T/checks/atlas-ic/STATE.md"
D="$(date +%Y-%m-%d)"
OLD=202001011200
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
block() {  # the 15 keys; $1 is what follows the fence
  printf '```state\nsession: atlas-ic\nrole: ic\nrung: ATL-42 retry wrapper\nhandoff: /h/handoff.md\nrepo: /r\nbranch: feat/42\nhead: 1a2b3c4\npushed: no (no upstream)\ndirty: 0\nstop: STOP 1 sent 10:05\nawaiting: owner: "ATL-42 spec ok"\nnotice: none\nnext: wait for the spec word\nupdated: 2026-01-01 10:05 GMT (10:05Z)\nevidence: /e/evidence.md\n```\n%s' "$1" > "$F"
  touch -t $OLD "$F"; cp -p "$F" "$T/orig"
}
above() { sed '/^## log/,$d' "$1"; }
run() { out="$("$SET" "$@" 2>&1)"; rc=$?; }
untouched() { [ "$(mt "$F")" = "$(mt "$T/orig")" ] && cmp -s "$F" "$T/orig" && echo same || echo changed; }

# 1 one key: replaced above the log, the old line logged last, the rest identical, mtime kept
block $'\n## log\n- merged: PR #7 as 7c1e2a9\nnext: a raw key line in the log is not read\n'
run atlas-ic next="merge PR #88 on the owner's word"
check "set: exit 0" "$rc" "0"
check "set: prints what it did" "$(echo "$out" | grep -c "^state-set: $F: set next; 1 line(s) under ## log; mtime kept$")" "1"
check "set: the new line, once, above the log" "$(above "$F" | grep -c "^next: merge PR #88 on the owner's word$")" "1"
check "set: the old line is the last line, word for word" "$(tail -1 "$F")" "- superseded $D: next: wait for the spec word"
check "set: the raw key line in the log is untouched" "$(grep -c '^next: a raw key line in the log is not read$' "$F")" "1"
check "set: every other line above the log byte-identical" "$(diff <(above "$T/orig" | grep -v '^next: ') <(above "$F" | grep -v '^next: ') >/dev/null && echo same)" "same"
check "set: the file is the old one plus one line, in place" "$(diff <(sed 's/^next: wait for the spec word$/X/' "$T/orig") <(sed '$d' "$F" | sed "s/^next: merge PR #88 on the owner's word$/X/") >/dev/null && echo same)" "same"
check "set: updated: untouched when not asked" "$(grep -c '^updated: 2026-01-01 10:05 GMT (10:05Z)$' "$F")" "1"
check "set: mtime kept" "$(mt "$F")" "$(mt "$T/orig")"
check "set: the result passes shape()" "$(eval "$(sed -n '/^shape() {$/,/^}$/p' "$FLEET_STATE_GATE")"; declare -F shape >/dev/null && echo read; shape "$F" ic)" "read"

# 2 several keys, in the order given; updated: when asked
block $'\n## log\n'
run atlas-ic stop="STOP 2 reached 15:40" awaiting="lead-1: the S5 ruling" updated="2026-01-02 15:40 GMT (15:40Z)"
check "multi: exit 0" "$rc" "0"
check "multi: three lines replaced" "$(above "$F" | grep -c -e '^stop: STOP 2 reached 15:40$' -e '^awaiting: lead-1: the S5 ruling$' -e '^updated: 2026-01-02 15:40 GMT (15:40Z)$')" "3"
check "multi: logged in the order given" "$(tail -3 "$F" | cut -d: -f2 | tr '\n' ' ')" " stop  awaiting  updated "
check "multi: mtime kept" "$(mt "$F")" "$(mt "$T/orig")"

# 3 no ## log: the heading is added after the closing fence, the block unchanged
block ''
run atlas-ic notice="armed on atlas-ic"
check "no log: exit 0" "$rc" "0"
check "no log: fence, blank, heading, bullet at the end" "$(tail -4 "$F" | tr '\n' '|')" "\`\`\`||## log|- superseded $D: notice: none|"
check "no log: one heading" "$(grep -c '^## log$' "$F")" "1"
check "no log: the old file is the new one's head, but for the line" "$(diff <(sed 's/^notice: none$/X/' "$T/orig") <(head -17 "$F" | sed 's/^notice: armed on atlas-ic$/X/') >/dev/null && echo same)" "same"

# 4 the value is kept literally
block $'\n## log\n'
run atlas-ic next='run `make check` & then $HOME\path "quoted" 100%'
check "literal: the value as given" "$(grep -c '^next: run `make check` & then \$HOME\\path "quoted" 100%$' "$F")" "1"
# a <word> outside backticks in the old line goes in backticks under the log; inside backticks it stays
block $'\n## log\n'
sed -i '' 's/^rung: .*/rung: ATL-42 <record>\/plan.md and `<kept>` as is/' "$F" 2>/dev/null || sed -i 's/^rung: .*/rung: ATL-42 <record>\/plan.md and `<kept>` as is/' "$F"
run atlas-ic rung="ATL-42 retry wrapper, r2"
check "ticks: a bare <word> is put in backticks in the log" "$(tail -1 "$F")" "- superseded $D: rung: ATL-42 \`<record>\`/plan.md and \`<kept>\` as is"
# the other tag-like forms a viewer drops, and backticks this split cannot pair;
# each result must pass md-check (fleet-check's rule d and ledger-add.sh rely on it)
setnext() {  # $1 the old next: value, $2 the log line wanted, $3 the case
  block $'\n## log\n'
  awk -v v="$1" '/^next: /{print "next: " v; next} {print}' "$F" > "$T/x" && cat "$T/x" > "$F"
  run atlas-ic next="done"
  check "ticks: $3: exit 0" "$rc" "0"
  check "ticks: $3: logged" "$(tail -1 "$F")" "- superseded $D: $2"
  check "ticks: $3: md-check ok" "$(bash "$HERE/records/md-check.sh" "$F" | tail -1)" "md-check $F: ok"
}
setnext 'see <!-- note --> here' 'next: see `<!-- note -->` here' "a comment"
setnext '<?php echo ?> legacy' 'next: `<?php echo ?>` legacy' "a processing instruction"
setnext '<!DOCTYPE html> tag' 'next: `<!DOCTYPE html>` tag' "a declaration"
setnext 'x<y and z>w' 'next: x`<y and z>`w' "a tag mid-word"
setnext 'run `foo <bar>' '`` next: run `foo <bar> ``' "an unpaired backtick"
setnext 'run ``a`b`` <c>' '``` next: run ``a`b`` <c> ```' "a double backtick"

# 5 refusals: exit 1, the file byte-identical, mtime kept
refused() {  # name, then the args; $want is a fixed string the message must hold
  block $'\n## log\n- merged: x\n'
  [ -n "${prep:-}" ] && { eval "$prep"; touch -t $OLD "$F"; cp -p "$F" "$T/orig"; }
  run "$@"
  check "$name: exit 1" "$rc" "1"
  check "$name: says why" "$(echo "$out" | grep -cF -- "$want")" "1"
  check "$name: says nothing was written" "$(echo "$out" | grep -c '^state-set: refused, nothing was written.$')" "1"
  check "$name: file and mtime untouched" "$(untouched)" "same"
  prep=""
}
prep=""
name="unknown key"; want='"mood" is not one of the 15 keys'; refused atlas-ic mood="fine"
name="a key twice"; want='"next" is given twice'; refused atlas-ic next="a" next="b"
name="not key=value"; want='"next" is not key="value"'; refused atlas-ic next
name="line break"; want='the value of "next" has a line break'; refused atlas-ic next=$'a\nb'
name="key not in the file"; want='"notice" has 0 lines above ## log, not 1'; prep='sed -i "" "/^notice: /d" "$F" 2>/dev/null || sed -i "/^notice: /d" "$F"'; refused atlas-ic notice="armed"
name="key twice in the file"; want='"next" has 2 lines above ## log, not 1'; prep='printf "next: again\n" > "$T/x"; sed -i "" "/^updated: /r $T/x" "$F" 2>/dev/null || sed -i "/^updated: /r $T/x" "$F"'; refused atlas-ic next="one"
name="shape fault"; want='would break the state shape: line 12 "awaiting" opens "nothing yet"'; refused atlas-ic awaiting="nothing yet"
name="shape fault elsewhere"; want='would break the state shape: line 17 is not one of the 15 keys: mood: fine'; prep='printf "mood: fine\n" > "$T/x"; sed -i "" "/^evidence: /r $T/x" "$F" 2>/dev/null || sed -i "/^evidence: /r $T/x" "$F"'; refused atlas-ic next="x"
name="missing file"; want="$T/checks/nova-ic/STATE.md is missing"; refused nova-ic next="x"
name="not a name"; want='"../atlas-ic" is not a roster name'; refused ../atlas-ic next="x"
# md-check is the backstop for a log line ticks() did not make safe: a stand-in
# md-check faults any file whose next: is "trigger", and "wide" alone never blocks
printf '#!/bin/bash\nif grep -q "^next: trigger" "$1"; then printf "md-check %%s: 1 faults\\n  line 13: vanishes: <fake>\\n" "$1"; exit 1; fi\nif grep -q "^next: long" "$1"; then printf "md-check %%s: 1 faults\\n  line 13: wide: 200 chars\\n" "$1"; exit 1; fi\necho "md-check $1: ok"\n' > "$T/fake-md.sh"
name="md-check fault"; want='would get a fault a viewer shows: vanishes: <fake> (shared/records/md_check.py says what each fault is)'; FLEET_MD_CHECK="$T/fake-md.sh" refused atlas-ic next="trigger"
block $'\n## log\n'
FLEET_MD_CHECK="$T/fake-md.sh" run atlas-ic next="long"
check "md-check wide alone: exit 0, written" "$rc|$(grep -c '^next: long$' "$F")" "0|1"
name="md-check missing"; want="md-check did not run ($T/no-md.sh)"; FLEET_MD_CHECK="$T/no-md.sh" refused atlas-ic next="x"

# a fault the file already had does not block a write elsewhere
block $'\n## log\n- an old <raw> line\n'
run atlas-ic next="x"
check "old fault: exit 0, written" "$rc|$(grep -c '^next: x$' "$F")" "0|1"
check "no temp file left beside STATE.md" "$(ls -A "$T/checks/atlas-ic" | tr '\n' ' ')" "STATE.md "

# the guard: a file changed after the read is never overwritten. A shasum on
# PATH that, on its second call (the check before the write), first appends a
# line to the file, as another writer would.
REAL_SHASUM="$(command -v shasum)"
if [ -z "$REAL_SHASUM" ]; then echo "SKIP  guard: no shasum on PATH"; else
  mkdir -p "$T/bin"
  printf '#!/bin/bash\nn=$(( $(cat "%s" 2>/dev/null || echo 0) + 1 )); echo "$n" > "%s"\n[ "$n" = 2 ] && printf -- "- changed by another writer\\n" >> "%s"\nexec "%s" "$@"\n' \
    "$T/count" "$T/count" "$F" "$REAL_SHASUM" > "$T/bin/shasum"; chmod +x "$T/bin/shasum"
  block $'\n## log\n'; rm -f "$T/count"
  out="$(PATH="$T/bin:$PATH" "$SET" atlas-ic next="x" 2>&1)"; rc=$?
  check "guard: exit 1" "$rc" "1"
  check "guard: says the file changed" "$(echo "$out" | grep -c "$F changed while this ran (sha256 differs from what was read)")" "1"
  check "guard: the other writer's line kept, the value not written" "$(tail -1 "$F")|$(grep -c '^next: x$' "$F")" "- changed by another writer|0"
  check "guard: the rest is the file as read" "$(diff <(sed '$d' "$F") "$T/orig" >/dev/null && echo same)" "same"
  check "guard: no temp file left" "$(ls -A "$T/checks/atlas-ic" | tr '\n' ' ')" "STATE.md "
fi

# usage
out="$("$SET" atlas-ic 2>&1)"; rc=$?
check "usage: exit 2 with no key" "$rc|$(echo "$out" | grep -c '^usage: ')" "2|1"

# shape() unreadable: refused
block $'\n## log\n'
out="$(FLEET_STATE_GATE="$T/no-gate.sh" "$SET" atlas-ic next="x" 2>&1)"; rc=$?
check "no shape(): exit 1, untouched" "$rc|$(untouched)|$(echo "$out" | grep -c "cannot read shape() from $T/no-gate.sh")" "1|same|1"

# 5 state-set and state-gate agree on the folder under a non-default FLEET_HOME (no STATE_CHECKS)
FH="$T/fh"; AR="$T/arepo"; mkdir -p "$FH/checks/atlas-ic" "$AR"
git -C "$AR" init -q; echo a > "$AR/a"; git -C "$AR" add a; git -C "$AR" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m c1
printf '**owner: Robin** (x)\n\n```fleet\nlead-1\t/x\natlas-ic\t%s\n```\n' "$AR" > "$T/roster-fh.md"
cp "$F" "$FH/checks/atlas-ic/STATE.md"; touch -t $OLD "$FH/checks/atlas-ic/STATE.md"
gate_rc() { printf '{"cwd":"%s"}' "$AR" | env -u STATE_CHECKS FLEET_HOME="$FH" FLEET_ROSTER="$T/roster-fh.md" "$HERE/hooks/state-gate.sh" >/dev/null 2>&1; echo $?; }
check "agree: the gate bounces the old STATE.md under FLEET_HOME/checks" "$(gate_rc)" "2"
out="$(env -u STATE_CHECKS FLEET_HOME="$FH" "$SET" atlas-ic next="agree probe" 2>&1)"; rc=$?
check "agree: state-set writes FLEET_HOME/checks/atlas-ic/STATE.md" "$rc|$(echo "$out" | grep -c "state-set: $FH/checks/atlas-ic/STATE.md:")" "0|1"
touch "$FH/checks/atlas-ic/STATE.md"
check "agree: the gate finds that file and passes" "$(gate_rc)" "0"
check "agree: the pass is logged in the same folder" "$(grep -c ' pass atlas-ic$' "$FH/checks/atlas-ic/state-gate.log")" "1"

echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ]
