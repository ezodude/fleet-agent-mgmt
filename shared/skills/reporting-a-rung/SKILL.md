---
name: reporting-a-rung
description: Use when a fleet IC (AgentMgmt Lead and ICs) reaches a STOP and writes its report, including STOP 2 "ready for push", a report sent before the IC pushes; when lead-1 runs the audit after the push; and when lead-1 writes any message to the owner that carries IC state, a fleet status, a rollup or a digest. Both sides of the same report.
---

# Reporting a rung

## Overview

One report shape, two writers. The IC writes a STOP report against its gate
block. lead-1 recaps every IC into one fixed box at the top of every message
to the owner, then writes the body verdict-first. The owner reads the box, opens only
the red line.

**Core principle:** a gate is red when its output does not match its pass
line. Nobody's reasoning turns it green. Only the owner re-writes a pass
line, or lead-1 sets it to what origin/main prints (a line main cannot pass).

**REQUIRED BACKGROUND:** `foundations/gate-block.md`,
`foundations/decision-card.md`, `foundations/grove-monitoring.md`,
`foundations/artifact-caps.md`, `foundations/one-way.md`,
`recording-a-decision` (the entries the review reads).

## The rung's STOPs

```
  STOP 1   the spec's screen one                      hold: the owner reviews direction
  (build)  autonomous: no STOP; a ONE-WAY line is an ask in the pane, quoting the rules.md line
  STOP 2   "ready for push", at a green receipt       no hold: a report; the IC pushes its branch and opens a draft PR
  (after)  lead-1's audit of the record               rework in the IC's pane; the band recorded at the close
  per-task STOPs only when the handoff's MODE line says so (band 3+)
```

## IC side: the STOP report

Fill `templates/stop-report.md`. Rules the template cannot enforce:

1. **One row per step, glyph first, expected beside actual.** ✔ ✖ ● ○,
   step, time, actual output, then "= pass" or "≠ pass <line>". Not
   "passed". No separate todo block and gates section: the rows are both.
2. **A gate is red on any mismatch.** Exit 1 is red. "2 failed" against
   "0 failed" is red. A red gate's step is NOT ticked. Report the failing
   line. A fix inside the worktree (code, tests, local cache, local
   tools): fix and re-run without the owner's word, one DR per re-run
   (what was red, the fix, the receipt), at most 2 re-runs per line. A
   third red on the same line: stop, report it, it goes to the owner as
   a card via lead-1. A fix or re-run that touches anything
   outside the worktree: stop, ask, unless the rung's sandbox scope
   covers it.
3. **Relevance is not the IC's call.** "The failures are in a scenario this
   rung does not deploy" goes on the `unverified` line, and the step stays
   unticked. lead-1 carries it up; the owner rules.
4. **Options with cost, never a pick.** Two to four lines, each an action
   the IC could take next and what it costs or needs. No "recommended", no
   "I will". The recommendation is lead-1's, on the card.
5. **The message is the template, 30 lines at most.** Header, rows,
   stakes, options, unverified, files; at STOP 1 the four lines of
   rule 10 as well. Everything else (traces, diffs, reasoning,
   the one-job walkthrough) goes in the report file named on the `files`
   line, and the haiku check reads that file; lead-1 never does. A hook
   denies a longer STOP message before it sends. Same for updates and
   answers under the lane header: the file carries the body, the message
   carries the answer.
6. **Unverified is not optional.** Anything the report rests on that no
   output proves goes there, one line each. An empty line reads "none".
7. **Stakes, one line.** What the decision touches: demo, client, regulated
   control, money, prod, or "none beyond the rung". Wording from the
   handoff's gate block.
8. **Save, then send.** Write the message to
   `$FLEET_HOME/checks/<ic>/stop-<n>.md`, name that path on the `files` line,
   then send the same text. lead-1's check reads the file, not the message.
9. **Every STOP after STOP 1 is preceded by `shared/records/gate-run.sh`.** It
   runs the commands frozen in `<record>/gate.md` as written and writes a
   receipt under the record folder's `receipts/`, naming the sha256 of the
   gate.md it ran; the `files` line names the newest receipt. A hook
   refuses a STOP or "ready for push" message with no receipt newer than
   HEAD, with a ✔ row over a red receipt line, or when rules.md or
   gate.md no longer matches `<record>/frozen.sha256`. Red reported as
   red passes. STOP 1 comes before the freeze and has no receipt.
