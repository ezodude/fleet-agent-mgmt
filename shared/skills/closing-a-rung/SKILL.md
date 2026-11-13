---
name: closing-a-rung
description: Use when a fleet IC (AgentMgmt Lead and ICs) has merged a rung and writes the close report, the last message of the rung to the owner, after the final STOP report was accepted and before STATE.md marks the rung closed.
---

# Closing a rung

## Overview

The close report is one screen the owner reads cold, on a day with five
lanes open, to answer one question: is this rung done as ruled, and what
does it leave behind. It is rendered from artefacts that already exist
(ticket, handoff, spec, STOP reports, evidence file), not written fresh.
The only new content is LEARNED and the rung's numbers.

**Core principle:** the gate block decides done. The verdict is the gate
rows and the SHIPPED gap, nothing the IC reasons.

**REQUIRED BACKGROUND:** `foundations/gate-block.md`,
`foundations/decision-card.md`, `foundations/artifact-caps.md`,
`foundations/writing-rules.md`, `foundations/fournier-tech-lead.md`,
`foundations/definition-of-done.md` and `$FLEET_HOME/profiles/<project>.md`
(the profile line),
`recording-a-decision` (the folder the close lives in).

## When

After the merge, after lead-1's audit after the push (the REVIEW entry,
with the band) and its acceptance of the last STOP report, before
STATE.md says closed. Not at a STOP: that is `reporting-a-rung`. One
close per rung. Path: `close.md` in the rung's record folder,
`$FLEET_HOME/records/<project>/<lane lowercase>-r<n>/close.md`
(the artefact gate sees it there). A rung whose
handoff predates 2026-10-08 and has no record folder closes at the old
path, `$FLEET_HOME/checks/<ic>/<lane lowercase>-r<n>-close.md`. The message
to lead-1 that carries it opens with the same header line.

## Steps

1. **Header, one line.** `close · <ic> · <lane> rung n · <title> · <datetime> · merged <sha>`.
   The sha is the merge commit on the main branch, read from git, not memory.
2. **Verdict line.** One of `✔ shipped as designed`, `✔ shipped as designed with N gaps, below`,
   `✖ not shipped: <line>`. Then the reply strings, verbatim, each in
   backticks (a bare `<line>` is read as an HTML tag and vanishes):
   Reply `<lane> close ok` or `<lane> close back: <line>`. A verdict without both
   strings gives the owner nothing to type. When OWED has rows with owner
   `owner`, the verdict ends `N owed items need an owner`; "close ok"
   accepts the tables as written and the owner assigns in the same reply,
   one line per item.
