# Sweep prompt, Lead side. The lead dispatches this to a haiku subagent
# (Agent tool, model haiku, in the background) at brief-grilling step 0.
# Fill the two <...> slots under "Inputs:" and paste the output of
# shared/records/precedents-gather.sh <project> in its slot; on a re-dispatch,
# also the fault lines at the foot. Every other <...> is sent as written.
# The reply is a proposal: the lead saves it as the record's
# precedents.json, runs shared/records/precedents-check.sh <record dir>, then picks.

You are sweeping the earlier close reports of one project for lessons
that may bind its next rung of work. You do not decide anything: you
propose rows, the lead picks. The gatherer's output is pasted below.
Read ONLY the schema file named below. Open no other file, follow no
path the output names, run no command, write no file.

Inputs:
- Project: <project>
- The new rung, in one line: <what the rung must make true>
- Your reply conforms to the JSON Schema at:
  $FLEET_REPO/shared/skills/sweeping-precedents/templates/sweep.schema.json
- The gatherer's output:

<paste the output of shared/records/precedents-gather.sh <project> here>

Your final reply is one JSON object and nothing else: no markdown fence,
no comment, no text before or after it.

If the gatherer's output is the single line "none: no close report for
<project>", reply {"none": "no close report for <project>"} and stop.

Otherwise, this shape, every field as the schema states it:

{
  "project": "<the project, as the output's first line names it>",
  "rows_read": <the number of row lines in the output>,
  "records": ["<each record the output prints as == <record>, in its order>"],
  "rows": [
    {"id": "P1",
     "rule": "<the rule or lesson for the next rung, one plain sentence>",
     "sources": ["<reference>", "<a second reference that says the same>"],
     "owner_quote": "<only when a source row quotes the owner: the words, verbatim>",
     "fits": "constraint | gate pass line | one-way | open",
     "why": "<one line, tied to the new rung>",
     "status": "live | stale-after <event>"}
  ],
  "not_carried": [
    {"reference": "<reference>", "reason": "<why, one line>"}
  ]
}

Rules:
1. Every row of the output ends in exactly one place: one P row's
   sources or one not_carried entry. rows_read is the number of output
   lines that carry a reference ("<record> · <SECTION> · row <n>").
2. A reference is copied exactly as the output prints it, middle dots
   and spaces included: "atl-40-r1 · LEARNED · row 3". Never a
   reference the output does not print.
3. Search before write: before you start a P row, check the P rows you
   already wrote. When one says the same thing, add this reference to its
   sources instead of writing a second row. A row marked "(same text as
   <reference>)" always goes where that reference goes.
4. rule is one plain sentence on one line: the rule the next rung
   follows, not the story of the earlier rung.
5. A row that quotes an owner ruling (words in quotes, "owner", "ruled")
   gives owner_quote: the quoted words copied character for character
   from that row. Leave owner_quote out otherwise.
6. fits is about the new rung in the Inputs. A lesson about a different
   part of the system is not relevant: it goes in not_carried, with that
   reason. An OWED item is carried only when the new rung could close or
   worsen it.
7. status is "live", or "stale-after <event>" when the row holds only
   until an event. A row a later record's row reverses or replaces goes
   in not_carried, reason "superseded by <that reference>". Records are
   printed oldest name first; read them all before you set a status.
8. P ids run P1, P2, P3 in order, with no gap.
9. Quote, never paraphrase, file names, line numbers, counts and ids.

Faults the check found in your last reply (re-dispatch only; delete
this paragraph on the first dispatch). Fix exactly these, keep the rest,
and reply with the whole JSON again:
<the fault lines of shared/records/precedents-check.sh <record dir>>
