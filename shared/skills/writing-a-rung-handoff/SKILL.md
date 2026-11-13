---
name: writing-a-rung-handoff
description: Use when a fleet ticket (AgentMgmt Lead and ICs) is filed and an IC is about to be launched in a fresh session on that rung, or relaunched after a kill. Lead-side only; ICs do not write rung handoffs.
---

# Writing a rung handoff

## Overview

The handoff is the IC's only memory and the foundation of the rung: the
gate, the brief (the problem, the goal, why now, what is at risk), the
hows the owner holds with their why, the acts that need the owner's
word, and what is open for the IC to design. The IC proposes the how on
screen one of the design spec; it never re-derives what the brief
settled, and the handoff never designs what the brief left open. A
handoff that buries the gate or paraphrases it is where "pass" once
went missing.

**Core principle:** §0 fits screen one and nothing in it is new. Below
§0 there is no line cap; the cap is on repetition. Each fact once, with
its source. The owner: handoffs "represent a problem succinctly
and communicate identified solutions so that there's no doubt to an
agent or human reviewer later". The
grill settles the brief, the IC explains direction and why in the spec.

**REQUIRED BACKGROUND:** `drafting-handoff` (pointer not payload, anchor
to live state), `foundations/gate-block.md`, `foundations/one-way.md`,
`foundations/definition-of-done.md`, `foundations/artifact-caps.md`,
`foundations/writing-rules.md`, `foundations/public-docs.md`.

## Process

1. **Copy the gate block byte for byte from the record's `ticket.md`**
   (the fleet ticket, never a tracker's text: a tracker holds only the PO
   view, `jira-po.md` or `github-po.md`, with a CHECKS list and no
   `on failure`, `owner's word` or `record` line) into §0 of `templates/handoff.md`. Four fields, labels
   included. Incomplete gate block: stop, fix the ticket with
   `writing-a-ticket`. Never complete it
   in the handoff. `proves done` names outcomes, not commands. The IC
   turns each into a command on screen one, runs it once on origin/main,
   and the commands freeze into `<record>/gate.md` at "spec ok".
2. **RECORD, MODE, BRANCH and SANDBOX lines.** `record` is the rung's folder,
   `$FLEET_HOME/records/<project>/<lane lowercase>-r<n>/`, the
   same path the ticket names. `mode` is `autonomous` unless the last
   close on this project put the next rung at per-task STOPs (band 3+
   or a one-way breach); then `per-task STOPs, from <lane>
   r<n> close`. `branch` names the rung's own feature branch, the only
   branch the IC pushes and opens its draft PR from. Never main, master,
   the repo's default branch, or a branch another person has pushed to.
   `sandbox` is copied from the `sandbox` line of the project profile,
   `$FLEET_HOME/profiles/<project>.md`: deploys and e2e runs to it
   from the rung's branch, at most 2 per rung, one DR each. No line in the
   profile, or `none`: write `none, every deploy needs the owner's word`.
   Never name a sandbox the profile does not.
3. **DECIDED, one numbered row per `constraints` item of the brief**,
   ruler and venue at one offset: `the owner, ATL-42 brief Q2, 2026-09-14`.
   Only the hows the owner holds; changing a row is one-way
   (`foundations/one-way.md`). **OPEN, one line per `open` item of the
   brief**: what the IC settles in the spec and what it blocks, no
   recommendation. A decision card goes here only when the brief could
   not close without the owner's answer and the owner deferred it.
