#!/bin/bash
# SessionStart hook, matcher "startup|resume|clear|compact". On resume the
# markers are kept (the context survived, so the invocations did) and only
# the SKILLS IN FORCE line prints. Otherwise clears this session's skill markers, so every
# gate starts cold and a skill body lost to compaction must be loaded again,
# then prints the skills in force for the role. Solo: silent, exit 0.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "solo" ] && exit 0
[ "$(j '.source')" = "resume" ] || rm -rf "$MARKS" 2>/dev/null
# An IC session that starts on an open, unfrozen record folder of its own leaves a line in its
# ic-sessions.log (shared/frozen.py stamp): the chore freeze refuses a record an IC has worked on.
# A folder with any file committed in the records repo is never written: it closed as committed.
[ "$ROLE" = "ic" ] && python3 "$(dirname "$0")/../frozen.py" stamp "${FLEET_RECORDS:-$FLEET_HOME/records}" \
  "$NAME" "$SID" "session $(j '.source')" >/dev/null 2>&1
mkdir -p "$MARKS"
if [ "$ROLE" = "ic" ]; then
  cat <<TXT
SKILLS IN FORCE ($NAME, IC; hooks enforce these, a gate bounces the write or the turn until the skill is invoked this session):
  STOP report, any turn or SendMessage with a "· STOP n ·" header   reporting-a-rung; the message is the template, 30 lines max, the rest in the report file
  a file under docs/analysis/ or */analysis/                   writing-an-analysis
  a file under docs/adr/ or */adr/                             writing-an-adr
  a file under */specs/                                        writing-a-design-spec
  the close report, a file ending -close.md or a turn opening "close · "   closing-a-rung
  the rung's record folder ~/.fleet-agent-mgmt/records/<project>/<lane>-r<n>/:
    decision-record.md (a DR before any choice the plan left open, a UAT entry, a one-way act)   recording-a-decision
    evidence.md (every run a report or a DR rests on)         recording-evidence
    each DR, UAT and E entry is appended with shared/records/record-add.sh <record folder> dr|uat|e; an Edit mid-file is denied
    rules.md (shared/records/freeze-rules.sh writes it at "spec ok")  writing-a-design-spec
    close.md                                                  closing-a-rung
Invoke the skill with the Skill tool BEFORE the write or the report. Drafts in the scratchpad are exempt.
TXT
else
  cat <<TXT
SKILLS IN FORCE (lead-1; hooks enforce these, a gate bounces the write or the turn until the skill is invoked this session):
  a rung brief, ~/.fleet-agent-mgmt/records/*/brief.md         brief-grilling (the grill for a rung; the brief is its close)
  the record's precedents.json, the step 0 sweep of earlier closes   sweeping-precedents; a new brief is denied until shared/records/precedents-check.sh <record dir> passes on precedents.json
  a session handoff, Leads/lead-1/handoffs/*-session-handoff.md   drafting-handoff
  a rung handoff, ~/.fleet-agent-mgmt/records/*/handoff.md       writing-a-rung-handoff
  Leads/lead-1/briefs/, tickets/ and rung handoffs: history, writes denied
  a ticket, Jira, GitHub issue or filesystem                   writing-a-ticket
  any message to the owner carrying a "check ·" header               reporting-a-rung, Lead side, and the haiku check dispatched with the Agent tool
  any message opening with "held n since"                      holding-rollups
  any message to the owner over 15 prose lines (fenced blocks not counted)   explaining-in-steps (a diagram, one step per turn)
Invoke the skill with the Skill tool BEFORE the write or the message. Drafts in the scratchpad are exempt.
TXT
fi
for m in "$MARKS"/*; do
  [ -f "$m" ] || continue
  s="$(basename "$m")"; f="$(stale_file "$s")"
  [ -n "$f" ] && echo "  CHANGED since this session read it, invoke again before the next gated write or message: $s ($f)"
done
exit 0
