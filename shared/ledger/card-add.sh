#!/bin/bash
# lead-1's one write path for a decision card file: one file per card it
# sends the owner, read by the fleet-console mod (the card for that row).
#   shared/ledger/card-add.sh new <id> row=<row> where=<session> reply="<a> | <b>" < body
#   shared/ledger/card-add.sh answer <id> "<the owner's words>"
# new writes <cards>/<slug>.md, the slug being the id with each space as "-"
# ("atlas D1" is atlas-D1.md):
#   id: <id>
#   row: <the board row: an IC's name, or lead-1>
#   status: open
#   since: YYYY-MM-DD HH:MM <zone>
#   where: <the session whose pane the owner types the reply in>
#   reply: <the replies, alternatives separated by " | ">
#   answer: -
#   ---
#   <the body from stdin, exactly as sent>
# and prints the one line the main window carries instead of the card:
#   <id> · card in fleet pane, row <row> · reply <reply>
# answer sets status: answered and answer: <words> · <HH:MM>; every other
# line, the body included, stays byte for byte.
# Refused, nothing written (exit 1): an id that is not words of ASCII
# letters, digits, ".", "_" and "-", one space between words, the first
# word starting with a letter or digit (so no leading, trailing or double
# space, no accented letter, no "." or "-" first); an open
# card with the same id; a file at the slug that is not this id's card; a
# row or where that is not lead-1 or a name in the roster's fleet block; a
# missing or empty row, where or reply; a value with a line break; an empty
# body; a body line wider than the cap in card-width.txt (see below); a
# label longer than 10 characters (see below); answer on a card that is
# missing or already answered; empty words.
# The width cap: every body line, fenced or not, is at most the number in
# shared/launch/card-width.txt, counted in display columns as the fleet pane draws
# it ("**" marks are not drawn and not counted; a wide East Asian character
# counts 2, a combining mark 0, a tab 8, a character followed by the emoji
# selector U+FE0F 2, anything else 1, box lines and arrows included). The
# cap is the card line room at a 160-column terminal
# (shared/launch/term-width.sh --card --at 160); a longer line wraps in the pane.
# The label cap: the pane draws a part's label in a column as wide as the
# longest label on the row, so the room above holds only while every label
# is at most 10 characters ("unverified"). A label is read as the mod reads
# it: "**word**" on any line outside a ``` fence, or "<Capitalised words>: "
# opening a paragraph, lower-cased, with "The problem", "Status" and
# "Recommendation" drawn as problem, state and rec; "reply" is not drawn.
# So "Recommended: b" is the label "recommended", 11, and is refused.
# An answered card with the same id is replaced by new. The file is written
# beside the old one and renamed over it, so no reader sees half a file.
# Paths, overridable for tests:
#   FLEET_HOME    ~/.fleet-agent-mgmt (the cards are <home>/checks/lead-1/cards/)
#   FLEET_ROSTER  $FLEET_HOME/roster.md (the names are its ```fleet block's first column)
#   CARD_NOW      "YYYY-MM-DD HH:MM <zone>", the time written (default: now)
#   CARD_WIDTH_FILE  shared/launch/card-width.txt (the cap, one number)
set -u
. "$(cd -P "$(dirname "$0")" && pwd)/../lib/paths.sh"
CARDS="$FLEET_HOME/checks/lead-1/cards"
ROSTER="${FLEET_ROSTER:-$FLEET_HOME/roster.md}"
WIDTH_FILE="${CARD_WIDTH_FILE:-$(dirname "$0")/../launch/card-width.txt}"
# Prints two lines: one clause per body line wider than CARD_CAP ("body line 7 is 58 columns"), then one per
# label longer than CARD_LABEL ("body line 9 opens the label \"recommended\", 11 characters"); a line is empty
# when nothing is over. The label rules mirror cardParts in mods/fleet-console/hooks/parse.ts.
WIDTHS='
import os, re, sys, unicodedata
cap, most = int(os.environ["CARD_CAP"]), int(os.environ["CARD_LABEL"])
def cols(ch):
    if ch == "\t": return 8
    if unicodedata.combining(ch) or unicodedata.category(ch) in ("Mn", "Me", "Cf"): return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