3. **SHIPPED.** Three rows: `designed` (one line, from the spec's `## Building`), `built`
   (one line, from the merged code), `gap` (one line per difference:
   what differs · the card or amendment id and date · the why in one clause).
   Who accepted it and when is a CHANGED row, not part of the gap line.
   No gap: the row reads `none`. A gap in prose below the fold is a hidden gap.
   The three rows go in a ``` fence, after a blank line, so a viewer keeps
   them as lines.
   Before the table, re-run the freeze's check on the merged spec against
   the frozen files:
   `git -C <worktree> show <merge sha>:<spec path> | $FLEET_REPO/shared/records/freeze-rules.sh --check - --path <spec path> --record <record folder>`.
   Exit 0: the merged spec still holds every frozen row. Exit 2: each
   reason it prints is a `gap` row (`spec drift: <reason>`), and the
   verdict cannot be `✔ shipped as designed`. Rows lead-1 retired or
   added by amendment pass either way. A folder in
   `shared/records/legacy-records.txt` prints a note and exits 0: write
   `legacy rung, not checked` under the table.
4. **PROVED, one row per gate in the gate block of the record's `ticket.md`, no other rows.**
   GATE | PASS LINE | ACTUAL OUTPUT | DOES NOT PROVE. The pass line is copied
   from the ticket, the actual output from the evidence file, glyph first.
   No pass line on record means the glyph is `?`, never `✔`: a gate nobody
   declared before the run proves what the author says it proves. Red rows
   first, then `?`. A red row makes the verdict `✖`. DOES NOT PROVE names
   what this gate's own output leaves open, never empty. Claims the rung
   rests on that no gate covers go under the table, after a blank line,
   as a list under one label: `not proved by any gate:`, then one
   `  - <claim>, <who or what would prove it>` per line. Other
   measurements (a migration timing, a row count) go to the appendix.
5. **CHANGED, one row per decision record entry and per owner card.** ID |
   QUESTION | DECIDED | CONSEQUENCE IN THE CODE | BY, REVIEW. The id is the
   DR, UAT or card id; the question from the entry's `question` line
   (the owner's words for a UAT row or a card); the decision in one line;
   the consequence names the file or function it landed in; BY is the IC
   or the owner, and REVIEW is lead-1's `review` line for a DR (`ok`,
   `rework: <reason>`) or the ruling date for a card. The push and the
   draft PR read `IC, at green receipt <time>`, or `IC, red lines <n> overridden
   by the owner <time>` when the owner overrode a red gate line (one row per
   override, its reason in DECIDED); marking the PR ready reads
   `owner's word <time>`. Nothing here is new to the owner. No rows: `none`.
5b. **NUMBERS, the rung's counts, two lines at most.** `DRs n
   (one-way n, with the word n) · jev rework n · rework items n (crossed a
   line n, claim false n, better path n) · rework rounds n · cards n ·
   UAT n · days to draft PR n · band <0 | 1-2 | 3+>`. Read from the
   record, not from memory. The band is lead-1's, from its audit after
   the push (the REVIEW entry); the score is set here, at the close, and
   moves the next rung's mode. Three closes on a project with these
   lines are the retro's input.
5c. **PROFILE, one line.** `profile: unchanged` or
   `profile changed: <the line as it should now read>`; lead-1 edits
   `$FLEET_HOME/profiles/<project>.md` on the owner's word and
   commits it when written.
   NUMBERS and PROFILE share one ``` fence.
6. **LEARNED, one row per fact.** KIND (`went wrong` / `went well` / `got lucky`
   / `missing guardrail`) | FACT | EVIDENCE. One `missing guardrail` row per
   rework item: the one check, hook or rule line that would have caught it.
   A fact is one sentence a future rung can act on; the evidence is a
   file and line, a test, or a quoted output. A lesson
   without evidence is an opinion. Root cause A in the retro was a false
   pass; every `got lucky` row is a gate that nearly missed.
7. **OWED, one row per item this rung leaves behind.** ITEM | OWNER | STATE.
   The owner is a ticket id, a team, or `owner` (to decide); never `unowned`
   without a row asking the owner to assign it. State is `filed <date>`,
   `not filed`, or `to decide`.
8. **`---`, then the appendix:** Trail (one row per STOP with path, the
   receipt beside STOP 2 and the time of lead-1's audit), Commits (merge
   sha, PR, count, subjects: the close cites the PR and the merge; the
   ledger line cites the folder), Amendments (copied from the spec),
   Not measured (every number screen one rests on that has no command
   beside it in the evidence file), Glossary (every fleet or project term
   screen one uses that a reader outside the lane would not know: the
   release train, the grill, owner's word, band), More information (absolute paths).
   Trail is a table; every other appendix section is its lines in a ``` fence.
9. **Align, width, count.** Run
   `$FLEET_REPO/shared/skills/closing-a-rung/bin/align-tables.py <file>`:
   every table padded to its widest cell, with a blank line above and
   below it (a markdown viewer pulls a line written straight under a
   table into it as a one-cell row). Then run
   `$FLEET_REPO/shared/records/md-check.sh <file>`: it renders
   the file as a viewer does and names each line swallowed into a table,
   lined-up text merged into one paragraph, `<word>` that vanishes and
   line over 160 characters. Exit 0 before the close is sent; fix every fault.
   A cell holds one fact under about 70 characters; the why
   of a fact goes to the appendix, not the cell. The script prints the
   screen one count (header line to `---` inclusive, blank lines and
   fence lines not counted); write it as the last line, `screen one: N
   lines`, N under 45. Over: cut repetition, never rows, never the blank
   lines or fences.
10. **Send the close and stop; lead-1 commits the record folder.** The IC
   never runs git in `$FLEET_HOME`, the owner's own repository.
   lead-1 commits the folder at the ticket end, however the ticket ends,
   in the same step as the ledger entry that records the end. Nothing
   in the folder is edited after that commit; a later correction is a new
   rung's entry that names it.
11. **STATE.md** then reads closed, with the close path in `stop` and
   `awaiting: none`. lead-1's ledger
   close line carries the record folder's absolute path, the merge sha and
   the sha of lead-1's record folder commit.

## Why this shape, the theory behind it

Each section answers one question in a fixed order, so the owner reading
five closes reads five identical screens. Sources, so the shape can be
argued with rather than taken on faith:

  | SECTION       | SOURCE                                       | WHAT IT BORROWS                                                  |
  | Verdict first | BLUF, US Army AR 25-50; Grove, HOM ch. 3     | conclusion before evidence; read the exception                   |
  | SHIPPED       | After Action Review, US Army TC 25-20        | meant, happened, why the difference                              |
  | PROVED        | fleet gate block; retro root cause A         | pass line beside output, so a false pass shows                   |
  | CHANGED       | PRINCE2 End Stage Report                     | what moved from the plan, ruled by whom, at a boundary           |
  | LEARNED       | Google SRE book ch. 15, blameless postmortem | went well, went wrong, got lucky; fact plus evidence             |
  | OWED          | SRE action items; PRINCE2 follow-on actions  | one owner and one state per item, or it is lost                  |
  | one screen    | SBAR handover; Patagonia 5-15 report         | fixed order for a cold reader; 15 min to write, 5 to read        |
  | rendered      | Fournier, The Manager's Path ch. 3           | the lead is judged on outcomes, so show outcomes against rulings |

HOM is High Output Management; Fournier's chapter is summarised in
foundations/fournier-tech-lead.md. Cited from memory of the sources, not from links: the fleet keeps no
external dependencies in skills. Check the source before quoting it outward.

## Red flags, stop and fix

- The gap appears only in prose below the fold, or not at all.
- A close with no `--check --record` run on the merged spec, or a
  `✔ shipped as designed` over a check that exited 2.
- A verdict without the two reply strings.
- A gate row with a tick and no quoted output, or output with no pass line.
- A DOES NOT PROVE cell left blank, or "n/a".
- A `✔` beside `PASS LINE: not in the record`.
- A ruling column reading `a)` alone, with no question and no consequence.
- LEARNED as numbered paragraphs, or a row with no evidence cell.
- A table whose bars do not line up: the align script was not run.
- A line straight under a table, or blank lines cut between sections to
  fit the count: the viewer renders it as a broken row.
- Aligned plain text (SHIPPED, NUMBERS, an appendix list) outside a
  fence, or a bare `<word>`: the viewer merges or drops it.
- A line over 160 characters: the pane wraps it and the bars stop lining up.
- A rung-level unproved claim sitting in a gate's DOES NOT PROVE cell.
- An OWED row with `unowned` and nothing asking the owner to assign it.
- The reader addressed as `you`; the report says `the owner`.
- A number on screen one with no command in the evidence file and no
  `Not measured` row.
- A NUMBERS line from memory, or one missing a count; a band that is not
  the REVIEW entry's; a close with no `profile:` line.
- A rework item with no `missing guardrail` row in LEARNED.
- An IC's git command in `$FLEET_HOME`, or a record folder edited after lead-1's commit.
- A close written to `$FLEET_HOME/checks/` for a rung that has a record folder.

| Excuse                                        | Reality                                                                                                                   |
|-----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| "The gap is explained in CHANGED"             | CHANGED is the ruling; SHIPPED gap is the difference. Both, or the owner reads the ruling and misses that the code moved. |
| "The STOP 3 report already has the gate rows" | The owner does not open STOP 3. The rows are copied, with the pass line, or the close proves nothing.                     |
| "Everything went well, LEARNED is empty"      | One rung went well until it was quizzed. A rung with nothing learned was not looked at. Name the got-lucky.               |
| "The tables are readable enough"              | The owner: "the table cols don't line up sometimes, making it hard to read". Run the script.                              |
| "The theory is obvious, drop the section"     | The shape is argued with, not obeyed. A reader who wants to change it needs to know what each part costs.                 |

## Example

`templates/close.md` carries the invented lane atlas / ATL-42 rung 1, filled
in with one gap, two gates, six changes, two lessons and two owed items.
Copy the shape, replace every value, run the align script.
