#!/bin/bash
# Tests for shared/ledger/card-add.sh, against a cards folder in a temp FLEET_HOME.
# Never touches ~/.fleet-agent-mgmt.
#   shared/tests/test-card-add.sh            prints one line per case, then "N pass, M fail"; exit 1 on any fail
set -u
TD="$(cd "$(dirname "$0")" && pwd -P)"; HERE="$(cd "$TD/.." && pwd -P)"
ADD="$HERE/ledger/card-add.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }
export FLEET_HOME="$T/home" FLEET_ROSTER="$T/roster.md" CARD_NOW="2026-01-02 15:40 GMT"
printf '**owner: Robin** (x)\n\n```fleet\nlead-1\t/x\natlas-ic\t/y\norbit-ic\t/z\n```\n\nnot-in-block\t/w\n' > "$T/roster.md"
C="$T/home/checks/lead-1/cards"
BODY="$T/body.md"
# The body quotes a card file's own lines (a "---", a lowercase "status: open" and "answer: -"): answer must
# change the header's lines only, never these. Every line is inside the width cap (card-width.txt).
printf '%s\n' \
  'atlas · ATL-42 D6, retry limit or wait · lead-1' \
  '' \
  'The problem: the vendor has not said its rate limit.' \
  '' \
  'Status: STOP 2 is ready; the draft card began:' \
  '```' \
  'status: open' \
  'answer: -' \
  '---' \
  '```' \
  '' \
  'a) ship with a limit of three tries' \
  '   the import may still be blocked on a bad night' \
  'b) hold the push until the vendor answers' \
  '' \
  'Reply ATL-42 D6 a, or ATL-42 D6 back: <line>.' > "$BODY"
run() { out="$("$ADD" "$@" 2>&1)"; rc=$?; }
runin() { local in="$1"; shift; out="$("$ADD" "$@" < "$in" 2>&1)"; rc=$?; }
listing() { ls -A "$C" 2>/dev/null | tr '\n' ' '; }

# 1 new: the file, its header, the body byte for byte, the pointer line
runin "$BODY" new "ATL-42 D6" row=atlas-ic where=atlas-ic reply="ATL-42 D6 a | ATL-42 D6 back: <line>"
F="$C/ATL-42-D6.md"
check "new: exit 0" "$rc" "0"
check "new: prints the pointer line" "$out" "ATL-42 D6 · card in fleet pane, row atlas-ic · reply ATL-42 D6 a | ATL-42 D6 back: <line>"
check "new: the slug is the id with spaces as -" "$(listing)" "ATL-42-D6.md "
check "new: the header" "$(sed -n '1,8p' "$F" | tr '\n' '|')" "id: ATL-42 D6|row: atlas-ic|status: open|since: 2026-01-02 15:40 GMT|where: atlas-ic|reply: ATL-42 D6 a | ATL-42 D6 back: <line>|answer: -|---|"
check "new: the body after the first ---, byte for byte" "$(tail -n +9 "$F" | cmp -s - "$BODY" && echo same)" "same"

# 2 answer: status and answer change; every other line, the body included, byte for byte
cp "$F" "$T/before"
run answer "ATL-42 D6" 'a, go ahead \n not an escape'
check "answer: exit 0" "$rc" "0"
check "answer: prints what it did" "$out" 'ATL-42 D6 · answered · a, go ahead \n not an escape · 15:40'
check "answer: status answered" "$(sed -n 3p "$F")" "status: answered"
check "answer: the words verbatim and the time" "$(sed -n 7p "$F")" 'answer: a, go ahead \n not an escape · 15:40'
check "answer: only lines 3 and 7 changed" "$(diff <(sed '3d;7d' "$T/before") <(sed '3d;7d' "$F") >/dev/null && echo same)" "same"
check "answer: a line --- in the body is body, untouched" "$(grep -c '^---$' "$F")" "2"
check "answer: the body's own status: and answer: lines are body, untouched" "$(grep -c '^status: answered$' "$F")|$(grep -c '^status: open$' "$F")|$(grep -c '^answer: -$' "$F")" "1|1|1"
check "answer: the body after the header, byte for byte" "$(tail -n +9 "$F" | cmp -s - "$BODY" && echo same)" "same"

# 3 answer again: refused, untouched
cp "$F" "$T/before"
run answer "ATL-42 D6" "b"
check "answered twice: exit 1, says so" "$rc|$(echo "$out" | grep -c 'is already answered: a, go ahead')" "1|1"
check "answered twice: untouched" "$(cmp -s "$F" "$T/before" && echo same)" "same"

