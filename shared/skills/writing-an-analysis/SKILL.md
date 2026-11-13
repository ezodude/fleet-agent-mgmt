---
name: writing-an-analysis
description: Use when a fleet IC (AgentMgmt Lead and ICs) is asked to analyse, investigate, compare or find out something and write the result up for the owner or lead-1 (the AgentMgmt Lead session) to decide on. IC-facing; lead-1 reviews against it.
---

# Writing an analysis

## Overview

An analysis is read once, cold, by someone deciding what to do next. Screen
one answers their three questions and stops; everything that backs it sits
below a fold they choose to open. The owner's words: "an IC generates
too much info, not concise, requires many hours to rationalise".

**Core principle:** the reader decides from screen one. Screen one is the
title line to the `---` fold, under 45 content lines: blank lines,
headings and fence lines are not counted. Over 45 is returned with the
count. Cutting blank lines to fit is a red flag.

**Who reads it:** a committed analysis is read by the team, PR reviewers
and anyone with repo access, on GitHub, as rendered markdown. It is
written for them and never names the fleet: step 5 holds the list. This
holds whenever the file is committed where a team reads, the path the
ticket names included.

The card shape is in the template. Its full rules:
`$FLEET_REPO/shared/skills/foundations/decision-card.md`.
Read it once; the template stands alone after that. In the file a card
carries no IC name, no lane id and no reply line; those go on the STOP
report.

Ids: in the file, open items are `Open 1`, `Open 2`, in the order they
appear. On the STOP report each becomes a card with its lane id: `ATL-17
D1` is lane `ATL-17` (the ticket key from the ticket or handoff lead-1
gave you) plus `D1` for Open 1. The lane id never goes in the file.

## Steps, in order

1. **Style source.** The file carries no style line. When the ticket
   names a document the owner has vetted, read it and match its voice,
   never its length. Otherwise the template is the form. Do not pick a
   neighbour yourself.
2. **Screen one**, `templates/analysis.md`, in this order, nothing else:
   - title line `# <ticket key> · project · title · date`, no IC name
   - `**Verdict:**` one line, the answer
   - `## Found`, a fenced block: one row per finding, glyph first, the
     proof beside it. No proof: it is not a finding, it becomes an open
     card `unverified`
   - `## Decides`, a list: one row per thing the findings settle
   - `## Open`, one fenced card per item still needing a decision,
     fields as in the template. Only items the ticket raised or the facts
     force
3. **The fold**: a blank line, `---`, a blank line, then `## Appendix`,
   one `###` section per open item with its trace (mechanism, cases,
   rejected options, evidence the team can open), aligned lines inside a
   fence, under 15 lines each; then `### History`.
4. **Count.** Content lines from the title to the `---`, by the rule
   above. Over 45: move a finding to the appendix, never compress the
   rows, never cut blank lines. The count goes on the STOP report as
   `screen one: N lines`, not in the file.
5. **Public check.** Search the file for each of these and rewrite every
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
     writing-an-analysis, superpowers:...

   Then the render check: a blank line between every block (after the
   title, between paragraphs, before and after every heading, list,
   table and fence, before the `---`); section titles as `##` headings,
   not ALL-CAPS lines; column-aligned blocks inside ``` fences, prose and
   lists outside. No line of text directly above a `---`; every fence
   opened is closed. A write hook and the push gate check some of this
   too; when one denies, rewrite the line it names. They do not replace
   this step.
6. **Deliver.** Save at the path the ticket names, else `docs/analysis/
   <lane-lowercase>-<kebab-title>.md`. Commit on the rung's branch and put
   the path on the `files` line of the STOP report, with one card per
   open item in the `foundations/decision-card.md` shape: lane id, IC and
   reply line. lead-1 reviews from there and puts the cards to the owner.

## Red flags, stop and fix

- No `---` fold, or over 45 content lines above it.
- Blank lines cut to fit 45, or a line of text directly above the `---`.
- An open item as a paragraph, a bold line or a table, not a card.
- A finding whose proof is "see the evidence log".
- A style line, or a source named but not read.
- A local path, an IC name, a lane id, a reply line or an evidence id in
  the file.
- An ALL-CAPS line as a section title, or aligned rows outside a fence.
- Open items the ticket never asked about, added to be thorough.
- A number in a finding invented to fill the proof column.

| Excuse | Reality |
|---|---|
| "It needs the history to make sense" | History is appendix. The reader who wants it scrolls once. |
| "The open item is simple, a table will do" | A card has the options and a recommendation, answered with one letter. A table makes the owner write the reply shape himself. |
| "Compressing the rows keeps it under 45" | Dense rows are the retro's complaint. Cut, do not squeeze. |
| "The evidence path helps the reviewer" | The reviewer has it on the STOP report. The team cannot open it. Cite a repo file or the ticket. |
