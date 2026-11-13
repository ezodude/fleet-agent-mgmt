---
name: writing-an-adr
description: Use when a fleet IC or lead-1 (AgentMgmt Lead and ICs) records a decision the owner has ruled, as an architecture decision record in Confluence, the repo's docs/adr, or wherever its existing ADRs live. IC-facing; lead-1 reviews against it.
---

# Writing an ADR

## Overview

An ADR is read later, by someone who was not there, to understand what was
decided and why. The form is the fleet ADR form, defined in full by
`templates/adr.md`; nothing outside this directory is needed to write one.
Provenance only: the form was distilled from a Confluence ADR the owner
picked as the reference ("everything should keep that ADR form").

**Core principle:** decision first, diagrams for flow, tables for
attributes, evidence when it exists, no sentence twice. There is no line
cap. The cap is on repetition and on hops.

**Who reads it:** the team, PR reviewers and anyone with repo or space
access, on GitHub or in Confluence. The ADR is written for them. It never
names the fleet: step 15 holds the list.

Sources: the decision came from a ruling. Cite it where the team can open
it: the ticket, a dated team channel message, a PR. Give the decider's
words and their role in the team, for example `ROW-12, product owner
comment, 2026-09-14: "keep the enum closed"`. Never cite a grill, a pane,
the brief, the handoff or the record. The ticket key, the ruling and where
the team can read it, and for Confluence the space key and ADR parent
page, are in the ticket or handoff lead-1 gave you. Missing: ask lead-1
before step 1, never guess.

## Steps, in order

1. **Writing rules.** Read
   `$FLEET_REPO/shared/skills/foundations/writing-rules.md`
   once. The four rules that bind here: options differing in attributes
   go in a table, options differing in flow go in a diagram, both when
   both apply, each once; every outside fact carries its source on the
   same line; a glossary when the reader may not know the subject; no
   paragraph over five lines.
2. **Form and place.** The ADR carries no style line. The template is the
   form unless the ticket names an ADR the owner has vetted; then match
   that one. Numbering and filename follow the neighbours where this one
   will live (the Confluence space from the ticket, or `docs/adr/`);
   none: `docs/adr/0001-<kebab-title>.md`.
3. **Metadata table**, `templates/adr.md`, first thing on the page:

   | FIELD | WHEN |
   |---|---|
   | Status | always: Proposed, Accepted, Superseded by ADR-NNN |
   | Date | always |
   | Drivers | always: who pushed for the decision, by name or team role, never a fleet name |
   | Relates to | always, `none` if none |
   | Approver | when someone other than the drivers signs it off |
   | Epic | when the work sits under a Jira epic or GitHub milestone |
   | Discovery | when a spike or discovery ticket preceded it |

4. **Decision**: one sentence, then at most three lines on the fact
   everything else follows from.
5. **Problem**: what is happening today and what is missing. A diagram
   when there is a flow or a gap to show; prose under five lines
   otherwise. Boxed "WHAT IS MISSING" when the gap is the point.
6. **Options**: each option in one short paragraph, chosen or not chosen
   in its heading. Then the comparison: a table for attributes (cost,
   identity, grants, code to write), a side-by-side diagram for flow,
   both when the options differ in both. Each fact in one of them, never
   both.
7. **Decision outcome**: "Adopt X. N facts back it." then one bold word
   and one paragraph per fact, under five lines each.
8. **Evidence**, only when a run, probe or query exists: what was done,
   the output as a table, what was torn down. Never invented; omit the
   section instead.
9. **Consequences**: three bold labels, Positive, Cost, Watch, one line or
   one short list each.
10. **Confirmation**: a table, one row per item, columns ITEM · OWNER ·
    STATE. Not a checklist of bullets, not a diagram. OWNER is a name or
    a team role.
11. **Glossary**, when the reader may not know the subject: one line per
    term, ten at most. Omit the section otherwise.
12. **More information**: every link and citation the body used, plus the
    meetings and messages that shaped it, dated. Only what the team can
    open. Always present.
13. **Repetition check.** Search the body for each option's name and each
    fact in Decision outcome. Each appears in its own section once and in
    Decision or Options once more. A third time: delete it.
14. **Strip the markers.** The template's comment is gone, and every
    `(situational)` and `(when it exists)`; a section or row with nothing
    real behind it is deleted, not left blank.
15. **Public check.** Search the ADR for each of these and rewrite every
    hit: cite the ticket, a repo file and line, an incident id, a dated
    team channel message or a PR, or drop the line.
    - an absolute local path: `~/...`, any home-folder path, `/private/tmp`, `/tmp`
    - `.fleet-agent-mgmt`, `~/.claude`, `checks/`, `records/<project>/...`,
      a record-folder file name (handoff.md, brief.md, decision-record.md,
      evidence.md, rules.md, gate.md, close.md, receipts/)
    - lead-1, an IC roster name, "the IC", "the fleet", "the owner" (write
      the person's role in the team, e.g. "the product owner")
    - STOP n, "screen one", "spec ok", "Reply:", "handoff", PROFILE,
      "gate block", jev, band
    - DR, UAT and E ids, a lane-prefixed decision id (`ATL-42 D2`); a Jira
      key alone (`ATL-42`) is fine, it is the team's ticket
    - a skill or AgentMgmt file name: one-way.md, foundations/,
      writing-an-adr, superpowers:...

    A file ADR must also render on GitHub: a blank line between every
    block (after the title, between paragraphs, before and after every
    heading, list, table and fence, before a `---`); section titles as
    `##` headings; column-aligned blocks inside ``` fences, prose and
    lists outside. No line of text directly above a `---`; every fence
    opened is closed. A write hook and the push gate check some of this
    too; when one denies, rewrite the line it names. They do not replace
    this step.
16. **Deliver.** Confluence: create under the ADR parent page from the
    ticket, title `ADR-NNN: <title>`. File: save at the path from step 2,
    commit on the rung's branch. Either way put the URL or path on the
    `files` line of the STOP report. lead-1 reviews from there.

## Red flags, stop and fix

- Decision not on the first screen, or stated after the problem.
- Options compared in prose, or a numbers comparison drawn as a diagram.
- A confirmation list as bullets or a diagram.
- Evidence section with no real run behind it.
- A fact with no source beside it, or no More information section.
- A paragraph over five lines.
- The same sentence in Decision, Options and Decision outcome.
- A style line, a local path, a fleet name, a fleet id or a grill cited
  anywhere in the ADR.
- A line of text directly above a `---`, or an aligned block outside a
  fence.

| Excuse | Reality |
|---|---|
| "The reader wants the full argument" | The reader wants the decision, then the argument once, in the section that owns it. |
| "A checklist reads fine as bullets" | Bullets have no owner and no state. A table does. |
| "There is no evidence, I'll describe what would happen" | Then there is no Evidence section. Say `unverified` where it matters. |
| "The record path helps the reviewer" | The reviewer has it on the STOP report. The team cannot open it. Cite the ticket. |