# 4 new on an answered id: replaced, open again
CARD_NOW="2026-01-03 09:05 GMT" runin "$BODY" new "ATL-42 D6" row=atlas-ic where=atlas-ic reply="ATL-42 D6 ok"
check "new over answered: exit 0, open, new since" "$rc|$(sed -n 3p "$F")|$(sed -n 4p "$F")|$(sed -n 7p "$F")" "0|status: open|since: 2026-01-03 09:05 GMT|answer: -"

# 5 refusals: exit 1, says why, the folder and the open card untouched
cp "$F" "$T/before"; was="$(listing)"
refused() {  # $1 name, $2 the text the message must hold, $3 the stdin file, then the args
  local name="$1" want="$2" in="$3"; shift 3
  runin "$in" "$@"
  check "$name: exit 1" "$rc" "1"
  check "$name: says why" "$(echo "$out" | grep -cF -- "$want")" "1"
  check "$name: nothing written" "$(listing)|$(cmp -s "$F" "$T/before" && echo same)" "$was|same"
}
: > "$T/empty"; printf ' \n\t\n\n' > "$T/blank"
refused "open id" 'card "ATL-42 D6" is open' "$BODY" new "ATL-42 D6" row=atlas-ic where=atlas-ic reply="x"
refused "row not in the roster" 'row "nobody-ic" is not lead-1' "$BODY" new "ATL-9 D1" row=nobody-ic where=atlas-ic reply="x"
refused "row outside the fleet block" 'row "not-in-block"' "$BODY" new "ATL-9 D1" row=not-in-block where=atlas-ic reply="x"
refused "where not in the roster" 'where "nobody-ic"' "$BODY" new "ATL-9 D1" row=atlas-ic where=nobody-ic reply="x"
refused "empty body" 'the body is empty' "$T/empty" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply="x"
refused "blank body" 'the body is empty' "$T/blank" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply="x"
refused "no reply" 'no reply=' "$BODY" new "ATL-9 D1" row=atlas-ic where=atlas-ic
refused "empty reply" 'no reply=' "$BODY" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply="  "
refused "no row" 'no row=' "$BODY" new "ATL-9 D1" where=atlas-ic reply="x"
refused "no where" 'no where=' "$BODY" new "ATL-9 D1" row=atlas-ic reply="x"
refused "unknown key" '"answer" is not one of row, where, reply' "$BODY" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply="x" answer=y
refused "key twice" '"row" is given twice' "$BODY" new "ATL-9 D1" row=atlas-ic row=orbit-ic where=atlas-ic reply="x"
refused "reply with a line break" 'the reply has a line break' "$BODY" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply=$'a\nb'
refused "id with a slash" 'is not a card id' "$BODY" new "ATL/9 D1" row=atlas-ic where=atlas-ic reply="x"
refused "id with .." 'is not a card id' "$BODY" new "../x" row=atlas-ic where=atlas-ic reply="x"
refused "id starting with ." 'is not a card id' "$BODY" new ".hidden" row=atlas-ic where=atlas-ic reply="x"
refused "id starting with -" 'is not a card id' "$BODY" new "-x" row=atlas-ic where=atlas-ic reply="x"
refused "id with a leading space" 'is not a card id' "$BODY" new " ATL-9 D1" row=atlas-ic where=atlas-ic reply="x"
refused "id with a trailing space" 'is not a card id' "$BODY" new "ATL-9 D1 " row=atlas-ic where=atlas-ic reply="x"
refused "id with a double space" 'is not a card id' "$BODY" new "ATL-9  D1" row=atlas-ic where=atlas-ic reply="x"
refused "id of spaces only" 'is not a card id' "$BODY" new "   " row=atlas-ic where=atlas-ic reply="x"
refused "empty id" 'is not a card id' "$BODY" new "" row=atlas-ic where=atlas-ic reply="x"
refused "id with a tab" 'is not a card id' "$BODY" new $'ATL-9\tD1' row=atlas-ic where=atlas-ic reply="x"
refused "id with an accented letter" 'is not a card id' "$BODY" new "ATL-9 Dé" row=atlas-ic where=atlas-ic reply="x"
LC_ALL=en_US.UTF-8 refused "id with an accented letter, UTF-8 locale" 'is not a card id' "$BODY" new "café D1" row=atlas-ic where=atlas-ic reply="x"
refused "answer a missing card" 'no card "ATL-9 D1"' "$BODY" answer "ATL-9 D1" "a"
refused "answer with empty words" "the owner's words are empty" "$BODY" answer "ATL-42 D6" " "
# a file at the slug that is another id's card ("a b" and "a-b" share a slug)
cp "$F" "$C/x-y.md"; cp "$F" "$T/xy"; was="$(listing)"
runin "$BODY" new "x y" row=atlas-ic where=atlas-ic reply="x"
check "slug taken by another id: exit 1, says so, untouched" "$rc|$(echo "$out" | grep -c 'is not card "x y"')|$(cmp -s "$C/x-y.md" "$T/xy" && echo same)" "1|1|same"
rm -f "$C/x-y.md"; was="$(listing)"

