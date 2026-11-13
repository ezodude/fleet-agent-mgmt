#!/bin/bash
# PreToolUse hook, matcher "SendMessage". IC only. A message carrying a
# "· STOP n ·" header is denied before it sends when (a) reporting-a-rung has
# no marker this session, or (b) the message is over 30 lines: the message is
# the template, the rest lives in the report file whose path the `files` line
# carries, and the haiku check reads that file, lead-1 never does (the
# owner: "messages cost tokens, we should only send what is needed"; one
# morning 11 IC messages averaged 90 lines against a 21-line template). (c) RECEIPT GATE: the message names the
# rung's record folder (~/.fleet-agent-mgmt/records/<project>/<lane>-r<n>/) and
# the newest receipts/*-gate.md there, written by shared/records/gate-run.sh, is at the
# worktree's HEAD; and no ✔ row names a command the receipt marks red. A rung
# with no record folder for this IC (opened before 2026-10-08) skips (c).
# FROZEN, every STOP after STOP 1: rules.md and gate.md match <record>/frozen.sha256,
# the receipt names the frozen gate.md's sha256, and the frozen files lead back to the
# approved STOP 1 commit (shared/frozen.py check --repo); a chore's (no spec, no STOP 1, frozen
# by lead-1 with freeze-rules.sh --chore) lead back to its handoff's `## Checks` instead.
# STOP 1 GATE: a STOP 1 report comes before the freeze, so it has no receipt and
# skips (c). Instead it carries the spec line `spec  <repo path> @ <sha>`, the
# commit the owner reviews, and shared/frozen.py stop1 checks: the spec at <sha>
# freezes as written (freeze-rules.sh --check); no Checks row has a placeholder
# `on main` cell; and <record>/evidence.md has one entry per Checks command run at
# origin/main (`ran` the command exactly, `where` `<cwd> · origin/main · HEAD <sha>`).
# A STOP 1 on a chore's record is denied (shared/frozen.py stop1): a chore has no STOP 1.
# A STOP 1 that passes every gate here and is sent to lead-1 gets a line in <record>/stop1.log (the
# spec path, the full sha, this IC, the session): the freeze takes only the newest sha there as
# --approved, and the owner's "<lane> r<n> spec ok" counts only when typed after that line. Sent to
# lead-1 is a `to` of "lead-1", or of uds:<socket>/<pid>.sock where that process runs in lead-1's
# roster folder. A STOP 1 sent to anyone else is not denied but writes no line, and the hook says so
# to the IC (additionalContext).
# The record folder is picked by shared/frozen.py record: the folders the message names,
# written as $RECORDS, ~/.fleet-agent-mgmt/records or $HOME/...; this IC's open folder wins
# wherever it stands, and a STOP that does not name an open folder of its own is denied.
# A record folder in shared/records/legacy-records.txt skips FROZEN, STOP 1 GATE and DRIFT.
# (d) JEV RECEIPT GATE, "ready for push" only: every jev line in the record's
# decision-record.md has a receipt with the same entry and verdict. "Ready for
# push" is a report sent before the push, not a hold: the IC pushes without
# waiting, and push-gate.sh repeats (c) and (d) at the push itself.
# DRIFT, "ready for push" only: the frozen spec at the worktree's HEAD still
# freezes, its rows match rules.md and gate.md, its screen one is the approved one
# and it ends in a dated `## Amendments` (shared/frozen.py check --worktree).
# Solo and lead: exit 0.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "ic" ] || exit 0
m="$(j '.tool_input.message')"; [ -n "$m" ] || exit 0
# "· STOP n ·", and "· STOP n (re-send) ·": text after the number up to the next "·" is still STOP n,
# never STOP 10 for STOP 1. A suffix used to skip every gate here.
stopn(){ printf '%s' "$m" | grep -Eq "· STOP $1([^0-9·][^·]*)? ·"; }
stopn '[0-9]+' || exit 0
CAP=30
RECORDS="${FLEET_RECORDS:-$FLEET_HOME/records}"
n="$(printf '%s\n' "$m" | wc -l | tr -d ' ')"
reason=""
has reporting-a-rung || reason="SKILL GATE: a STOP report needs reporting-a-rung, $(why reporting-a-rung). Invoke it with the Skill tool ($SKILLS_ROOT/reporting-a-rung/SKILL.md), fill templates/stop-report.md, then send."
[ "$n" -gt "$CAP" ] && reason="${reason:+$reason }LENGTH GATE: this STOP message is $n lines; the cap is $CAP. The message is the template only (header, rows, options, unverified, files). Move everything else into the report file named on the files line and send the short form; lead-1's haiku check reads the file."
FROZEN_PY="$(dirname "$0")/../frozen.py"
stop1=""; stopn 1 && stop1=1
# (c) the receipt
# the record folder: shared/frozen.py record picks it from the folders the message names, written as
# $RECORDS, ~/.fleet-agent-mgmt/records or $HOME/...; this IC's open folder wins wherever it stands
rec="$(printf '%s' "$m" | python3 "$FROZEN_PY" record "$NAME" 2>/dev/null)"; prc=$?
sl=""
if [ "$prc" -eq 3 ]; then
  reason="${reason:+$reason }RECEIPT GATE: $rec"; rec=""
