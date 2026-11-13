#!/bin/bash
# The owner's terminal width for a fleet session, and the room a card body
# line has in the fleet pane at that width.
#   shared/launch/term-width.sh [session]             the terminal width (default lead-1)
#   shared/launch/term-width.sh --card [session]      the card line room at that width
#   shared/launch/term-width.sh --card --at <width>   the card line room at <width>, nothing read
# The width comes from the tmux client of the session
# (tmux display -p -t <session> "#{client_width}"), else $COLUMNS, else
# tput cols when a terminal is attached. No width: exit 1, says so.
#
# The card line room mirrors the fleet-console mod (mods/fleet-console):
#   dock    = max(1, min(floor(width * 0.45), width - 60))
#             hooks/parse.ts dockColumns, the widest dock the engine gives;
#             /fleet asks for it (hooks/register.tsx, command.run hook)
#   body    = dock - GRIP
#             the engine adds its dock grip to the width /fleet asks for, clamps the
#             whole dock at the widest above, and gives the pane the dock less the grip
#   room    = body - CARD_FRAME - (LABEL + LABEL_GAP)
#             hooks/register.tsx decisionCard: textWidth = columns - CARD_FRAME - labelColumn,
#             labelColumn = the longest label on the row + LABEL_GAP
#   GRIP       = 1  (the engine's DOCK_GRIP_COLUMNS)
#   CARD_FRAME = 4  (register.tsx: the card's border and paddingX)
#   LABEL_GAP  = 3  (register.tsx: the gap after the label column)
#   LABEL      = 10 ("unverified", the longest label the decision-card skill uses;
#                    shared/ledger/card-add.sh refuses a longer one)
# A body line, fenced or not, sits beside the label column, so a line of
# room columns or fewer is drawn whole; a longer one wraps. This assumes the
# dock is as wide as /fleet asked: a dock dragged narrower has less room.
set -u
die() { printf 'term-width: %s\n' "$1" >&2; exit 1; }
GRIP=1 CARD_FRAME=4 LABEL_GAP=3 LABEL=10
card=0 at="" session=""
while [ $# -gt 0 ]; do
  case "$1" in
    --card) card=1 ;;
    --at) [ $# -ge 2 ] || die "--at needs a width"; at="$2"; shift ;;
    -*) die "unknown option $1 (use --card, --at <width>)" ;;
    *) [ -z "$session" ] || die "one session only"; session="$1" ;;
  esac
  shift
done
session="${session:-lead-1}"
num() { [[ $1 =~ ^[1-9][0-9]*$ ]]; }

if [ -n "$at" ]; then
  num "$at" || die "--at \"$at\" is not a width"
  width="$at"
else
  width=""
  if command -v tmux >/dev/null 2>&1; then
    w="$(tmux display -p -t "$session" '#{client_width}' 2>/dev/null)"
    num "$w" && width="$w"
  fi
  if [ -z "$width" ] && num "${COLUMNS:-}"; then width="$COLUMNS"; fi
  if [ -z "$width" ] && { [ -t 0 ] || [ -t 1 ] || [ -t 2 ]; }; then
    w="$(tput cols 2>/dev/null)"
    num "$w" && width="$w"
  fi
  [ -n "$width" ] || die "no width for \"$session\": no tmux client, no \$COLUMNS, no terminal for tput"
fi

if [ "$card" -eq 0 ]; then
  echo "$width"
  exit 0
fi
dock=$(( width * 45 / 100 ))
[ "$dock" -le $(( width - 60 )) ] || dock=$(( width - 60 ))
[ "$dock" -ge 1 ] || dock=1
room=$(( dock - GRIP - CARD_FRAME - LABEL - LABEL_GAP ))
[ "$room" -ge 1 ] || die "a $width-column terminal leaves no room for a card line"
echo "$room"
