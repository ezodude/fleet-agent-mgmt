---
name: writing-a-design-spec
description: Use when a fleet IC (AgentMgmt Lead and ICs) writes the design document for a rung from the handoff lead-1 gave it, the step the CHAIN lists before superpowers:writing-plans. IC-facing; the owner approves screen one at STOP 1, lead-1 audits the rest after the push.
---

# Writing a design spec

## Overview

The spec is where the brief meets the code. The brief says what is
wanted and why; the IC proposes the how. Screen one is the RFC the
owner approves cold at STOP 1: the direction and why this way, what the
IC rejected, the subtleties the wider company must know, the rules the
rung runs under, the shape once, what is still open, what the tests
prove, and the checks: each command with its pass line and main's output.
On approval the rules and the gate freeze, and the IC writes the
appendix and the plan and keeps going; there is no second hold. The
owner's words: "design specs are too huge to decipher". The IC owns
the how; one review at STOP 1, and lead-1 audits the record after the
push; the rules are written for a decision model.

**Core principle:** screen one is the lines from the title line to the
`---` fold. It holds under 45 content lines: blank lines, headings,
fence lines and table header and `|---|` rows are not counted, and
neither are the rows of the Terms table (a lookup, five rows at most)
or the Checks table (the commands gate.md is frozen from). A spec at 45 or more comes back with the count.
Blank lines are never cut to fit: GitHub needs them to render the file.
Below the fold there is no line cap; each fact appears once with its
source on the same line. One 139 KB spec carried its facts a dozen
times in prose.

This skill replaces the design-doc step of superpowers:brainstorming.
The grill produced the brief; the handoff carries it. A Decided row is
a one-way choice the owner already holds: never re-open it. The card
shape is in
`$FLEET_REPO/shared/skills/foundations/decision-card.md`.

Ids: `ATL-42 D1` is lane `ATL-42` (the ticket key from the handoff)
plus `D1`, numbered in the order the cards appear. Cards the handoff
already carries keep their number. A card id lives on the STOP report
and in the decision record, never in the spec: the spec states the
question in plain words under `## Open`.

## The reader is public

The spec is committed to a product repo. The team, PR reviewers and
anyone with repo access read it on GitHub, as rendered markdown. It is
written for them and never names the fleet. The fleet lines (the
handoff path, the record folder, the count, open cards with their ids,
the reply words) go on the STOP 1 report (`reporting-a-rung`, STOP 1
variant), never in the spec.

## The leak list

The full list is
`$FLEET_REPO/shared/skills/foundations/public-docs.md`.
In short, never in the spec:

- an absolute local path: `~/...`, any home-folder path, `/private/tmp`, `/tmp`
- the record folder or its files: `.fleet-agent-mgmt`, `~/.claude`,
  `checks/`, `handoff.md`, `brief.md`, `decision-record.md`,
  `evidence.md`, `rules.md`, `gate.md`, `close.md`, `receipts/`
