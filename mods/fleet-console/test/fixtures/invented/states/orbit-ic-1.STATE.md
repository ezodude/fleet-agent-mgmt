```state
session: orbit-ic-1
role: ic
rung: ORB-7 r2, research: which columns the weekly survey export keeps, then a draft schema for the export and a sample file
handoff: /Users/owner/.fleet-agent-mgmt/records/orbit/orb-7-r2/handoff.md
repo: /Users/owner/src/orbit/.claude/worktrees/w1 (the IC reads here and writes nothing)
branch: main (research rung, no branch of its own)
head: 7b8c9d0
pushed: no (a research rung pushes nothing)
dirty: 0
stop: STOP 1 sent again 2026-10-20 17:38 after the owner's check (17:37, sample row 4 had an empty date, E6) and the fix (E8); report /Users/owner/.fleet-agent-mgmt/checks/orbit-ic-1/stop-1.md sent to lead-1 in this pane
awaiting: Three questions for the owner, sent to lead-1 at 14:15 BST. Q1: keep the two date columns or merge them into one (the draft schema /Users/owner/.orbit/drafts/week-43/export-columns.schema.json, has both; merging saves a column but loses the time zone). Q2: whether the free-text answers go in the export at all; they hold names in about 1 row in 20 (E14), so they would need a pass that removes names first. Q3: who reads the export first, the data team or the survey owners, since that sets the column order. Meanwhile: the sample file is checked against the draft schema (0 errors, E15) and a second sample with every field empty passes too (E16). Nothing is shared outside the record folder until the owner says so in this pane. Once the answers are in: one pass over the column list, the sample built again, then STOP 2 (about 30 minutes of work). (Earlier asks, for the record: the column order to orbit-ic-2; a name check on the sample by lead-1; then the owner's check
notice: none
next: on "ORB-7 r2 sample ok" from the owner: write the column list into the analysis, score the three export options against it, then STOP 2; carry the "empty dates" finding into the analysis
updated: 2026-10-21 16:33 BST
evidence: /Users/owner/.fleet-agent-mgmt/records/orbit/orb-7-r2/evidence.md (E1-E16)
```
