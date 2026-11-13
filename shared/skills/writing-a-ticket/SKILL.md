---
name: writing-a-ticket
description: Use when a brief-grilling with the owner has ended ("brief ok") and a rung of fleet work (AgentMgmt Lead and ICs) needs a ticket before an IC is launched, for a Jira ticket, a GitHub issue, or a filesystem ticket (always, for research). Lead-side only; ICs do not write tickets.
---

# Writing a ticket

## Overview

The ticket is the one place "done" is defined for a rung. Everything
downstream (handoff §0, STOP report, recap token) copies from it. A ticket
that names commands but not what their output must say is the failure that
let a broken pipeline run count as done. The ticket names outcomes and
what their output must show; the IC writes the commands, and
`<record>/gate.md` keeps them.

**The rule: an external-facing tracker gets only the PO view** (owner:
"Essentially no fleet info in the Jira ticket pls. This is PO facing";
then: "Github should mirror Jira, infact any external facing entity
should operate in this way (e.g. if we ever use Linear)"). An
external-facing tracker is any place people outside the fleet read the
ticket: Jira, a GitHub issue, Linear, or one not used yet. The fleet
ticket is `<record>/ticket.md`: gate block, standing block, PROFILE,
record paths. It never leaves the fleet: the handoff copies from it and the
review checks it. Each tracker gets its own PO view,
`<record>/<tracker>-po.md`, the only text filed there, holding exactly what
the tracker holds. Two targets today:

| tracker | PO view | template |
|---|---|---|
| Jira | `jira-po.md` | `templates/jira.md` |
| GitHub issue | `github-po.md` | `templates/github-issue.md` |

A tracker not in the table gets its own `<tracker>-po.md`, cut from
`ticket.md` by the step 4d checklist before its first filing. It has no
template until one is written for it. A filesystem or research ticket is
one file, `ticket.md`: nothing leaves the fleet, so there is no PO view.

**Core principle:** no ticket without a complete gate block and a
project profile. Four fields and seven lines, or the skill stops and asks.
In `ticket.md` the Definition of Done is the rung's own lines plus the
standing list and the profile pasted verbatim: one list the review checks.
The PO view keeps only the rung's own lines.

**REQUIRED BACKGROUND:** `foundations/gate-block.md`,
`foundations/definition-of-done.md` and `foundations/artifact-caps.md`
in this directory's parent.

## Process

**First, a brief from a shaping session**, on the owner's typed `shape
<idea> done` in the lead-1 pane (a relay never counts): copy `brief.md`
and `precedents.json` from `$FLEET_HOME/shaping/<idea>/` into
the rung's record folder, a shell `cp`, then run
`shared/records/md-check.sh <record>/brief.md` and
`shared/records/precedents-check.sh <record dir>`. A fault: remove the two
copies, send the owner `<idea> brief back: <the fault line>`, and the
shaping session resumes. Both pass: `shared/launch/shape-up.sh --done <idea>`,
then step 1 as for any brief.

1. **Collect the gate block from the brief**
   (`$FLEET_HOME/records/<project>/<ticket-lowercase>-r<n>/brief.md`, the close of
   `brief-grilling`). Four fields, all required:
   - `proves done`: the outcomes done proves, one per line, in outcome
     words. No commands: before STOP 1 the IC turns each line into a
     command, runs it once on origin/main and records the output; at
     "spec ok" the commands freeze into `<record>/gate.md`. The ticket
     keeps the outcomes; gate.md keeps the commands.
   - `pass`: what the output must show. Exit code, count, or summary line.
     "Passes" and "succeeds" are not pass lines. The pass line is an
     outcome the run proves, never the size of an edit. A diff count is
     not a pass line. The summary line exactly as the pane prints it is
     the IC's, on spec screen one from main's run: the shell output filter
     (rtk) reshapes test runners, so a direct pytest run prints
     "N passed" on green and no "0 failed".
   - `on failure`: always these four clauses (do not tick; report; a
     bounded re-run inside the worktree; stop and ask outside it), in
     this wording:
     ```
     on failure    do not tick; report the failing line. A fix inside the worktree:
                   fix, one DR, re-run, at most 2 re-runs per line; a third red
                   goes to the owner. Anything outside the worktree: stop, ask.
     ```
   - `owner's word`: which pane, before which actions.
   If any field cannot be filled from the brief, STOP and ask the owner for that
   field. Do not guess a pass line. Do not write "as appropriate".
1b. **Find the project's profile** in
   `$FLEET_HOME/profiles/<project>.md` (`PROFILE <project>`). None: stop. The profile is born at
   `brief-grilling` step 2 and appended on the owner's word; a ticket
   is never written without one, and never with a profile written here.
   A profile with no `sandbox` line is valid: every deploy needs the
   word, and `brief-grilling` asks for the line at the next brief.
1c. **Kind.** The brief says `build` or `research`. Research is always
   a filesystem ticket (nothing is filed to any tracker), its gate block's
   pass line is "the analysis answers the question with a
   recommendation and says what it does not prove", and the ticket
   says there is no spec, plan or decision record: the IC writes with
   `writing-an-analysis`, the evidence file holds what was run, the
   rung closes on the owner's word.
2. **Read the project's own quality gates** (Makefile, CLAUDE.local.md
   "Quality gates", or the repo's CI config) and put the pre-commit gates
   in Further detail, verbatim.
3. **Pick the packaging by target** and fill the template. Same content,
   different order and headings. Write `ticket.md` first, then the PO view
   from it (step 4d):

   | target | fleet ticket (`<record>/ticket.md`) | PO view (the only text filed) |
   |---|---|---|
   | Jira | `templates/fleet-ticket.md` | `templates/jira.md`, saved as `<record>/jira-po.md` |
   | GitHub issue | `templates/fleet-ticket.md` | `templates/github-issue.md`, saved as `<record>/github-po.md` |
   | any other external tracker (Linear, a later one) | `templates/fleet-ticket.md` | `<tracker>-po.md`, cut by step 4d; no template yet |
   | filesystem, personal or research | `templates/filesystem.md`, one file, saved beside the specs | none: nothing leaves the fleet |

4. **Where the gate block sits depends on the target.**
   - An external tracker (Jira, GitHub, any other), in `ticket.md`: Definition of Done is plain
     done-lines, one outcome each, no commands; the last line points at
     the gate. The gate block opens Further detail, verbatim. Under it,
     one proof line for each done-line the gate does not cover: an
     outcome and where it shows, or a file and what it contains. No
     commands: the IC writes them on spec screen one. In the PO view the
     same lines stand as CHECKS (step 4d).
   - Filesystem: the gate block comes first in the done section, then
     the other done-when lines, each with its own proof.
   "Runs green" and "deploys" are outcomes, not proofs.
4a. **The standing block, under the rung's own done-lines, verbatim.**
   `DONE, standing` (Part 1 of `foundations/definition-of-done.md`) and
   the project's `PROFILE` block from `$FLEET_HOME/profiles/<project>.md`, byte for byte, under a line reading
   `Standing, every rung on <project>`. In `ticket.md` it closes the
   Definition of Done; on the filesystem it follows Done when. It is never
   in the PO view or on the tracker. A line trimmed or reworded is a line
   the review cannot check. The rung's own lines never repeat a standing
   line.
4c. **The record folder.** Every fleet ticket names
   `$FLEET_HOME/records/<project>/<ticket-lowercase>-r<n>/`
   as the rung's record: the evidence file, the decision record, the
   gate receipts and the close live there. The evidence
   line of the gate block points at `evidence.md` in it. `ticket.md` is
   saved in it, its first line a header: the key, the tracker and its
   link, type, parent, priority, filed time, and "the tracker holds the PO
   view: <jira-po.md | github-po.md | <tracker>-po.md>; this file is the
   fleet ticket".
4b. **Further detail, in the template's order.** On Jira the gate block
   and its proof lines come first. Then a layout diagram when
   the rung changes a layout or topology. Design rules one per bullet,
   the why on the same line; rejected options the same way, never packed
   into one sentence. A revert runbook, numbered and drawn, when
   the rung moves shared state. Read first, pre-commit gates,
   conventions that bite. `Not in this rung`, always, one line of what
   a reader might assume is included. This is the shape of the ticket
   the owner named as the reference.
4d. **The PO view.** Written from `ticket.md` after it is complete, once
   per external tracker, saved as `<record>/<tracker>-po.md` (`jira-po.md`,
   `github-po.md`) under a header line `<KEY> · <Tracker> PO view, the
   description as <Tracker> holds it · set <time> · the fleet ticket is
   ticket.md`. Everything under the header is the text the tracker holds.
   The reader is a PO or a stranger: no fleet information. Checklist:
   - **Cut:** the Summary line's "rung N" prefix (the tracker's title
     field is one plain line, kept in `ticket.md`); the `Standing` line, the
     `DONE, standing` block and the `PROFILE` block; the gate block's
     `on failure`, `owner's word` and `record` lines; the evidence-file
     line and every path under `$FLEET_HOME`; the style source;
     the commit rule; any local or absolute path; roster, pane and role
     names (lead-1, IC, an IC's roster name).
   - **Rename:** GATE BLOCK to CHECKS; rung to ticket; gate to checks;
     word-gated, owner's word to needs approval; Not in this rung to Not
     in this ticket; Pre-commit gates to Pre-commit checks.
   - **Keep:** Overview with its Steer; Definition of Done as the rung's
     own outcome lines, the last one reading "Each line is proven by the
     checks below, first in Further detail"; CHECKS, the gate's
     `proves done` and `pass` lines as plain numbered outcomes, then the
     proof lines; layout diagram; design rules; rejected, one per line;
     revert runbook; merge order; Read first, repo-relative; pre-commit
     checks from CI; the repo's conventions that bite; Not in this ticket.
   - **Check before filing:** `grep -niE
     'lead-1|\bIC\b|rung|gate|standing|profile|roster|\bDR[0-9]|STOP|owner.s
     word|evidence|decision.record|handoff|/Users|fleet-agent'
     <record>/<tracker>-po.md` finds nothing, or each hit is a word the
     repo itself uses.
   GitHub issue: the same checklist, with more force (the issue is read
   by strangers); its layout is `templates/github-issue.md` and its
   checks sit in a fold under Done when. Any other tracker: the same
   checklist, run before its first filing.
5. **Name the style source**, in `ticket.md` only. `fleet template` unless
   the owner named a vetted document in the brief; then its absolute path.
   Never pick one yourself: the repo's existing specs are what this skill
   replaces. The PO view has no style source line.
6. **Check the cap.** Overview under 10 lines. The rung's own done-lines
   under 15; the standing block below them in `ticket.md` is pasted, not
   counted. Overview and done-lines are the same in both files.
   Further detail is a fold with no line cap; each fact once. Over the
   cap, cut before filing.
7. **Draft only.** Filing is on the owner's word, then read the issue back.
   File the tracker's PO view (under its header line) and nothing else:
   `jira-po.md` to Jira, `github-po.md` to GitHub, `<tracker>-po.md` to
   another; read the issue back against that file, not against
   `ticket.md`. A change to the filed text is made in the PO file and,
   when it touches an outcome, in `ticket.md` too, in the same sitting.

## Red flags, stop and fix

- A done-when line with a verb and no proof: "deployed", "passes",
  "verified", "confirmed".
- A command in the gate block or a proof line: the ticket holds
  outcomes, `<record>/gate.md` holds the commands.
- Outcomes grouped: "the three e2e runs" instead of one line each.
- A pass line you inferred rather than read from the notes or the harness.
- A pass line that measures an edit (insertions, deletions, files changed)
  instead of what the run proved.
- A pass line copied from the worked example in `templates/fleet-ticket.md`,
  `templates/jira.md` or `foundations/gate-block.md`. Those are examples.
  A value comes from the brief or the repo's own harness, never from a
  template.
- A ticket with no `Not in this rung` line: the IC decides the scope.
- A fleet word, local path, roster name, profile or standing block in
  text filed to any external tracker: the PO view is `<tracker>-po.md`,
  cut by step 4d.
- `ticket.md` filed to any external tracker, or the PO file trimmed from
  the filed text by hand at filing time: the two files drift and the
  read-back checks nothing.
- A tracker read-back compared with `ticket.md` instead of its PO file.
- A new external tracker (Linear, say) filed from `ticket.md`, or from a
  PO view that has not been through step 4d.
- A ticket for a project with no `PROFILE` block, or a profile written
  into the ticket by hand instead of pasted from the profile file.
- A standing line trimmed, reworded or "summarised"; a rung line that
  restates a standing one.
- A research ticket filed on any tracker, or one that asks for a spec.
- "Keep it short" used to drop the on-failure line. The gate block is
  under 10 lines. Shortness comes from Further detail, never from the gate.

| Excuse | Reality |
|---|---|
| "Pass is obvious from the outcome" | It was obvious on one rung too. The IC ticked a failed run. |
| "The owner is tired, file it now" | Four missing lines cost a rung. Ask for the one field, then file. |
| "The handoff will add the pass line" | The handoff copies the ticket verbatim. Nothing is added later. |
| "The IC knows the harness" | The IC is a fresh session with no memory. It knows the ticket. |
| "The exact command is known, put it in the ticket" | The IC runs each gate line on origin/main before STOP 1 and freezes the commands in gate.md at "spec ok". A gate command written at the grill and never run went red at the IC's first STOP. |
| "The standing list is in the foundations, no need to paste it" | The PO and the review read the ticket. One list, in one place, or the review checks half of it. |
| "The tracker is where the IC reads its ticket, so paste the whole ticket" | The IC reads `ticket.md` and the handoff, never a tracker. A tracker is PO facing; the standing block and the profile there are noise to the PO (the owner's ruling). |
| "Two files drift, file the one ticket" | The PO view is cut from `ticket.md` by a fixed checklist, and the read-back is against `jira-po.md`. One file on a tracker is the drift. |
| "A fleet word is just a word, the PO will skim it" | "Rung", "word-gated DROP" and "PROFILE" meant nothing to the PO. Plain words: ticket, needs approval, checks. |
| "The diff count is exact, it cannot lie" | It measured the edit, not the outcome. On one rung the same correct narrowing read 26/26 one day and 8/8 the next. |

## Example

`templates/fleet-ticket.md` carries an invented rung, ATL-42 on project
atlas, filled in: the fleet ticket. `templates/jira.md` is the same rung as
the Jira PO view; `templates/github-issue.md` as the GitHub PO view. Copy their shapes, replace every value.
