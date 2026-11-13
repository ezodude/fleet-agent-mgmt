---
name: brief-grilling
description: Use when the owner opens a grill on a new rung of fleet work (AgentMgmt Lead), a build or a piece of research, and lead-1 must come out of it with a brief the IC designs from; or a shaping session shapes a new idea into that brief. Lead or shaping session only. Replaces `grilling` for rung work; `grilling` stays for everything else.
---

# Brief grilling

## Overview

A grill one level up. It settles the problem, the goal and why now, the
constraints the owner holds, what is at risk, the one-way acts and the
kind of rung. It does not settle the how: the IC proposes the how on
screen one of the design spec (Direction, Rejected, Subtleties) and the
owner reviews direction at STOP 1. The grill works at a higher level
than the old one: the IC explains direction and why in the design spec,
not in the grill.

**Core principle:** a question about the how is out of scope. When the
owner holds a how, it is a constraint with a source; otherwise it is the
IC's, and the brief says so under `open`. A question on mechanics (where
a step runs, which copy an IC reads, how two rungs share a resource) is
lead-1's call, never a grill question: decide it, write it as a
constraint sourced `[lead-1's call: <reason>]`, and show it in the brief
delta for "brief ok" (`foundations/decision-card.md`, What reaches the
owner as a card). Every question that does go out opens with the problem
in plain words and one example.

**REQUIRED BACKGROUND:** `grilling` (the rounds, the map, the question
shape: the problem first, ids last), `explaining-in-steps` (pacing),
`foundations/one-way.md`, `foundations/definition-of-done.md`.

## What the brief holds

In the file each field is a `##` heading with its text under it;
`constraints` and `open` are numbered lists, `one-way` a bullet list, and
only the gate block sits in a fence.

```
  problem      what goes wrong today, one concrete case, with its evidence
  goal         what is true when the rung is done, in the owner's words
  why now      the clock, the dependency or the cost of waiting
  constraints  the hows the owner holds, one numbered item each, source in brackets, probed facts only  (these become DECIDED rows)
  at risk      what the rung can damage: demo, client, regulated control, money, prod, or none beyond the rung
  one-way      per-rung acts beyond foundations/one-way.md and the profile, one bullet each
  kind         build | research
  gate block   proves done / pass / on failure / owner's word, the four fields of foundations/gate-block.md, outcomes only, no commands
  open         what the IC settles in the spec, one numbered item each, no recommendation; every "assumed: <fact>" item too
  not in rung  one line of what a reader might assume is included
  profile      <project> present | born today (the seven lines below)
```

## Process

0. **Fact sweep, before the map.** Dispatch subagents to read every
   repo fact the fields will need: paths and line ranges, the existing
   pattern to follow, how the harness behaves, what each gate command
   really does. The map goes out when they return, so no question waits
   on a fact: in one grill, facts that arrived after their question
   cost 30 to 70 of 232 minutes.
   **Then probe every environment resource the brief names**: a volume,
   table, bucket, app, deploy target, queue, service or path. One
   subagent, read-only, in dev or the sandbox only. Per resource it
   checks three things: it exists, the IC's identity can write to it,
   and its current state in one line. Only a probed fact may enter a
   `constraints` item or a pass line. Production is never probed. A
   resource that cannot be probed is written `assumed: <fact>` and goes
   to `open`. Each probed fact carries its probe time, inside the
   question and inside the brief's brackets ("probed 11:36: 22 files
   listed at 4e1f0a2"), so the owner sees how old a fact is before
   ruling on it.
   **And sweep the precedents** with `sweeping-precedents`, beside the
   fact sweep: a haiku agent reads the project's earlier close reports
   (CHANGED, LEARNED, OWED, as `shared/records/precedents-gather.sh` prints
   them, pasted into its prompt) and replies with rows as JSON, which you
   save as the record's `precedents.json` and
   `shared/records/precedents-check.sh <record dir>` holds to the printed rows. You pick the rows that change what the IC
   does; the haiku agent only proposes. The picks become brief items
   like any constraint, so an earlier rung's lesson shapes this rung's
   plan, and the owner reads each with its source and status at "brief
   ok". A
   carried row enters `constraints` (or the gate block, `one-way`,
   `open`) sourced with its status: `[precedent: atl-40-r1 close.md
   LEARNED 3; live]`, `live | stale-after <event>`; a superseded row is
   not carried. The rest stays in `not_carried` in the record's
   `precedents.json`; a hook refuses the first write of `brief.md` until
   `precedents-check.sh <record dir>` passes, `{"none": "<reason>"}` on
   a project's first rung.