def width(line):
    w, last = 0, 0
    for ch in line:
        if ch == "\ufe0f" and last == 1: w, last = w + 1, 2
        else: last = cols(ch); w += last
    return w
BOLD = re.compile(r"\*\*([A-Za-z][A-Za-z ]{0,19})\*\*\s*(.*)$")
WORD = re.compile(r"([A-Z][A-Za-z ]{0,19}):\s+(.*)$")
FENCE = re.compile(r"\s*```")
LABELS = {"the problem": "problem", "status": "state", "recommendation": "rec"}
text = sys.stdin.buffer.read().decode("utf-8", "replace")
over, long, fenced, start = [], [], False, True
for n, line in enumerate(text.split("\n"), 1):
    line = line.rstrip("\r")
    w = width(line.replace("**", ""))
    if w > cap: over.append(f"body line {n} is {w} columns")
    if fenced:
        fenced = not FENCE.match(line)
        continue
    if line.strip() == "":
        start = True
        continue
    m = BOLD.match(line) or (WORD.match(line) if start else None)
    start = False
    if m:
        label = m.group(1).strip().lower()
        label = LABELS.get(label, label)
        if label != "reply" and len(label) > most:
            long.append(f"body line {n} opens the label \"{label}\", {len(label)} characters")
    elif FENCE.match(line):
        fenced = True
