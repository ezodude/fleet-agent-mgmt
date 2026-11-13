#!/bin/bash
# Stop hook. A turn whose last message carries a skill's header may not end
# unless that skill was invoked this session. Bounces at most twice per turn.
#   ic    "· STOP n ·" header          needs reporting-a-rung
#   ic    opens with "close · "        needs closing-a-rung
#   lead  "check ·" header             needs reporting-a-rung and agent-haiku
#   lead  opens with "held n since"    needs holding-rollups
#   lead  over 15 prose lines          needs explaining-in-steps (final text only,
#         non-blank lines outside ``` fences; check and held messages exempt)
#   lead  chat gate: a turn the owner did not start (a peer message, a subagent
#         result, a notice; turn_text.py --start says machine) ends with no chat
#         text, or one line naming no ticket key and no IC; else exit 2. Owner-typed
#         and compaction turns are not checked. Spec: lead-ux/hook-chat-gate.md.
# Solo: exit 0. Reads .last_assistant_message plus the turn's text and
# SendMessage bodies from the transcript (turn_text.py, documented there).
# Bounces at most TWICE per turn, counted in $MARKS/.bounces (reset when a
# turn starts cold, wiped with the markers on compaction). Once was beaten
# on 2026-09-16: lead-1 was bounced, re-read the skill, auto-compacted in the
# same turn (markers wiped), and its redone message passed on the once-guard.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "solo" ] && exit 0
if [ "$(j '.stop_hook_active')" = "true" ]; then
  n="$(cat "$MARKS/.bounces" 2>/dev/null || echo 0)"; [ "$n" -ge 2 ] && exit 0
else
  n=0; rm -f "$MARKS/.bounces" 2>/dev/null
fi
msg="$(j '.last_assistant_message')"
last="$msg"
# The turn's SendMessage bodies count too: a STOP report sent to lead-1 with a
# final text of "sent, holding" is still a STOP report (loophole closed
# 2026-09-15). From the transcript: every assistant record after the last
# human turn, text blocks and SendMessage inputs; falls back to the last text.
t="$(j '.transcript_path')"
if [ -f "$t" ]; then
  turn="$(python3 "$(dirname "$0")/turn_text.py" "$t")"
  msg="${msg}${msg:+
}${turn}"
fi
[ -n "$msg" ] || exit 0
missing=""
if [ "$ROLE" = "ic" ]; then
  if printf '%s' "$msg" | grep -Eq '· STOP [0-9]+ ·'; then
    has reporting-a-rung || missing="reporting-a-rung, $(why reporting-a-rung) (IC side: rows glyph first, options with cost, unverified line)"
  fi
  if printf '%s' "$msg" | grep -Eq '^close · '; then
    has closing-a-rung || missing="${missing:+$missing; }closing-a-rung, $(why closing-a-rung) (verdict with reply strings, SHIPPED gap, PROVED with pass line beside output, tables aligned)"
  fi
else
  if printf '%s' "$msg" | grep -Eq '(^|[[:space:]])check · '; then
    has reporting-a-rung || missing="reporting-a-rung, $(why reporting-a-rung) (Lead side, steps 0-4; the card shape is foundations/decision-card.md, read it)"
    has agent-haiku || missing="${missing:+$missing; }the haiku check (Agent tool, model haiku, templates/check-prompt.md)"
  fi
  if printf '%s' "$msg" | grep -Eq '^held [0-9]+ since'; then
    has holding-rollups || missing="${missing:+$missing; }holding-rollups, $(why holding-rollups)"
  fi
  if ! printf '%s' "$last" | grep -Eq '(^|[[:space:]])check · |^held [0-9]+ since'; then
    p="$(printf '%s\n' "$last" | awk '/^```/{f=!f; next} !f && NF{n++} END{print n+0}')"
    if [ "$p" -gt 15 ]; then
      has explaining-in-steps || missing="${missing:+$missing; }explaining-in-steps, $(why explaining-in-steps) (this message is $p prose lines; a diagram carries the structure, one step per turn, stop at the explanation)"
    fi
  fi
  if [ -f "$t" ] && [ "$(python3 "$(dirname "$0")/turn_text.py" --start "$t")" = "machine" ]; then
    body="$(printf '%s\n' "$last" | awk '/^```/{f=!f; next} !f && NF')"
    nl="$(printf '%s' "$body" | awk 'NF{n++} END{print n+0}')"
    ics="$(sed -n '/^```fleet$/,/^```$/p' "$ROSTER" 2>/dev/null | sed '1d;$d' | cut -f1 | grep -vx 'lead-1' | grep -v '^$' | paste -sd'|' -)"
    # lowercase lane names (one per line in $FLEET_HOME/lane-prefixes.txt) also count as ticket refs: "<lane>-12", "<lane> #12"
    lanes="$(grep -E '^[a-z][a-z0-9]*$' "$FLEET_HOME/lane-prefixes.txt" 2>/dev/null | paste -sd'|' -)"
    lre=""; [ -n "$lanes" ] && lre="|\\b($lanes)-[0-9]+\\b|\\b($lanes) #[0-9]+\\b"
    hit="$(printf '%s' "$body" | grep -oE "\\b[A-Z][A-Z0-9]+-[0-9]+\\b$lre" | head -1)"
    [ -z "$hit" ] && [ -n "$ics" ] && hit="$(printf '%s' "$body" | grep -oE "(^|[^A-Za-z0-9-])($ics)([^A-Za-z0-9-]|\$)" | head -1 | sed -E 's/^[^A-Za-z0-9-]//; s/[^A-Za-z0-9-]$//')"
    if [ "$nl" -gt 1 ] || [ -n "$hit" ]; then
      why_=""; [ -n "$hit" ] && why_="the text names $hit"; [ "$nl" -gt 1 ] && why_="${why_:+$why_; }it is $nl lines"
      mkdir -p "$MARKS" && echo $((n+1)) > "$MARKS/.bounces"
      echo "CHAT GATE: this turn was not the owner's; $why_. Put it on board.md (yours / running / owed / done today) or in a report, end with no chat text." >&2
      exit 2
    fi
  fi
fi
[ -n "$missing" ] || exit 0
mkdir -p "$MARKS" && echo $((n+1)) > "$MARKS/.bounces"
echo "SKILL GATE: this message needs a skill that is not in force: $missing. Invoke it with the Skill tool, redo the message per its template, then end the turn." >&2
exit 2