# 6 lead-1 is a row without a fleet-block line of its own; a body read from a pipe
out="$(printf 'fleet · fleet G2 · lead-1\n\nThe problem: two rungs want one IC.\n' | "$ADD" new "fleet G2" row=lead-1 where=lead-1 reply="fleet G2 a | fleet G2 b" 2>&1)"; rc=$?
check "lead-1 row: exit 0, pointer" "$rc|$out" "0|fleet G2 · card in fleet pane, row lead-1 · reply fleet G2 a | fleet G2 b"
check "lead-1 row: a body with no last newline gets one" "$(tail -c 1 "$C/fleet-G2.md" | od -An -c | tr -d ' ')" '\n'

# 7 no temp file is left behind, and nothing is written outside the cards folder
check "clean: only card files in the folder" "$(listing)" "ATL-42-D6.md fleet-G2.md "
check "clean: nothing else under FLEET_HOME" "$(cd "$T/home" && find . -type f | sort | tr '\n' ' ')" "./checks/lead-1/cards/ATL-42-D6.md ./checks/lead-1/cards/fleet-G2.md "

# 8 what the mod reads: card-add.sh writes the fleet-console mod's card fixture byte for byte.
# The fixture predates the width cap (its lines run to 73 columns), so this case runs under a cap of 100:
# it checks the file format, not the width.
FIX="$HERE/../mods/fleet-console/test/fixtures/invented/cards/fleet-G2.md"
if [ -f "$FIX" ]; then
  export FLEET_HOME="$T/home2"
  sed '1,/^---$/d' "$FIX" > "$T/g2-body"
  printf '100\n' > "$T/width-100"
  CARD_WIDTH_FILE="$T/width-100" CARD_NOW="2026-10-21 16:50 BST" runin "$T/g2-body" new "fleet G2" row=lead-1 where=lead-1 reply="fleet G2 a | fleet G2 b"
  check "mod fixture: written byte for byte as the mod's test reads it" "$rc|$(cmp -s "$T/home2/checks/lead-1/cards/fleet-G2.md" "$FIX" && echo same)" "0|same"
else
  echo "skip  mod fixture: $FIX is not there"
fi

# 9 the width cap: a body line wider than card-width.txt is refused, counted in display columns
TW="$HERE/launch/term-width.sh"
CAP="$(tr -d ' \t\r\n' < "$HERE/launch/card-width.txt")"
check "cap: card-width.txt is the card line room at a 160-column terminal" "$CAP" "$(bash "$TW" --card --at 160)"
check "cap: term-width.sh --card at 160, 180, 186 and 200 columns" \
  "$(bash "$TW" --card --at 160) $(bash "$TW" --card --at 180) $(bash "$TW" --card --at 186) $(bash "$TW" --card --at 200)" "54 63 65 72"
check "cap: term-width.sh --at gives the width back" "$(bash "$TW" --at 186)" "186"
out="$(env -i PATH=/usr/bin:/bin bash "$TW" no-such-session-x < /dev/null 2>&1)"; rc=$?
check "cap: term-width.sh with no width to read: exit 1, says so" "$rc|$(echo "$out" | grep -c 'no width for "no-such-session-x"')" "1|1"
export FLEET_HOME="$T/home3"
C3="$T/home3/checks/lead-1/cards"
rep() { local i; for ((i = 0; i < $2; i++)); do printf '%s' "$1"; done; }  # $1 repeated $2 times
wbody() { printf 'atlas · ATL-50 W1 · lead-1\n\n'; printf '%s\n' "$@"; }    # a body with these lines from line 3
widthok() {  # $1 name, then the body lines: written, exit 0
  local name="$1"; shift
  wbody "$@" > "$T/wbody"; rm -rf "$C3"
  runin "$T/wbody" new "ATL-50 W1" row=atlas-ic where=atlas-ic reply="ATL-50 W1 ok"
  check "$name: exit 0, written" "$rc|$(ls "$C3" 2>/dev/null)" "0|ATL-50-W1.md"
}
widthno() {  # $1 name, $2 the text the message must hold, then the body lines: exit 1, nothing written
  local name="$1" want="$2"; shift 2
  wbody "$@" > "$T/wbody"; rm -rf "$C3"
  runin "$T/wbody" new "ATL-50 W1" row=atlas-ic where=atlas-ic reply="ATL-50 W1 ok"
  check "$name: exit 1" "$rc" "1"
  check "$name: names the line, its width and the cap" "$(echo "$out" | grep -cF -- "$want; the cap is $CAP columns")" "1"
  check "$name: nothing written" "$(ls -A "$C3" 2>/dev/null)" ""
}
widthok "a line at the cap" "$(rep x "$CAP")"
widthno "a line one over the cap" "body line 3 is $((CAP + 1)) columns" "$(rep x $((CAP + 1)))"
widthno "a fenced diagram line over the cap" "body line 5 is $((CAP + 1)) columns" \
  '```' "┌$(rep ─ $((CAP - 2)))┐" "│ import ▶ queue$(rep ' ' $((CAP - 16)))│" '```'