1. **Open the tree with the seven fields above as its root**, and run
   it as `grilling` runs it: the map, one question per message (with
   the fleet console mod loaded, each question is one card,
   `holding-rollups` step 4e), the problem first and ids last, facts
   from subagents inside the question they unblock. The frontier is
   bounded by the fields: a question that would settle a design choice
   is answered "the IC proposes it in the spec; is there a constraint
   you hold?" and moves to `constraints` or
   `open`. Every block that goes to the owner for a word (a whole brief
   draw, an amendment delta, a gate block) is first broken by a critic
   subagent and fixed, so the owner rules once on the fixed block,
   not again after a late finding. Step 4 holds the gate block's checks.
2. **First rung on a project: the profile questions first**, seven, in
   this order, "none" a valid answer to each:
   1. where the ticket lives (Jira project, GitHub repo, filesystem dir, none)
   2. the gate commands and their pass lines, as the pane prints them
   3. CI: workflow and trigger
   4. deploy and UAT: who deploys, how, where the owner tries it
   5. one-way acts beyond the standing list
   6. the venue for shipped docs
   7. the sandbox: an environment, local or remote, that only this rung
      writes to, or none
   The answers become a `PROFILE <project>` block, the template in
   `foundations/definition-of-done.md` Part 2, written by lead-1 to
   `$FLEET_HOME/profiles/<project>.md` on the owner's word, before the ticket is
   written; lead-1 commits it when written, and again at every edit.
   A profile is project data: it never goes into the
   foundations file or anywhere else in AgentMgmt. `writing-a-ticket`
   refuses a project with no profile. A rung that closed with three or
   more `jev` reworks adds a `pattern` line to the profile, what the IC
   kept trying, on the owner's word. A project whose profile has no
   `sandbox` line gets question 7 at its next brief, before the map;
   the answer becomes the line, on the owner's word. Until then every
   deploy needs the word.
3. **Kind: research.** When the goal is an answer, not a change, the
   rung is research: no spec, plan or decision record; the gate is "the
   analysis answers the question with a recommendation and says what it
   does not prove"; the IC writes with `writing-an-analysis`, the
   evidence file holds what was run; the ticket is a filesystem ticket;
   the rung closes on the owner's word and its ruling becomes the brief
   of the build rung.
4. **Gate block, outcomes only.** Collect the four fields as
   `foundations/gate-block.md` defines them, from the profile's gates and
   this rung's own proof. `proves done` and `pass` are written in outcome
   words: what done proves, never the exact command. The IC writes the
   commands: before STOP 1 it runs each gate line once on origin/main,
   records the output in the evidence file, and shows command, pass line
   and main's output on spec screen one; at "spec ok" they freeze into
   `<record>/gate.md` with rules.md, and `shared/records/gate-run.sh` runs that
   file (a gate went red at the IC's first STOP on brief-written
   commands nobody had run). `on failure` is the bounded re-run:
   ```
   on failure    do not tick; report the failing line. A fix inside the worktree:
                 fix, one DR, re-run, at most 2 re-runs per line; a third red
                 goes to the owner. Anything outside the worktree: stop, ask.
   ```
   A missing field is a question, never a guess. Before the gate question
   goes to the owner, a critic subagent is told to break the draft: does
   each pass line name an outcome a run can show, which done line has no
   outcome proving it, does any line hold a command, does each pass line
   rest on a probed fact, does each `proves done` line have its pass line
   at the same position. Fix what it finds, then ask once: in one grill
   the critic ran after the owner had accepted the block, and re-asking
   cost about 25 minutes.
5. **Close with the brief drawn**, `templates/brief.md`, as the
   shared-understanding diagram `grilling` closes with. Draw what the
   owner has not yet confirmed as a delta against what they have, not
   the whole brief again: re-reading settled lines cost 5 to 8 minutes
   in one grill. Re-read every repo that moved during the grill (`git
   fetch`, HEAD) before the draw, so the brief anchors to today's code. The owner replies "<lane> brief ok" or "<lane> brief
   back: <line>". A "brief back", or an owner question that opens a
   sub-grill on one lane, numbers its items with lane-prefixed letter
   ids: A1..An for the brief's design questions, J1..Jn for a ticket's,
   in order, never reused; a dropped id stays dropped, so a cold reader
   tells a dropped item from a missed one (atlas A1..A6 and J1..J4,
   J3 dropped). When the owner renames a lane mid-grill, ids already
   sent keep the old prefix; new messages, the brief and the ticket use
   the new name from the ruling on, with one line naming the old one,
   so an id quoted earlier still finds its message (atlas renamed
   atlas-ingest at J2 a). Nothing is filed before "brief ok". Delivering
   questions in a batch, defaults accepted, is the owner's to ask for
   in a given grill; never the default, since it breaks one item per
   message.