10. **STOP 1 carries the lines the spec does not.** The spec is a public
   repo doc (`foundations/public-docs.md`): no fleet line goes in it.
   The STOP 1 report carries them, `templates/stop-report.md`, STOP 1
   variant: `spec` the repo path at the commit (`<repo path> @ <sha>`,
   nothing after the sha), `source` the handoff path and its time,
   `record` the record folder, one `card` line per open item of the
   spec, and `reply` the two strings "<lane> spec ok" and "<lane> spec
   back: <line>". A `card` line is the card id (`ATL-42 D1`), the
   question in words, the plan task it blocks, the options a) and b),
   the recommendation with its reason, and its own reply words
   ("ATL-42 D1 b"); the spec states the question with no id. No open
   item: no card line. The `reply` line stands for options; add an
   `options` line only for a choice beyond the two strings, and `new
   fact` or `word` only when there is one. Rows: the spec commit with
   the count, `N content lines + Terms t + Checks c`
   (`writing-a-design-spec` step 9), then each Checks command's run on
   origin/main with its E id. The spec's One-way rows cover every line
   of the handoff's `one-way` block; a line with no row is named on
   the report. A hook
   reads the spec line, `<repo path> @ <sha>`, and refuses the send when
   the spec at that sha would not freeze, when an `on main` cell is a
   placeholder, or when evidence.md has no entry for a Checks command run
   at origin/main (`recording-evidence`). The sha is the commit the owner
   reviews; the freeze takes it as `--approved`.
11. **STOP 2 is "ready for push", a report, not a hold**,
   `templates/ready-for-push.md`, sent at a green receipt at HEAD: the
   header carries the words `ready for push`; the rows are one per gate
   from the receipt, one per TESTS row of the spec with its E id, and
   one line each for DRs, UAT entries and SUBTLETIES counts. The `files`
   line names `evidence.md`, `decision-record.md` and the receipt. A
   hook refuses it unless the jev audit on the decision record exits 0.
   Then, without waiting, the IC pushes and opens a draft PR, only when
   all hold:
   - the newest receipt is at HEAD with 0 red lines, or each red line
     overridden by the owner: "<lane> r<n> override <checks>: <reason>"
     typed in the IC's pane (a relay never counts), and a DR whose
     `owner` line quotes it; the receipt stays red and the close lists it;
   - the jev audit on the decision record exits 0;
   - the branch is the rung's own feature branch, named in the handoff;
     never main, master or the repo's default branch, never a branch
     another person has pushed to;
   - a plain push: never `--force`, `-f`, `--force-with-lease` or a
     `+refspec`;
   - the PR is a draft (`gh pr create --draft`), body from the spec
     summary.
   One DR for the push, one for the PR, each naming the receipt; no
   `owner` line needed. The owner's word, always: marking the PR ready,
   merging, closing, a PR body or comment after ready, any other push,
   any deploy outside the sandbox scope, and shared writes. The IC
   never merges. `push-gate.sh` enforces the push and PR conditions.

## Lead side: the audit after the push

After the IC's push and draft PR, an audit of the record; the IC does not
wait for it. lead-1 reads four things and never the diff:

```
  1  decision-record.md   every DR: write its `review` line    ok | rework: crossed a line | rework: claim false | rework: better path found
                          every UAT entry: count them; they are the owner's own words, never re-asked
                          a ONE-WAY act with no `owner` line: the owner's card, always, whatever else is green
                          the push and draft PR DRs need no `owner` line: each names a green receipt at HEAD
  2  the receipt          through the haiku check: every gate line green, or red named
  3  the spec's TESTS     each row's E id from the STOP 2 report (the spec carries none) in evidence.md,
                          the output quoted: proven | unproven
  4  SUBTLETIES           each line still true, or amended with a date
```

Then the band, from the rework items (DRs marked rework + gates red +
TESTS unproven), counting only `crossed a line` and `claim false`;
`better path found` is noted and reworked, never counted:

```
  0        next rung on this project: same mode
  1 to 2   rework now, same mode
  3+, or any one-way act without the word   rework now; the next rung on this project at per-task STOPs until one clean rung
  cap      two rework rounds; the third brings the rung to the owner as a card
```

The band is recorded at the close (close.md NUMBERS) and sets the next
rung's mode.