widthok "box lines and arrows count 1 each" \
  '```' "┌$(rep ─ $((CAP - 2)))┐" "│ import ─▶ queue ─▶ vendor$(rep ' ' $((CAP - 28)))│" "└$(rep ─ $((CAP - 2)))┘" '```'
widthok "** marks are not drawn, so not counted" "**problem**$(rep ' ' 5)$(rep x $((CAP - 12)))"
widthno "a wide East Asian character counts 2" "body line 3 is $((CAP + 1)) columns" "$(rep 表 $(((CAP + 1) / 2)))$(rep x $(((CAP + 1) % 2)))"
widthno "every line over the cap is named" "body line 3 is $((CAP + 2)) columns, body line 4 is $((CAP + 3)) columns" \
  "$(rep x $((CAP + 2)))" "$(rep x $((CAP + 3)))"
SIGN=$'\xe2\x9a\xa0' VS16=$'\xef\xb8\x8f'  # U+26A0, a sign one column wide as text, and U+FE0F, which draws it as a 2-wide emoji
widthno "an emoji with the selector U+FE0F counts 2" "body line 3 is $((CAP + 1)) columns" "$(rep x $((CAP - 1)))$SIGN$VS16"
widthok "the same sign with no selector counts 1" "$(rep x $((CAP - 1)))$SIGN"
labelno() {  # $1 name, $2 the text the message must hold, then the body lines: exit 1, nothing written
  local name="$1" want="$2"; shift 2
  wbody "$@" > "$T/wbody"; rm -rf "$C3"
  runin "$T/wbody" new "ATL-50 W1" row=atlas-ic where=atlas-ic reply="ATL-50 W1 ok"
  check "$name: exit 1, names the line and the label" "$rc|$(echo "$out" | grep -cF -- "$want; a label is at most 10 characters")" "1|1"
  check "$name: nothing written" "$(ls -A "$C3" 2>/dev/null)" ""
}
labelno "a label of 11 opening a paragraph (the grilling format's own)" 'body line 3 opens the label "recommended", 11 characters' \
  'Recommended: b, an amendment path. One reason: ...'
labelno "a bold label of 11 inside a paragraph" 'body line 4 opens the label "consequence", 11 characters' \
  '**problem**     the retry shares one queue' '**consequence** jobs wait'
widthok "labels of 10 and less: unverified, and the ones the pane shortens" \
  '**unverified**  the limit is from a page' '' 'The problem: one queue' '' 'Recommendation: b' '' 'Status: ready'
widthok "Word: inside a paragraph, a fence or a reply is no label" \
  'a) keep it' 'Consequences follow: none' '' '```' 'Recommended: b' '```' '' 'Reply with an amendment: ROW-12 Q4 b'
printf 'none\n' > "$T/width-bad"; rm -rf "$C3"
CARD_WIDTH_FILE="$T/width-bad" runin "$BODY" new "ATL-9 D1" row=atlas-ic where=atlas-ic reply="x"
check "an unreadable cap: exit 1, says so, nothing written" "$rc|$(echo "$out" | grep -c 'cannot read the width cap')|$(ls -A "$C3" 2>/dev/null)" "1|1|"

# usage
out="$("$ADD" new 2>&1)"; rc=$?
check "usage: exit 2 with no id" "$rc|$(echo "$out" | grep -c '^usage: ')" "2|1"
out="$("$ADD" remove "ATL-42 D6" 2>&1)"; rc=$?
check "usage: exit 2 on an unknown command" "$rc|$(echo "$out" | grep -c '^usage: ')" "2|1"

echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ]