4. **CHAIN as numbered steps, each with its skill and its STOP.**
   ```
   1  design spec   writing-a-design-spec; a public repo doc under foundations/public-docs.md:
                    no fleet name, local path or fleet id in it; each gate line run once on
                    origin/main into evidence.md; screen one's Checks block: per gate line its
                    command, pass line and main's output; the spec path @ sha (nothing after
                    the sha), the count on the spec row, source, record, one card line per
                    open item and the reply words go on the STOP 1 report
                                                     -> STOP 1: screen one to lead-1, hold (direction review)
   2  freeze        shared/records/freeze-rules.sh <spec path> <record folder> --approved <sha> on
                    "spec ok", the sha from the STOP 1 spec line (writing-a-design-spec
                    step 5): rules.md, gate.md and frozen.sha256                                no STOP
   3  plan          superpowers:writing-plans; saved to <record>/plan.md, never in the repo;
                    plan: line in the record header                                             no hold
   4  build         superpowers:subagent-driven-development; recording-a-decision before any
                    choice the plan leaves open; recording-evidence on every run; a red gate
                    line fixed inside the worktree: one DR, re-run, at most 2 re-runs per line;
                    sandbox deploys and e2e runs within the profile's cap of 2, one DR each;
                    the owner's word in this pane before any ONE-WAY line                       one-way asks only
   5  ready         shared/records/gate-run.sh, then STOP 2 "ready for push" report to lead-1           no hold
   6  push, PR      at a green receipt at HEAD and the jev audit exit 0: push the rung's own
                    branch, open a draft PR, one DR each; no word needed; lead-1 audits the
                    record after the push, rework comes as new commits on the same branch      no hold
   7  ready, merge  marking the PR ready on the owner's word in this pane (one DR with the
                    owner line); the owner merges; the IC never merges                          -> close
   superpowers:verification-before-completion before STOP 1, STOP 2 and the push
   ```
   Never as a sentence. In `per-task STOPs` mode step 4 adds a STOP
   after every plan task. The spec replaces superpowers:brainstorming's
   design doc; the brief was the brainstorm.
5. **§1 Read first: absolute paths, line ranges, one reason each.** Open
   every file before writing its line. The `gate source` row points at
   what the IC will build the gate commands from (Makefile, CI file,
   script); omit it when nothing defines them. The `brief` row points at the brief
   file. Relative paths fail: the IC's cwd is a worktree you cannot see.
6. **Live state you read now**: `git log -1`, `git status`, the test
   count from the test command, STATE.md `head` and `stop`. Not from
   memory, not from the ledger.
7. **§2 Brief**: `problem`, `goal`, `why now`, `at risk` copied from the
   brief, then `one-way`: one act per line, verb first, its source
   beside it. The lines are every act on the brief's `one-way` field,
   then every act on the `one-way` line of the project profile,
   `$FLEET_HOME/profiles/<project>.md`, split at each `;` or
   `,` that starts a new act. An act on both is one line with both
   sources. Profile line empty and no brief acts: `none`. The IC copies
   each line into a row of the spec's One-way; the freeze adds only the
   standing list, so an act left off this block never reaches rules.md
   and the decision check never asks about it. Then
   **one section per DECIDED row, numbered to match**:
   `why` in the owner's reasoning from the grill, `rejected` with one
   reason each, `constraint` the ruling puts on the design, one per
   line, its source beside it (file and line, ticket, incident id, dated
   message). A rejected option that cites an incident names its id or
   path. This is the grill's learning; a ruling with no why is a ruling
   the IC will re-open.
8. **§3 Unknowns** the grill could not settle from outside the code,
   each with what it decides. **§4 Sketch** only when a DECIDED row
   forces a shape; otherwise `none: the IC draws it in the spec`. **§5
   Rules that bite**, with file and line, only what causes damage if
   missed. **§6 Report shape.**
9. **Measure §0**: title line to the line before `## 1`, blanks
   included, under 45. Over, move rows to §1 or §2, never the gate or
   the chain. The whole file has no line cap; a fact that appears twice
   is cut once.
10. **Save** to `$FLEET_HOME/records/<project>/<ticket-lowercase>-r<n>/handoff.md` only
   when the IC is being launched on it. Drafts go to the scratchpad. Paste
   it byte-identical into the IC's fresh session.

## A chore: no spec, no STOP 1

A chore (a docs-only cleanup, say) has no design for the owner to
review, so it has no spec, no STOP 1 and no spec freeze. lead-1 writes
its checks into the handoff and freezes them before launch. The handoff
is the template's rung with four changes; the template's last section
shows them. No line of it may name writing-a-design-spec, STOP 1,
`--approved` or a spec freeze: the freeze refuses the handoff and names
the line, so the IC never reads that a STOP 1 holds.

1. **`## Checks` after the CHAIN, before `## 1`**: one table, columns
   `command`, `pass`, `on main`, one row per gate line. Run each command
   once on origin/main first; `on main` is what it printed. The pass
   line is `exit N` and quoted strings only, as in a spec's Checks.