elif [ "$prc" -ne 0 ]; then
  reason="${reason:+$reason }RECEIPT GATE: the record folder could not be read from the message ($FROZEN_PY record failed). Name it on the files line as $RECORDS/<project>/<lane>-r<n>/, then send."; rec=""
elif [ -z "$rec" ]; then
  :
elif [ -n "$stop1" ]; then
  # STOP 1 comes before the freeze: no receipt yet. The spec line names the commit the owner reviews.
  sl="$(printf '%s\n' "$m" | sed -nE 's/^[[:space:]]*spec[[:space:]]+([^[:space:]]+)[[:space:]]+@[[:space:]]+([0-9a-f]{7,40})[[:space:]]*$/\1 \2/p' | head -1)"
  if [ -z "$sl" ]; then
    reason="${reason:+$reason }STOP 1 GATE: no spec line. STOP 1 carries \`  spec       <repo path> @ <sha>\`, the commit whose screen one the owner reviews; the freeze takes that sha as --approved."
  else
    bad="$(python3 "$FROZEN_PY" stop1 "$rec" "${sl% *}" "${sl#* }" --cwd "${cwd:-.}" 2>/dev/null)" ||
      reason="${reason:+$reason }STOP 1 GATE: $(printf '%s' "$bad" | sed 's/$/;/' | tr '\n' ' ')Fix the spec or run each Checks command once on origin/main and record it in evidence.md (recording-evidence), commit, put the new sha on the spec line, then send."
  fi
else
  rcpt="$(ls -t "$rec"/receipts/*-gate.md 2>/dev/null | head -1)"
  if [ -z "$rcpt" ]; then
    reason="${reason:+$reason }RECEIPT GATE: no gate receipt under $rec/receipts/. Run $FLEET_REPO/shared/records/gate-run.sh $rec from the worktree, then send; red reported as red passes."
  else
    rhead="$(sed -n '1s/.*· HEAD \([0-9a-f]*\).*/\1/p' "$rcpt")"
    chead="$(git -C "${cwd:-.}" rev-parse HEAD 2>/dev/null || echo nogit)"
    if [ "$rhead" != "$chead" ]; then
      reason="${reason:+$reason }RECEIPT GATE: the newest receipt ($(basename "$rcpt")) is at HEAD ${rhead:0:7}, the worktree is at ${chead:0:7}. Run $FLEET_REPO/shared/records/gate-run.sh $rec again at this HEAD, then send."
    else
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        if printf '%s\n' "$m" | grep -F -- "$c" | grep -q '✔'; then
          reason="${reason:+$reason }RECEIPT GATE: ticked over red: the receipt marks \"$c\" red and a ✔ row names it. Report it ✖ with the receipt's exit code and tail; red reported as red passes."
        fi
      done < <(grep -E '^  [0-9]+  red ' "$rcpt" | sed -E 's/^  [0-9]+  red +exit [0-9]+  //')
    fi
  fi
  # the frozen files and the receipt's gate hash; the spec at HEAD at "ready for push"
  wt=(--repo "${cwd:-.}"); printf '%s' "$m" | grep -qi 'ready for push' && wt+=(--worktree "${cwd:-.}")
  bad="$(python3 "$FROZEN_PY" check "$rec" ${rcpt:+--receipt "$rcpt"} ${wt[@]+"${wt[@]}"} 2>/dev/null)" ||
    reason="${reason:+$reason }FROZEN GATE: $(printf '%s' "$bad" | sed 's/$/;/' | tr '\n' ' ')A frozen rule or gate line changes only through a card to lead-1; a drifted spec is restored to the frozen rows."
fi
# (d) the jev lines, at "ready for push", the report before the push (push-gate.sh checks again at the
# push): every jev line in the decision record is backed by a receipts/*-jev-*.json with the same entry
# and verdict (shared/hooks/dr_check.py --audit). A jev line typed by hand would otherwise read as
# checked, and the hook would skip that entry.
if [ -n "$rec" ] && [ -f "$rec/decision-record.md" ] && printf '%s' "$m" | grep -qi 'ready for push'; then
  bad="$(python3 "$(dirname "$0")/dr_check.py" "$rec/decision-record.md" --audit 2>&1)" ||
    reason="${reason:+$reason }JEV RECEIPT GATE: $(printf '%s' "$bad" | tr '\n' ' ')A jev line is written only by the Jev check (the dr-check hook, or shared/records/record-add.sh); a receipt made with JEV_STUB, another JEV_URL or DR_STANDING set does not count. An entry with no jev line: run python3 $FLEET_REPO/shared/hooks/dr_check.py $rec/decision-record.md --worktree <worktree> from the worktree, with none of those set; it checks every entry with none. Any other line: tell lead-1; never move or edit a line by hand. Then send."
fi
# the recipient is lead-1: its name, or the socket of a process whose cwd is lead-1's roster folder
to_lead(){
  local to lead pid pcwd
  to="$(j '.tool_input.to')"; [ -n "$to" ] || to="$(j '.tool_input.recipient')"
  [ "$to" = "lead-1" ] && return 0
  pid="$(printf '%s' "$to" | sed -nE 's|^uds:.*/([0-9]+)\.sock$|\1|p')"; [ -n "$pid" ] || return 1
  lead="$(sed -n '/^```fleet$/,/^```$/p' "$ROSTER" 2>/dev/null | awk -F'\t' '$1=="lead-1"{print $2; exit}')"
  pcwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
  [ -n "$lead" ] && [ -n "$pcwd" ] && [ "$(cd "$pcwd" 2>/dev/null && pwd -P)" = "$(cd "$lead" 2>/dev/null && pwd -P)" ]
}
if [ -z "$reason" ]; then
  # a STOP 1 to lead-1 that passed every gate: its spec sha is the one the freeze may take as --approved
  if [ -n "$stop1" ] && [ -n "$rec" ] && [ -n "$sl" ]; then
    if to_lead; then
      python3 "$FROZEN_PY" stop1-log "$rec" "${sl% *}" "${sl#* }" --cwd "${cwd:-.}" --name "$NAME" --session "$SID" >/dev/null 2>&1
    else
      jq -n --arg c "STOP 1 LOG: this STOP 1 is not sent to lead-1, so no line was written in $rec/stop1.log and the freeze will not take its sha. Send STOP 1 to lead-1 (to: \"lead-1\"); the owner's spec ok counts only after that line." '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
    fi
  fi
  exit 0
fi
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