6. **Save** to `$FLEET_HOME/records/<project>/<ticket-lowercase>-r<n>/brief.md`,
   creating the rung's record folder (a hook gates the path on this skill;
   `Leads/lead-1/briefs/` is history and refuses writes); a shaping session saves to
   `$FLEET_HOME/shaping/<idea>/brief.md`, `precedents.json` beside it, and lead-1 moves both, then `writing-a-ticket` and
   `writing-a-rung-handoff` copy from it: the fleet ticket's (`ticket.md`)
   gate block byte for byte from its fence, the handoff's §2 as the brief. A ticket for an
   external tracker (Jira, GitHub, any other) also gets its PO view
   (`jira-po.md`, `github-po.md`), cut from `ticket.md`; only the PO view
   is filed (`writing-a-ticket`). Before the draw and before the save,
   `shared/records/md-check.sh <brief file>` exits 0: the title a heading, each
   field a `##` heading, `constraints` and `open` numbered lists, only the
   gate block in a fence, no line over 150 characters, as
   `templates/brief.md` shows. A wrapped item keeps its continuation
   lines flush left: an indented one fails the check. Every saved brief
   before this rule failed the check: lined-up fields ran into one
   paragraph and lines ran to 700 characters, so the owner read a brief a
   viewer had broken.
7. **Amend after "brief ok" in place, never at the foot.** Rewrite the
   changed field or list item itself, its source in brackets naming the
   ruling. Under it, after one blank line, the amendment as its own
   paragraph: `amended <date time> · <the ruling, verbatim, venue> · was:
   <the old text>`. Under a list item it is indented to the item's text (three spaces
   under items 1 to 9, four under 10 and up); under a field it starts at the left edge.
   Keep it on one line, or wrap it with flush-left continuation lines: an indented
   continuation fails `md-check.sh`. A gate block line is amended in its
   fence, and its amendment paragraph goes right after the fence, never
   inside it: the ticket copies the fence. Quote a ruling once; a second place it
   changes says `same ruling`. Then carry it the same hour: the decision
   record's `goal amended` line when the goal moved (`recording-a-decision`
   rule 2), and one message to the IC naming each changed field or item. The
   ticket and the handoff stay as filed: the handoff is the IC's launch
   snapshot, and a tracker changes only on the owner's word. A foot block
   leaves the line stale for every reader that copies it (on one rung
   the decision record header copied the pre-ruling goal).

## Red flags, stop and fix

- A question that opens with "should the retry wrap X or Y": that is
  the IC's spec, not the grill.
- A question on mechanics (which environment, which file copy, which
  page or publish, the order of steps) whose answer would be the
  recommendation anyway: lead-1's call, a sourced constraint, no question.
- A question that opens with a diagram, an id or a file:line before the
  problem in plain words.
- A `constraints` item with no source, or one that is a preference
  ("I'd rather").
- A DECIDED row in the handoff that is not an item of `constraints`.
- A brief with `open` empty on a build rung: nothing left for the IC
  to design means the grill designed it.
- A gate block field filled from the template's example.
- A command in the gate block: the IC writes commands before STOP 1.
- A `constraints` item or a pass line resting on a fact nobody probed,
  or a probe sent to production.
- The map sent before the precedents sweep returned, or a
  `[precedent: ...]` line with no status or no row in `precedents.json`.
- A profile question skipped because "it is like the last project".
- A brief drawn or saved while `shared/records/md-check.sh` reports a fault on it.
- The brief filed before "brief ok", or edited after it without a dated
  line.
- An amendment appended at the foot while the line it changes keeps its
  old text.

| Excuse | Reality |
|---|---|
| "The owner already knows how they want it built" | Then it is a constraint with a source, one line. Everything else the IC proposes and the owner reviews at STOP 1, which costs one screen, not a grill round. |
| "Seven profile questions is a lot for a small project" | Seven lines, once per project. Two projects ran rungs with no gate block because nobody asked. |
| "I know the command, write it in the brief" | The IC runs it on origin/main before STOP 1 and the owner sees main's output on screen one. A command written in a grill and never run went red at the IC's first STOP. |
| "Research does not need a gate" | It needs the one gate that stops an analysis without a recommendation. |

## Example

`templates/brief.md` carries the invented lane atlas / ATL-42 rung 1,
with a profile born that day. Copy the shape, replace every value.