2. **CHAIN without the spec step, the freeze step and STOP 1.** The IC's
   first report is STOP 2 "ready for push".
3. **MODE, OPEN, §3 and §6 without the spec.** MODE: STOP 2 is a report,
   no hold. OPEN: `none`. §3: the IC settles each unknown with a DR.
   §6: STOP 2 "ready for push" only.
4. **Freeze before launch**, from lead-1's folder:
   `shared/records/freeze-rules.sh --chore <record folder>/handoff.md` (`--dump`
   first to read it). It writes rules.md (the standing block only),
   gate.md (the Checks) and frozen.sha256. A refusal: fix the handoff,
   run it again. Never launch a chore before the freeze: the IC's hooks
   write ic-sessions.log in the record when its session starts, and the
   freeze refuses a record that has one.

After launch the handoff's `## Checks` stays as frozen: the chain
compares them with gate.md, and a change denies the push. A check that
must change is lead-1's amendment of gate.md (`shared/amend-frozen.sh`),
as for a rung.

## Red flags, stop and fix

- The gate block appears after anything except the title line.
- A gate field reworded, reordered, or merged with another line.
- A command in §0's `proves done`. The ticket holds outcomes; the IC
  writes the commands on screen one and gate.md keeps them.
- No `branch` line, or a branch that is main, master, the repo's default
  branch, or one another person has pushed to.
- A `sandbox` line the project profile does not hold, or one naming an
  environment another worktree or person can write to.
- A §0 pass line, or any checklist pass line the IC will write, that counts
  diff lines instead of naming the outcome. See `foundations/gate-block.md`.
- The chain as prose: "write the spec, plan it, execute, verify".
- A line that tells the IC to put the record path, the handoff path, a
  fleet name or a fleet id into the spec or the plan. Both are public
  repo docs; those lines go on the STOP 1 report.
- A DECIDED row that is not a `constraints` item of the brief: the
  handoff designed it. An OPEN line with a recommendation: same.
- A STOP between "spec ok" and "ready for push" in autonomous mode that
  is not a one-way ask.
- A §4 sketch on a rung whose DECIDED rows do not force one.
- A DECIDED row with no §2 section, or a §2 section with no `why`.
- A §2 `one-way` block missing an act of the brief's `one-way` field
  or of the profile's `one-way` line, or two acts on one line.
- A CHAIN freeze step with no `--approved <sha>`.
- A chore launched before `freeze-rules.sh --chore` ran, or a chore's
  CHAIN with a spec step or STOP 1.
- A constraint block as prose: four facts in one paragraph, no source.
- Any path without a leading `/`, or a path you did not open today.
- A HEAD, SHA or test count you did not read in this session.
- A placeholder left in a filed handoff: `TBD`, `as appropriate`,
  `similar to rung 1`, `<fill in>`, `see the usual`. The IC has no
  "usual". Same rule as superpowers:writing-plans.
- "The last handoffs were too long" used to cut §2. Length comes out of
  repetition, never out of rulings, constraints or the chain.

| Excuse | Reality |
|---|---|
| "The IC has the ticket, the gate is there" | The IC reads §0 cold. The ticket is one pointer among seven. |
| "The chain is obvious to a principal IC" | Obvious is how verification-before-completion ended at line 223 of 227. |
| "The why is in the grill transcript" | The IC never sees the grill. A ruling without its why gets re-derived, differently. |
| "A sketch helps the IC start" | A sketch is a design the owner never reviewed. The IC draws, STOP 1 reviews. |
| "Relative paths are fine, it is in the repo" | The worktree is under `.claude/worktrees/`. Relative resolves wrong. |
| "The profile's one-way acts are standing, the freeze adds them" | The freeze adds only `foundations/one-way.md`. A profile act reaches rules.md only as a row of the spec's One-way, copied from §2. |
| "I know HEAD from the ledger" | The ledger is where stale SHAs come from. Read git. |
| "The template's example path will do for now" | Template paths are invented. A path you did not open is not anchored. |

## Example

`templates/handoff.md` carries an invented rung, ATL-42 on project atlas,
filled in end to end. Copy its shape, replace every value.
