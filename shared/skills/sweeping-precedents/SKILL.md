---
name: sweeping-precedents
description: Use when a brief-grilling on a new rung of fleet work (AgentMgmt Lead) reaches step 0, the fact sweep, and the project's earlier close reports must be read for lessons that bind the new brief; and before writing the rung's precedents.json, which the brief needs beside it. Lead or shaping session only.
---

# Sweeping precedents

## Overview

Earlier rungs on a project closed with lessons: decisions taken after
the handoff (CHANGED), what bit them (LEARNED), what they left behind
(OWED). A lesson that fits the next rung enters its brief, so the IC
designs and plans with it from the start; it is not a separate check
run later. The sweep finds them: a script prints the rows, a haiku
agent replies with candidates as JSON, a code check holds the JSON to
the rows, the lead picks, the owner sees the picks at "brief ok".

**Core principle:** a precedent is input to the brief, never a store of
its own. A row is carried as a brief line with its source and a status,
or listed in `not_carried` with the reason. No row disappears, and the
check proves it: every row the gatherer printed is placed exactly once.

**REQUIRED BACKGROUND:** `brief-grilling` (step 0, the `constraints`
field and its sources), `closing-a-rung` (where CHANGED, LEARNED and
OWED come from).

## When

At `brief-grilling` step 0, dispatched beside the fact sweep and the
probe, before the map. Every rung, the first on a project too. A hook
refuses the first write of the rung's `brief.md` until `precedents.json`
is in its record folder and `shared/records/precedents-check.sh <record dir>`
passes on it, and refuses `precedents.json` until this skill is invoked.

## The files

```
templates/sweep.schema.json        the shape, JSON Schema 2020-12: the single statement of it
templates/sweep-prompt.md          the haiku prompt, with a slot for the gatherer's output
templates/precedents.example.json  a finished precedents.json, invented project atlas
<record>/precedents.json           the haiku reply, saved; then the lead's pick
```

## Process

```
gather ──▶ paste into prompt ──▶ haiku replies JSON ──▶ save <record>/precedents.json ──▶ check <record dir>
                                        ▲                                                   │ fail
                                        └───── re-dispatch once with the faults ◀───────────┤ fail again: lead fixes by hand
                                                                                            │ pass
                                                                                            ▼
                                                        lead picks: moves rows to not_carried ──▶ check again ──▶ brief.md
```

1. **Gather.** Run
   `$FLEET_REPO/shared/records/precedents-gather.sh <project>`.
   It prints the CHANGED, LEARNED and OWED rows of every `close.md`
   under `$FLEET_HOME/records/<project>/`, oldest record name
   first, each row with its reference `<record> · <section> · row <n>`.
   It marks a row whose text an earlier row already has, and names the
   record folders with no close report. It reads screen one of
   `close.md` only, never a `sources/` folder or another record file.
   Exit 2 is a wrong project name: the reason lists the projects there.
   The single line `none: no close report for <project>` needs no
   haiku: save `{"none": "<reason>"}` and go to step 4.