`jev` reworks the IC superseded before acting are a separate count on
the `rework` line (`jev n superseded before the act`): visible, never in
the band; three or more in one rung is a pattern for the project's
profile. An entry whose `jev` line clears a
`decided-` or `rejected-` key with the owner's word is the owner changing
a rule: tag it `DRn ok · owner changed DECIDED 4` on the `decisions`
line, never rework, and the close's CHANGED table carries it.

lead-1 writes the `REVIEW` entry and the DR `review` lines in the record
(`recording-a-decision`), orders two-way rework in the IC's pane (one
message, the DR ids and the reason each; new commits on the same branch,
the draft PR updates), and puts `templates/review-block.md` under the
recap rows in the next message to the owner. Marking the PR ready and
merging are the owner's word in the IC's pane; lead-1 never gives them.

## Lead side: a gate line that cannot pass on main

When a gate line cannot pass on origin/main as written, lead-1 amends
`<record>/gate.md` and tells the owner in a report, not a card. An IC
never writes gate.md, rules.md or frozen.sha256; a hook denies it.
It arises at STOP 1 (the IC's main run shows the line red on main) or at
any later STOP (a receipt is red on a line that also fails on
origin/main). Two kinds only:

```
  a   a pass line, set to main's recorded output
  b   a command that cannot start, set to CI's exact form, citing the CI file and line
```

Guard: the main run goes into evidence.md first; never remove a line;
never loosen beyond what main prints. The steps:

```
  1  cp <record>/gate.md <record>/gate-pre-<stamp>.md      the frozen text, before the edit
  2  edit gate.md: one line above GATE BLOCK
     # Amended <date time> by lead-1 (C3): <line n>, <kind a|b>, <source>
  3  shared/amend-frozen.sh <record> gate "<the reason>"   checks the edit against the copy,
                                                           re-hashes, appends a history line
```

Until step 3 passes, gate.md differs from frozen.sha256 and gate-run,
the STOP gate and the push refuse. The IC runs gate-run again after the
amendment: a receipt names the gate.md it ran. A rules.md amendment
follows the same steps with `rules-pre-<stamp>.md` and `rules`: earlier
lines stay, the old row gains `[retired <date> by <line>]`, and the new
row is appended under a `<KIND>  amended <date>:` heading.
The check reads the amendment at the next STOP. Anything else (a pass
line main cannot meet for a real reason, a line to drop) is the owner's
card.

A new Checks line (a proves done line added), and any rules.md change,
is a card too, and `shared/amend-frozen.sh` refuses it until the owner
has typed the word. After the owner's ruling on the card, the owner
types, in lead-1's pane or the IC's:

```
  <lane> r<n> amend ok <card id>        ATL-42 r1 amend ok ATL-42 D4
```

Lead-1 then amends and cites the same card id in the reason
(`shared/amend-frozen.sh <record> rules "card ATL-42 D4: ..."`). The
script reads the word from Claude Code's session logs: a line typed by
a person (a message lead-1 relays does not count), after the record's
last amendment, naming this lane and rung, with the card id also in the
reason, so one word covers one edit. No word, or a different card id:
refused; hold and ask the owner, never relay or type it. A changed pass
line (kind a) or command (kind b), with no added line, needs no word.

## Lead side: the recap box and the body

On every STOP report, in this order, before any message to the owner:

1. Fill `templates/check-prompt.md`: report path, evidence path the report
   names, the rung's `<record>/gate.md` path, the receipt path, time received.
   At STOP 1, before the freeze, there is no gate.md and no receipt: save
   the spec at the spec line's sha (`git -C <worktree> show
   <sha>:<repo path> > <scratchpad file>`) and give that file and the
   rung's handoff.md instead. The check's `one-way` line names each
   handoff one-way act with no spec row; each one is a `spec back`.
2. Dispatch it with the Agent tool, model haiku. Wait for the check block.
3. Write the rows and the card. The card's `happened` field opens with the
   check header verbatim: `check · atlas-ic · ATL-42 r1 · STOP 3 ·
   received 16:40`. A card without that header was written without a
   check.
4. The card's trace is the check's `gate`, `unverified` and `failing`
   lines, copied.

Fill `templates/recap-box.md` at the top of every message that carries
IC state. Rules:

1. **One row per IC, glyph first:** ✖ failed gate, ? waiting on the owner
   (its STATE `awaiting:` line opens `owner:`), ● working, ○ down. Then ic, project and rung in words, state, what it
   needs from the owner, age. Red rows first. Never a prose tree, never a
   bordered box.
2. **A ticked step over a red gate is a ✖ row** and the card says
   "ticked anyway". The IC's reasoning never turns the row green; only
   the owner rewriting the pass line does, or lead-1's amendment to
   main's output.
3. **Order: red gates first, then awaiting the owner (`owner:`), then
   awaiting lead-1 (`lead-1:`), then working.** Grove: the exception is read first.
4. **The held line** states how many IC messages arrived while a grill was
   open and their age. Nothing that arrived during the grill is relayed
   before this box.
5. **Check before card.** Steps 1 to 4 above. lead-1 does not open the
   evidence file itself unless the check says "cannot read".
6. **Verdict, one sentence. Then ONE full decision card** in the
   `foundations/decision-card.md` shape, the ✖ row's if there is one. At
   most one two-line card behind it naming when it comes. Rows that need
   nothing get no card. A red gate is never "mine to clear": the card's
   options are the owner's, with a recommendation.
7. **Trace at the bottom of the same message**, under the card's id, only
   when the stakes line warrants it. Under fifteen lines.
8. **Cap:** rows plus verdict plus one card under 30 lines, trace excluded.

## Red flags, stop and fix

- A failed run described as "unrelated", "legacy", "out of scope",
  "flaky" by anyone other than the owner in a written verdict.
- Two options on one line, or options as prose.
- A trace in another file, or "see the evidence log".
- A STOP report with a tick and no quoted output beside it.
- A STOP message over 30 lines, or a trace pasted into the message instead of the file.
- A STOP 1 report with no `spec`, `source`, `record` or `reply` line, or
  one of those lines written into the spec instead.
- An open item in the spec with no `card` line on the STOP 1 report, or
  a card line with no plan task it blocks or no reply words.
- A STOP 1 count with no Terms or Checks part, or the count written on
  the `spec` line.
- A card whose `happened` does not open with a check header.
- lead-1 reading the diff, or a review verdict that cites a line of code.
- A `review` line written by anyone but lead-1; a REVIEW entry with a
  reason other than the two that count and the one that does not.
- A UAT entry relayed to the owner as news, or re-asked as a card.
- An audit that passes a ONE-WAY act with no `owner` line.
- A push or draft PR with no green receipt at HEAD, to a branch that is
  not the rung's own, or forced.
- A third re-run of the same red line, or a re-run outside the worktree
  without the word.
- A gate.md amendment with no main run in evidence.md, a line removed,
  or a pass line looser than main prints.
- An IC holding after "ready for push" for a review.
- The red item deferred to "next message" because an older ask is waiting.
- The rows redrawn as a tree, a paragraph, a bordered box, or per-project sections.

| Excuse | Reality |
|---|---|
| "The failures are in a job this rung does not deploy" | Then the pass line is wrong, and only the owner rewrites it, unless origin/main prints the same red (lead-1's amendment). Until then, red. |
| "The IC's reasoning is sound, I'll clear it" | lead-1 never clears a gate on reasoning; its one amendment is to what main prints, from a main run. One rung's failed run was cleared this way. |
| "One more re-run will turn it green" | Two re-runs per line. The third red is the owner's card. |
| "The audit will catch it, push now" | The push needs a green receipt at HEAD and a jev audit at 0. The audit reads the record; it does not replace the gate. |
| "The owner has been waiting on D1 longer" | Age orders asks. Red orders everything. Red first, D1 second. |
| "The owner asked what the fleet is doing, not for a box" | The rows are the answer. The card is the one thing they must act on. |
| "I can read the evidence file faster than dispatching a check" | Fable reading three exit codes is the cost the retro named. Haiku reads them; lead-1 writes the card. |
| "lead-1 needs the full trace to judge" | lead-1 never reads the trace; haiku does, from the file. Every line in the message is a line in Fable's context on five lanes. |
| "The options fit on one line" | They fit today. One per line, always, so the shape never changes. |
| "The DR is wrong but the code is fine, skip the rework" | A wrong record is a false audit. The entry is superseded or the code moves; the record says which. |
| "Band 3 is harsh for one rung" | One moving lever, so the cause is readable. Per-task STOPs end at the first clean rung. |

## Example

The three templates carry an invented fleet filled in: one red gate, one owner
ask, one working, one down, and a trace. Copy the shape, replace every value.