print(", ".join(over))
print(", ".join(long))
'
die() { printf 'card-add: %s\ncard-add: refused, nothing was written.\n' "$1" >&2; exit 1; }
usage() { printf 'usage: shared/ledger/card-add.sh new <id> row=<row> where=<session> reply="<a> | <b>" < body\n       shared/ledger/card-add.sh answer <id> "<words>"\n' >&2; exit 2; }
sha() { shasum -a 256 < "$1" 2>/dev/null || sha256sum < "$1"; }
oneline() { case "$2" in *$'\n'*|*$'\r'*) die "the $1 has a line break: one line only";; esac; }
now() { if [ -n "${CARD_NOW:-}" ]; then printf '%s' "$CARD_NOW"; else date '+%Y-%m-%d %H:%M %Z'; fi; }
# The header value of key $2 in card file $1 (lines above the first "---").
key() { awk -v k="$2" '$0 == "---" { exit } index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$1"; }
named() {  # $1 is lead-1 or a name in the roster's fleet block
  [ "$1" = lead-1 ] && return 0
  [ -f "$ROSTER" ] || die "cannot read the roster $ROSTER"
  sed -n '/^```fleet$/,/^```$/p' "$ROSTER" | sed '1d;$d' | cut -f1 | grep -qxF -- "$1"
}

[ $# -ge 2 ] || usage
cmd="$1"; id="$2"; shift 2
oneline id "$id"
# The id check runs in the C locale, so [A-Za-z] is the 52 ASCII letters and nothing else ("é" is refused).
id_ok() {
  local LC_ALL=C re='^[A-Za-z0-9][A-Za-z0-9._-]*( [A-Za-z0-9._-]+)*$'
  [[ $1 =~ $re ]]
}
id_ok "$id" || die "\"$id\" is not a card id: words of ASCII letters, digits, \".\", \"_\" and \"-\", one space between words, starting with a letter or digit"
slug="${id// /-}"
f="$CARDS/$slug.md"
tmp="$CARDS/.$slug.md.card-add.$$"
trap 'rm -f "$tmp"' EXIT

case "$cmd" in
new)
  row=""; where=""; reply=""; given=" "
  for a in "$@"; do
    case "$a" in *=*) ;; *) die "\"$a\" is not key=value";; esac
    k="${a%%=*}"; v="${a#*=}"
    case "$k" in row|where|reply) ;; *) die "\"$k\" is not one of row, where, reply";; esac
    case "$given" in *" $k "*) die "\"$k\" is given twice";; esac
    oneline "$k" "$v"; given="$given$k "
    printf -v "$k" '%s' "$v"
  done
  [ -n "$row" ] || die "no row= (the board row: an IC's name, or lead-1)"
  [ -n "$where" ] || die "no where= (the session whose pane the owner types the reply in)"
  [ -n "${reply// /}" ] || die "no reply= (what the owner types, alternatives separated by \" | \")"
  named "$row" || die "row \"$row\" is not lead-1 or a name in the roster's fleet block ($ROSTER)"
  named "$where" || die "where \"$where\" is not lead-1 or a name in the roster's fleet block ($ROSTER)"
  [ -t 0 ] && die "the body comes on stdin: the card exactly as sent"
  body="$(cat; printf x)"; body="${body%x}"
  [ -n "$(printf '%s' "$body" | tr -d ' \t\r\n')" ] || die "the body is empty: the card exactly as sent comes on stdin"
  cap="$(tr -d ' \t\r\n' < "$WIDTH_FILE" 2>/dev/null)"
  [[ $cap =~ ^[1-9][0-9]*$ ]] || die "cannot read the width cap from $WIDTH_FILE: one number"
  counted="$(printf '%s' "$body" | CARD_CAP="$cap" CARD_LABEL=10 python3 -I -c "$WIDTHS")" || die "cannot count the body's line widths (python3)"
  { IFS= read -r wide; IFS= read -r long; } <<< "$counted"
  [ -z "$wide" ] || die "$wide; the cap is $cap columns ($WIDTH_FILE): the fleet pane wraps a longer line, so cut it or redraw the diagram"
  [ -z "$long" ] || die "$long; a label is at most 10 characters (\"unverified\"): a longer one narrows every card on the row, so the pane wraps lines at the cap. Use a shorter label (\"Recommendation:\" is drawn as rec)"
  if [ -e "$f" ]; then
    [ "$(key "$f" id)" = "$id" ] || die "$f is there and is not card \"$id\": move it away first"
    [ "$(key "$f" status)" = answered ] || die "card \"$id\" is open ($f): answer it first"
  fi
  since="$(now)"
  mkdir -p "$CARDS" || die "cannot make $CARDS"
  { printf 'id: %s\nrow: %s\nstatus: open\nsince: %s\nwhere: %s\nreply: %s\nanswer: -\n---\n' "$id" "$row" "$since" "$where" "$reply"
    printf '%s' "$body"; case "$body" in *$'\n') ;; *) printf '\n';; esac; } > "$tmp" || die "cannot write $tmp"
  mv -f "$tmp" "$f" || die "cannot write $f"
  printf '%s · card in fleet pane, row %s · reply %s\n' "$id" "$row" "$reply"
  ;;
answer)
  [ $# -eq 1 ] || usage
  words="$1"
  oneline answer "$words"
  [ -n "${words// /}" ] || die "the owner's words are empty"
  [ -f "$f" ] || die "no card \"$id\" ($f is missing)"
  [ "$(key "$f" id)" = "$id" ] || die "$f is not card \"$id\""
  case "$(key "$f" status)" in
    open) ;;
    answered) die "card \"$id\" is already answered: $(key "$f" answer)";;
    *) die "$f has no status open or answered";;
  esac
  at="$(now)"; at="${at#* }"; at="${at%% *}"
  sum="$(sha "$f")"
  # The words through the environment, never awk -v, which would read a backslash in them as an escape.
  CARD_ANSWER="$words · $at" awk '
    !sep && $0 == "---" { sep = 1 }
    !sep && /^status: / { print "status: answered"; next }
    !sep && /^answer: / { print "answer: " ENVIRON["CARD_ANSWER"]; next }
    { print }' "$f" > "$tmp" || die "cannot write $tmp"
  [ "$(sha "$f")" = "$sum" ] || die "$f changed while this ran: re-run"
  mv -f "$tmp" "$f" || die "cannot write $f"
  printf '%s · answered · %s · %s\n' "$id" "$words" "$at"
  ;;
*) usage ;;
esac