2. **Dispatch.** Fill the two slots of `templates/sweep-prompt.md` (the
   project, the new rung's purpose in one line), paste the gatherer's
   whole output in its slot, and send the rest verbatim with the Agent
   tool, model haiku, in the background, so it runs while the fact
   sweep does. The agent reads only the schema: never hand it the close
   reports or the records folder. It writes no file; its final reply is
   the JSON.
3. **Save** the reply as `precedents.json` in the rung's record folder,
   `$FLEET_HOME/records/<project>/<lane lowercase>-r<n>/precedents.json`,
   byte for byte (a shaping session: its own folder, beside its `brief.md`; the
   check in step 4 then runs when lead-1 takes the brief). A reply wrapped in a markdown fence or prose fails the
   check as not JSON; that is a fault for the re-dispatch, not a hand
   strip.
4. **Check.** Run
   `$FLEET_REPO/shared/records/precedents-check.sh <record dir>`.
   It takes the project and the records root from the path, runs the
   gatherer itself, and checks the file against the schema and the
   gatherer's rows. `--schema <path>` overrides the schema, for tests
   only. Exit 0 is one pass line. Exit 1 prints one line per fault,
   naming the reference or the field. On a fail, re-dispatch the haiku
   agent ONCE with the same prompt and the fault lines in its foot slot,
   and save its reply over the file. A second fail, fix `precedents.json`
   by hand against the fault lines and check again; never a third
   dispatch.
5. **Pick.** Read each candidate against the draft brief. Keep a row
   only when it changes what the IC does on this rung. Then:
   - **Search before write.** Before a row becomes a brief line, look
     for a line that says the same thing (the draft brief, the profile,
     another candidate). Merge them: one P row with both references in
     `sources`, and both on the brief line's `[precedent: ...]` bracket.
   - **Status, checked.** `live` or `stale-after <event>`. A row a later
     close reversed is superseded: it moves to `not_carried` with the
     reason `superseded by <reference>`, and so does a stale row whose
     event has passed. The schema refuses any other status on a P row.
   - **Where it goes,** from `fits`: `constraint` becomes a
     `constraints` item, `gate pass line` a line of the gate block,
     `one-way` a `one-way` bullet, `open` an `open` item. The brief item
     carries its own link, `[precedent: <record> close.md <SECTION> <n>; <status>]`,
     for example `constraints 4  [precedent: atl-40-r1 close.md LEARNED 3; live]`.
   - **A dropped row** moves to `not_carried`, one entry per reference,
     with the reason in one line. Renumber the kept rows P1..Pn.
   - **An owner ruling** a row quotes stays in `owner_quote`, verbatim;
     the check finds it in the source row's text.
   Edit `precedents.json` in place and run step 4's check again. The
   hook runs the same command before the brief's first write and refuses
   it with the first fault lines.
6. **None.** With no close report on the project, the file is
   `{"none": "<reason>"}` (`{"none": "first rung on atlas"}`). Rows
   that exist but none fit are not the none form: they are all in
   `not_carried`, and the check refuses the none form on a project whose
   gatherer printed rows.
7. **Show at "brief ok".** The brief draw carries each precedent line
   with its source like any constraint; the owner reads the source and
   the status before ruling. `not_carried` is not drawn; the file
   answers "what did you leave out".

## Output shape

The schema is the statement; this is the reading of it.

```
{"none": "<reason>"}                                  a project with no close report, only

project, rows_read, records                           the gatherer's, as printed
rows[]  id           P1..Pn, in order
        rule         the rule or lesson, one plain sentence, one line
        sources      references exactly as the gatherer prints them, one or more
        owner_quote  optional: an owner ruling a source row quotes, verbatim
        fits         constraint | gate pass line | one-way | open
        why          one line, tied to the new rung
        status       live | stale-after <event>
not_carried[]  reference, reason (one line)
```

## What the check proves, and what it does not

Proves: the shape is the schema's; every row the gatherer printed is
placed exactly once, and no other reference appears; `rows_read`,
`records` and `project` are the gatherer's; a "(same text as ...)" row
sits where its first row sits; P ids run P1..Pn; an `owner_quote` is in
its source rows' text; the none form appears only when the gatherer
printed no row.

Does not prove: that a rule says what its sources say, that `fits` or
`status` is right, that a `not_carried` row should not bind the rung,
that a superseded reason names the right later row, or that a P row
reached the brief. Those are the lead's pick, and the owner reads them
at "brief ok".

## Red flags, stop and fix

- The haiku agent given the close reports or the records folder instead
  of the gatherer's output pasted in the prompt.
- A `precedents.json` used without a passing `precedents-check.sh` run
  on its record folder.
- A third haiku dispatch after two failed checks, or a fault line
  silenced by editing the gatherer's output instead of the JSON.
- A brief line sourced `[precedent: ...]` with no P row in
  `precedents.json` that carries its reference, or with no status.
- A row carried `live` when a later close reversed it.
- Two brief lines that say the same thing, each with one source.
- `{"none": ...}` on a project whose gatherer printed rows.
- `precedents.json` written from memory of the last rung, with no
  gatherer run.

| Excuse | Reality |
|---|---|
| "I remember what the last rung learned" | Memory carries the last rung; the gatherer carries every rung, with a reference to cite. The sweep costs one haiku pass. |
| "Nothing fits, skip the file" | The hook refuses the brief. Every row in `not_carried`, one reason each, and the check passes. |
| "The haiku reply looks right, skip the check" | The check is seconds; a dropped or invented reference is invisible by eye. The hook runs it anyway before the brief. |
| "Haiku failed twice, dispatch again" | Two fails mean the prompt or the output is the problem. Fix the JSON by hand against the fault lines. |
| "The reply has a fence, strip it and move on" | A fenced reply is a fault: the prompt asked for the JSON alone. Re-dispatch once with the fault line; by hand only after a second fail. |
| "Keep the lessons in a file per project" | A second store goes stale beside the closes. The close reports are the store; the sweep reads them each time. |

## Example

`templates/sweep-prompt.md` is the haiku prompt;
`templates/precedents.example.json` carries the invented project atlas,
rung ATL-44 r1, with three earlier closes and 14 rows read. Copy the
shape, replace every value.