- fleet names: `lead-1`, any IC roster name, "the IC", "the fleet",
  "the owner" (write the person's role in the team, such as "the
  product owner", or cite the ticket)
- fleet process words: `STOP n`, "screen one", "spec ok", `Reply:`,
  "handoff", PROFILE, "gate block", jev, band
- fleet ids: `DR<n>`, `UAT<n>`, `E<n>`, a card id such as `ATL-42 D2`.
  The Jira key alone (`ATL-42`) is the team's ticket and is fine.
- skill and AgentMgmt file names: `one-way.md`, `foundations/`, this
  skill's name, `superpowers:...`

Sources cite what the team can open: the Jira ticket, a repo file and
line, an incident id, a dated team channel message, a PR. Never the
brief, the handoff or the record. A hook denies a write to a spec that
carries a leak-list pattern or a render fault, and the push gate scans
the diff for paths and names; they are the backstop, step 4 comes first.

## Render rules

GitHub renders the file, and a plain-text layout breaks there. Lines
with no blank line between them join into one paragraph; a line of text
straight above `---` turns the whole block above it into a heading;
columns indented with spaces lose their alignment. One shipped spec
broke all three ways.

- A blank line between every block: after the title, between
  paragraphs, before and after every heading, list, table and fence,
  and before the `---` fold.
- Section titles are `##` headings, never ALL-CAPS lines.
- Rows of facts (Terms, Rejected, One-way, Decided, Checks) are Markdown
  tables; a `|` inside a cell is written `\|`. Diagrams (Building) and an
  appendix section's labels sit inside ``` fences, so alignment and line
  breaks survive. Prose and lists stay outside fences.
- Every fence opened is closed.

## Steps, in order

1. **Writing rules.** Read
   `$FLEET_REPO/shared/skills/foundations/writing-rules.md`
   once: tables for attributes, diagrams for flow, source on the same
   line, glossary when the reader may not know the subject, no paragraph
   over five lines. Read `foundations/one-way.md` once: the standing
   one-way list and the shape of a rule line. Read
   `foundations/public-docs.md` once: the leak list and the render rules.
2. **Style.** When the handoff names a document the owner has vetted,
   match its voice, never its length. The spec carries no `style:`,
   `source:` or `record:` line: the handoff path and time and the
   records folder go on the STOP 1 report, where the decision record
   and evidence are found (`recording-a-decision`).
3. **Screen one**, `templates/design-spec.md`, in this order, a blank
   line between every block:
   - title line `# <ticket key>: <title>`; no project, no IC name, no date
   - `**Problem:**` one paragraph in plain words, the failure as the user
     sees it, its source (ticket, incident, file) beside it
   - `**Verdict:**` one paragraph: `buildable as drawn`, or `blocked on`
     the open question in plain words
   - `## Terms`, a table `| name | what it is |`: one row per thing the
     spec is about, five at most: the name, what it is, the ticket's
     word when it differs.
     Every section after it uses the name as written (One name per
     thing, below).
   - `## Direction`, prose: the how in one or two lines, then `because`
     with the facts from the ticket or the code, sources beside them.
     This is the IC's proposal, not the brief restated.
   - `## Rejected`, a table `| do not come back to | source |`: one row
     per path the IC or the brief turned down. The `source` cell holds
     the source the team can open and the reason after it
     (`INC-118, 2026-08-29: would have looped 14 hours`); a row with no
     reason is re-argued by the next reader.
   - `## Subtleties`, a list: what someone outside the lane must know to
     describe this work correctly (a timing, a limit, a thing that looks
     like X and is not). The owner carries these to the wider company; a
     line here is true at close or amended with a date.
   - `## One-way`, a table `| stop and ask before | source |`: one row
     per line of the handoff's `one-way` block (§2), none dropped. That
     block holds the brief's one-way acts and the project's own acts,
     one act per line. Write each in the team's words, with a source the
     team can open: the ticket, or the repo file that states the rule.
     Never cite the brief, the handoff or the project's fleet file. Add
     a row for each act the design itself makes one-way. A line the
     handoff carries and the spec drops never reaches rules.md, so the
     decision check never asks about it. The standing lines are not
     copied and the spec does not name their file; the freeze step
     expands them.
   - `## Decided`, a table `| # | never change | lands in | source |`:
     the handoff's rows, same numbers, the component each lands in and
     `new`, `modify`, `reuse`, and the role of who ruled with a source
     the team can open (the ticket, a dated team message)
   - `## Building`: one diagram in a fence (flow, topology) or one table
     (attributes)
   - `## Open`, a list: the handoff's cards, then the ones the design
     raises, marked `raised by the design`. Each is the question in
     plain words, its options, the recommendation and why, with what
     the code adds. No card id and no reply string: the card itself
     goes on the STOP 1 report as a `card` line, with its id, the plan
     task it blocks and the reply words (`reporting-a-rung`, rule 10).
     Nothing open: one line `none`.
   - `## Checks`, a table `| command | pass | on main |`: the handoff's
     gate outcomes turned into commands, one row each, at least one row
     (`none` is refused here). The on-failure, word and record lines of
     the gate stay with the fleet, not in the spec. The brief and the
     ticket hold outcomes only; the IC writes the commands.
     - `command`: one runnable command, in one code span (a `|` in it is
       written `\|`; a command holding a backtick goes in a double
       backtick span). gate-run.sh runs it as written, with `bash -c`,
       from the worktree root. Commands joined with `&&` or `;` are one
       row and one exit code.
     - `pass`: the exit code as `exit N`, then each output fact as a
       "quoted string", exactly as main's run printed it. A string that
       must not appear is `no "x"`, one string per clause. gate-run
       checks only the exit code and the quoted strings, each as a whole
       token; any other word is never checked. The freeze refuses a pass
       line with words and no quoted string (`exit 0, 0 failed`), curly
       quotes, or an exit code worded another way.
     - Quote what the run printed, never what a runner usually prints.
       The pane passes through the shell output filter (rtk), which
       reshapes test runners; gate-run reads the raw output. A direct
       pytest run prints "N passed" on green and no "0 failed" in both,
       so quote "212 passed", not "0 failed".
     Before STOP 1, run each command once on
     origin/main (a detached worktree at origin/main, never the rung's
     branch) and write each run in evidence.md (`recording-evidence`);
     the `on main` line is that output, with no evidence id. A line red
     on main because the rung has not built it yet says `red, this
     change builds it`. Any other red on main shows on its `on main`
     line and is named on the STOP 1 report; after the freeze lead-1
     may amend that line in gate.md (a pass line set to main's recorded
     output, or a command set to CI's exact form) and tells the owner.
   - `## Tests`, a table: one row per test, `proves` and `does not
     prove` beside it
   - a blank line, then the `---` fold

   Each block heading is spelled exactly as above (`## Terms`, `## One-way`,
   `## Decided`, `## Rejected`, `## Checks`), once, at the `##` level.
   Under it: a blank line, one table, a blank line, the next heading.
   No text between the heading and the table, no second table, no row
   after a blank line. A block with nothing in it is one row whose only
   filled cell is `none` (`| none | |`), never a header alone or a
   dropped heading; every block is required, and Checks is never `none`. Cells hold no `[standing]` or `[retired` tag, and no
   source cell reads `standing`: the freeze and lead-1's amendments
   write those. The freeze reads only this shape and refuses anything
   else, and a hook runs that check at every spec write (step 4).

   The three rule blocks (One-way, Decided, Rejected) are plain one-line
   rules: one act or one fact per row, no "unless", no "normally", the
   source in its own `source` cell. A decision model reads each line as a
   yes/no question; a line a reader has to interpret is a line it gets
   wrong. One-way lines start with a verb ("apply, or
   ask Platform to apply", not "any run against the shared database"):
   the check asks "Is the agent about to <line>?". "Spend money" is not
   a line; name the act that keeps billing after the command returns.
4. **Read it as GitHub renders it, then STOP 1, screen one only.**
   Before the commit, on the spec file:
   - render faults and the leak list:
     `python3 $FLEET_REPO/shared/hooks/leak_check.py --doc <spec>`
     prints nothing. It is the check the hook runs: text above `---`, a
     fence left open (both read fence by fence, so a `---` inside a fence
     is fine), every leak-list pattern, roster names included.
   - the rest of the leak list, the words the hook does not check:
     `grep -niE '/tmp|\.claude|the owner|the fleet|handoff|profile|gate block|\bjev\b|(rules|gate|brief|close|one-way)\.md|receipts/|foundations/|superpowers:' <spec>`
     prints nothing, or only lines you have read and kept on purpose
     (a product word such as a user profile).
   - count (step 9): `awk '$0=="---"{exit} /^```/{f=!f; next} f{ if(/^[[:space:]]*$/ || s=="## Terms" || s=="## Checks") next; n++; next} /^#/{s=$0; t=0; next} /^[[:space:]]*$/{t=0; next} /^\|/{ if(s=="## Terms" || s=="## Checks" || !t++ || /^\|[-:| ]+\|?$/) next } {n++} END{print n+0}' <spec>`
     prints under 45.
   - the freeze's own reading:
     `python3 $FLEET_REPO/shared/records/freeze_rules.py --check <spec>`
     exits 0. Exit 2 prints one reason per line: a block missing, a
     heading spelled another way, text between a heading and its table,
     a row it would drop, a pass line it cannot check.
   - the One-way rows against the handoff's `one-way` block: every
     handoff line has a row.
   - read the file top to bottom as GitHub shows it: each block apart
     from its neighbours, each section a `##` heading, each rule block
     a table, each diagram inside a fence, the template's comment deleted.
   A hook runs the freeze's own check at every write of a spec file:
   a write the freeze could not read as written (a block missing, a
   heading spelled another way, a row it would drop) is denied with the
   reasons. Then commit the spec on the rung's branch and write the STOP 1 report
   (`reporting-a-rung`, STOP 1 variant) with the lines the spec does
   not carry: `spec` (`<repo path> @ <sha>`, the commit the owner
   reviews, nothing after the sha), the count on the spec row, `record`,
   `source`
   (the handoff path and time), one `card` line per open item (its id,
   the question, the plan task it blocks, the options, the
   recommendation and its reply words), and the
   reply words "<lane> spec ok" and "<lane> spec back: <line>". End the
   turn. The owner reads screen one at that path and replies with one
   of the two. The appendix is not written yet; nothing below the fold
   is in front of the owner. A hook refuses the STOP 1 send when the
   spec at that sha would not freeze, when an `on main` cell is a
   placeholder, or when evidence.md has no entry for a Checks command
   run at origin/main.
5. **Freeze, on "spec ok".** Run `shared/records/freeze-rules.sh <spec path>
   <record folder> --approved <sha>` from the worktree, the folder from
   the handoff (the spec no longer names it) and the sha from the STOP 1
   report's spec line. `--approved` is required for every spec, and
   the sha must be the newest STOP 1 for this spec in the record
   folder's `stop1.log` (the message gate writes that line when STOP 1
   passes and is sent to lead-1). It also needs the owner's "<lane>
   r<n> spec ok" (or "<lane> spec ok") typed by the owner in this pane
   or lead-1's after that STOP 1; it reads Claude Code's session logs
   for it, and a message relayed by lead-1 does not count. When it is
   not found, hold and ask the owner; never relay, write or forge it.
   It refuses when screen one at HEAD differs from
   screen one at that sha: an edit above the fold goes back to the
   owner. Edits below the fold are free. It writes `rules.md` in the records folder from
   the committed spec: the header `rules · <lane> r<n> · frozen at
   <sha> · <date time>`, Terms, the standing list from
   `foundations/one-way.md` verbatim, then screen one's One-way, Decided
   and Rejected blocks, row for row, under rules.md's TERMS, ONE-WAY,
   DECIDED and REJECTED headings; and it sets `rules: <sha>` in
   the decision record header. In the same step it writes `gate.md`
   beside it: the header `gate · <lane> r<n> · frozen at <sha> · <date
   time>`, then the Checks block without its `on main` lines, in the
   labels `shared/records/gate-run.sh` runs. Each block is read as a table or,
   as written before tables, a fence. A table row becomes one rules.md
   line: each cell's spaces collapsed to one, the `#` cell first, then
   the rule, the other cells, and the `source` cell in brackets. A spec
   in the old shape (ALL-CAPS block lines, no fences) still freezes. It
   refuses an uncommitted spec, a spec with no `--approved`, an
   `--approved` sha that is not the newest STOP 1 in `stop1.log`, no
   owner's spec ok typed after it,
   anything step 3's shape rules or `--check` refuse, an existing
   rules.md, gate.md or frozen.sha256, and a gate.md it did not write.
   Every reason is printed and nothing is written. Last it writes `frozen.sha256` beside them: the spec's
   repo path, the approved sha, and the sha256 of rules.md and gate.md.
   gate-run, the decision-record check, the STOP gate and the push
   refuse once a file no longer matches it; at "ready for push" and at
   the push the spec at HEAD must still match the frozen rows, and
   screen one must read as it did at the approved sha. The
   decision-record check reads the spec in the worktree the same way:
   a rule changed in the spec, on disk or committed, stops the check.
   rules.md and gate.md must chain back to the approved spec through
   the history lines in frozen.sha256. From
   here the rules do not move, and the IC never writes rules.md,
   gate.md, frozen.sha256 or stop1.log (a hook denies it, through
   Bash too). A change is a card to
   lead-1; once the owner has ruled it and typed "<lane> r<n> amend ok
   <card id>" in lead-1's pane or yours (a relayed message does not
   count; `shared/amend-frozen.sh` reads it from the session logs and
   refuses without it), lead-1 appends a dated amendment row under its
   own heading, tags the row it replaces `[retired <date> by <line>]`,
   and re-hashes with `shared/amend-frozen.sh`, citing the card id in
   the reason. A gate line that cannot pass on origin/main is lead-1's
   to amend in gate.md, the same way, under a dated `# Amended` header
   line, with no word from the owner while it changes a pass line or a
   command that exists; a new Checks line, or any other gate change, is
   a card to the owner and takes the same typed word.
6. **Appendix**, after approval, below the `---` fold: one `##` section
   per component named in Building, its labels in a fence: `contract`
   (signature, inputs, outputs), `data` (shapes, migrations, config),
   `errors`, `failure` drawn when there is a fork, `must not` (what it
   reuses and what it must not touch), `source` (the ticket, file and
   line). Then `## Risks and watch` as a table, `## Glossary` for
   subject terms a reader outside the lane may not know (a thing in
   Terms does not repeat there), `## More information` always, citing
   what the team can open. lead-1 reads the appendix only when a
   decision record entry or the audit after the push points at it.
7. **Settle the handoff's unknowns** inside the component that owns
   each, citing the line that settled it. An unknown the code cannot
   settle becomes a card on the next STOP report.
8. **Amendments**, `## Amendments`, last section, always present, `none`
   when empty. The heading is spelled exactly so, and every line under
   it starts with its date (`2026-10-20 ...`); a hook refuses any other
   line there. A new fact after approval is one dated line citing what
   the team can open (the ticket, a repo file, a PR, a dated team
   message). A change to Direction or to screen one's prose is such a
   line under `## Amendments`, dated, and nothing else: the spec's screen
   one stays as the owner approved it (the freeze compares it line for
   line), and a rule or Checks row that changes is the card and the
   typed amend ok above, not a rewrite of the spec. The fleet link goes in the decision record: one entry
   naming the amendment line by its date and first words, the card or
   STOP report that raised it, and the owner's word when a rule changed
   (`recording-a-decision`). The body is never rewritten for it.
9. **Count.** On the STOP 1 report's first row, the spec commit, never
   in the spec and never on the `spec` line (the STOP gate reads that
   line as `<repo path> @ <sha>` and nothing more):
   `N content lines + Terms t + Checks c`: N by the rule above, Terms
   and Checks not counted, t the number of terms, c the number of
   commands. At 45 or more: move to the appendix, never compress the
   rows, never cut blank lines.
10. **Plan, no hold.** Invoke superpowers:writing-plans from the
    appendix; its task lines name things as Terms does. The plan is
    committed to the product repo too, so the leak list and the render
    rules hold for it. Its own Self-Review stays. Write the plan path on
    the `plan:` line of the decision record header and continue into the
    build. The plan is the IC's; lead-1 reads it only when the audit
    after the push points at it.

## One name per thing

A thing is named once, in Terms, and every section after it uses that
name as written: the rule lines, Building, Tests, the plan's task lines
and the `decided` line of the decision record. The ticket's word for it
sits on the Terms line, once. A reader then meets one name per thing,
whether they open the spec, the plan or the record.

```
  Terms says        ✗ elsewhere in the spec                ✓ elsewhere in the spec
  nightly()         re-run the import by hand              start nightly() by hand
  import_runs       a counter on the runs table            a column on import_runs
  ops alert         a message to the channel per attempt   one ops alert per attempt
```

Decided rows keep the ruler's words. The component cell carries the
Terms name, and that cell is where a row is looked up.

Terms holds names: the name, what it is, the ticket's word when it
differs. Five lines at most. A line with a decision, a rule or a reason
in it belongs in another block.

## Red flags, stop and fix

- Screen one at 45 content lines or more, or no `---` fold.
- Blank lines cut to fit the cap.
- A leak-list item in the spec: a local path, a `$FLEET_HOME`
  record path, a record file name, a fleet name, a fleet word, a card,
  DR or evidence id.
- A `style:`, `source:`, `record:` or `Reply:` line, or the count line,
  in the spec.
- A line of text straight above `---`, an ALL-CAPS section line, a
  rule block that is not a table, or a fence left open.
- A block heading spelled another way, text between a block heading
  and its table, a second table under one heading, or an empty block
  with no `none` row: the freeze refuses each one.
- A thing with two names: one in Terms, another in a rule line,
  Building, a plan task or a `decided` line.
- A Terms line carrying a decision, a rule or a reason, or a sixth line.
- A Decided row re-argued, renumbered, or dropped.
- A rule line with "unless", "normally", "where possible", or two acts.
- A standing one-way line reworded or dropped from `rules.md`.
- `rules.md` written by hand instead of by `shared/records/freeze-rules.sh`; the
  one exception is lead-1's dated amendment row after a card, the
  `[retired <date> by <line>]` tag on the row it replaces, and the
  re-hash with `shared/amend-frozen.sh`.
- Direction that restates the brief and names no mechanism.
- A Subtleties line that is an implementation detail nobody outside the
  lane would ever repeat.
- A component in Building with no appendix section, or a section with
  no `contract` and no `source`.
- An open item as bold prose with no options, or a bullet list of "not
  settled" items.
- An open item with no `card` line on the STOP 1 report.
- A test row without "does not prove".
- A Checks line with no `on main` output, or a command copied from the
  brief or the ticket and never run on origin/main.
- A pass line with words and no "quoted string" (`exit 0, 0 failed`):
  gate-run checks the exit code alone and the words never.
- A pass string retyped from what a runner usually prints instead of
  copied from main's run.
- A line of the handoff's `one-way` block with no One-way row.
- `gate.md` written by hand instead of by `shared/records/freeze-rules.sh`, or
  copied in from another rung; the one exception is lead-1's dated
  `# Amended` line for a gate line that cannot pass on origin/main,
  re-hashed with `shared/amend-frozen.sh`.
- A screen-one edit after STOP 1 with no new STOP 1: the freeze refuses
  it against the approved sha.
- A Checks `on main` cell left `-`, TODO or empty at STOP 1.
- A measurement (rows, seconds, counts) without its command and output
  beside it. No command: mark it `unmeasured`.
- A fact stated in two sections. Cut one, point at the other.
- A paragraph of architecture prose where a diagram or a contract line
  would do: that is superpowers:brainstorming's design doc coming back.
- A gotcha patched into the body instead of a dated amendment.
- The appendix or the plan sent to the owner for a second approval.

| Excuse | Reality |
|---|---|
| "The reader needs the whole flow to approve" | The reader needs the shape once. Every branch is a component section, written after the yes. |
| "This open item is obvious, no card needed" | Then it is a Decided row with a ruler. If nobody ruled, it is a card. |
| "The handoff's ruling is wrong now that I see the code" | Raise a card, `raised by the design`. Never overwrite the row. |
| "The rule is clear enough with the caveat" | A caveat is a second question the model was not asked. One act per line, the caveat is its own line or it is not a rule. |
| "Longer is safer, the plan needs detail" | The plan needs contracts and tests, each once. Prose twice is where 139 KB came from. |
| "I'll fold the new fact into the section where it belongs" | Then the approver re-reads the section. A dated line at the end is read once. |
| "The plan shape should be checked before I build" | The plan is yours. lead-1's audit after the push reads what it produced. |
| "The ticket already has the gate commands" | The ticket holds outcomes. The commands are yours, run once on origin/main, and frozen at "spec ok". |
| "`exit 0, all rows loaded` says what passes" | gate-run reads `exit 0` and nothing else on that line. Quote the fact as main's run printed it: `exit 0, "loaded 3412 rows"`. |
| "The project's one-way acts are standard, the freeze adds them" | The freeze adds only the standing list. A project act not in a One-way row is never asked about. |
| "I'm two lines over, I'll drop a few blank lines" | Blank lines are not counted. Without them GitHub joins lines into one paragraph and makes the block above `---` a heading, as one shipped spec did. Move a line to the appendix. |
| "The record path helps the reviewer find the evidence" | The reader is the team on GitHub. A `$FLEET_HOME` path is a folder on one machine and names the fleet; one shipped spec carried one. It goes on the STOP 1 report; the spec cites the ticket or a repo file. |
