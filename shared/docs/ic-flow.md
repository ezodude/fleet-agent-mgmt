# How an IC rung works

One rung of work, from the lead's handoff to the IC's close, and the
checks that run between. Read this before extending a skill or hook,
and when a rung stops somewhere you did not expect.

```
  1. HANDOFF        lead-1 writes $FLEET_HOME/records/<project>/<lane>-r<n>/handoff.md; §0 holds the gate block (outcomes) and the MODE line
     │
     ▼
  2. SPEC, STOP 1   the IC runs each gate line once on origin/main, writes the design spec with the exact commands, sends STOP 1, holds
     │                "spec ok" ──▶ the IC runs freeze-rules.sh --approved <sha>, which finds the owner's spec ok in the session logs and writes rules.md, gate.md and frozen.sha256 into the record folder
     ▼
  3. BUILD          the IC codes. Before any act the plan left open: a decision record entry
     │                dr-check.sh asks Jev: continue · continue, read · stop and ask · rework
     ▼
  4. READY, STOP 2  gate-run.sh writes a receipt; at a green receipt at HEAD the IC sends STOP 2 "ready for push", a report, no hold
     │                push-gate.sh: receipt at HEAD 0 red, jev audit exit 0, own branch, plain push ──▶ the IC pushes and opens a draft PR, one DR each
     ▼
  5. AUDIT, CLOSE   lead-1 audits the record after the push: the record, the receipt, TESTS, SUBTLETIES, never the diff; rework as new commits on the same branch
                    marking the PR ready and merging are the owner's word; close.md carries the band in NUMBERS (0 same mode · 1-2 rework · 3+ next rung at per-task STOPs)
                    lead-1 commits the record folder at the ticket end, however the ticket ends
```

Sections 1 to 5 below follow these steps. Section 6 is where to look
when a rung stops; section 7 is what this guide proves.

## Why the flow looks like this

The flow is one framework applied to agents: a small, fast team solving
new problems, where rework is expensive, so autonomy must come with
guardrails rather than gates. The framework is kept beside this file as
fast-but-small.md. Each of its five principles lands in one place in the
flow, and that place is the reason the piece exists.

| PRINCIPLE                                     | WHY IT MATTERS HERE                                                                  | HOW THE FLOW DOES IT                                                                                                                                             |
|-----------------------------------------------|--------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 guardrails, not gates                       | a STOP per task is a gate: the lead becomes the bottleneck and the IC learns to wait | rules.md: ONE-WAY needs the word; everything two-way is the IC's, with a DR and a one-line undo (Tree 1 of foundations/rung-flow.md). Jev reads the line, not the lead |
| 1 automate the quality bar                    | a human reading output is slow and biased                                            | gate-run.sh: the pass line is declared before the run; the receipt is the fact                                                                                   |
| 1 a lightweight RFC for new thinking          | the wrong shape is cheapest to fix before code                                       | the design spec at STOP 1; "spec ok" freezes it into rules.md and the gate commands into gate.md                                                                 |
| 2 a shared Definition of Done                 | without one each IC invents its own "good"                                           | foundations/definition-of-done.md, pasted into every ticket; the close is measured against it                                                                    |
| 3 review the architecture, not the PR         | a PR review is too late; that is where rework is                                     | STOP 1 at the spec is the 10 percent mark; after the push lead-1 audits the record, the receipt, TESTS and SUBTLETIES, never the diff                            |
| 4 give the why and the what, delegate the how | a task without context gets a fragile solution                                       | the handoff §0: the goal, the gate block and the done-lines are the what; the plan and every two-way choice are the IC's                                         |
| 5 blameless, and accountable                  | fear of rework slows the IC to a stop; no record means nothing is learned            | the band scores the rung, not the IC, and moves one lever (the MODE line); every DR carries its own undo; LEARNED in the close asks which guardrail was missing  |

```
  ✗ a STOP after every task, the lead reads every diff        the lead is the gate; quality is whatever the lead noticed
  ✓ one hold at the spec, an audit after the push             the guardrails are files the checks read; the lead counts, the IC runs
```

Two things the framework asks for that the flow does not carry: a peer
review by another engineer, and observability of the shipped product.
The first is lead-1 and the owner today. The second is a profile line
per project, when the project has one.

## The record folder

Everything the checks read lives in one folder per rung, outside every repo.
The path is written absolute in the skills, the handoff, the ticket and the
STOP 1 report's `record` line, never in the spec (a public repo doc,
foundations/public-docs.md). freeze_rules.py takes it as its second argument
and expands a `~` if one slips in; message-gate.sh does not, so a STOP
message names the folder absolute.

`$FLEET_HOME/records/<project>/<lane>-r<n>/`

| FILE                            | WHAT IT HOLDS                                                                        | WRITTEN BY                            |
|---------------------------------|--------------------------------------------------------------------------------------|---------------------------------------|
| handoff.md                      | the rung's handoff; §0 holds the gate block (outcomes), MODE, BRANCH and SANDBOX; push-gate.sh reads BRANCH | lead-1 |
| gate.md                         | per gate line, the exact command and its pass line from spec screen one, frozen at "spec ok"; a dated `# Amended` header per lead-1 fix | freeze-rules.sh; lead-1 for an amendment |
| rules.md                        | the spec's `## Terms`, the standing ONE-WAY list, then the spec's `## One-way`, `## Decided` and `## Rejected` blocks, frozen at "spec ok" | freeze-rules.sh; lead-1 for an amendment |
| frozen.sha256                   | the spec's repo path, the approved sha, the sha256 of rules.md and gate.md, a history line per amendment | freeze-rules.sh; amend-frozen.sh |
| rules-pre-<stamp>.md, gate-pre-<stamp>.md | the frozen text before an amendment, the copy amend-frozen.sh checks the edit against | lead-1 |
| decision-record.md              | one entry per choice the plan left open, with its jev line                           | the IC; dr-check.sh adds the jev line |
| evidence.md                     | E1, E2, …: quoted command output; the STOP 2 report names the E id beside each spec Tests row (the spec carries none) | the IC |
| receipts/<stamp>-gate.md, .log  | every gate command, its exit and output tail, green or red; the full output beside it | gate-run.sh                          |
| receipts/<stamp>-jev-DR<n>.json | the request as sent, the response, the verdict; also -jev-UAT<n>.json for UAT entries | dr-check.sh                          |
| close.md                        | the close report, the last act on the rung                                           | the IC                                |

The hooks are wired in shared/launch/ic-settings.json. The decision check and the
freeze keep their logic in a .py beside the shell file, each with `--dump`
to print what it would do without doing it. The gate runner is a .py with
no `--dump`; the message, artefact, push and skill gates are shell. The skill gate
reads the turn's text through turn_text.py, which prints it when run on a
transcript by hand.

## 1. The handoff

One file per rung. Screen one (§0) is everything the IC needs cold, and
nothing in it is new: the gate block copied byte for byte from the record's ticket.md (the fleet ticket, not a tracker's text),
the record folder path, the mode, the chain of steps with a skill and a STOP
each. The gate block holds outcomes, never commands: the IC turns each
`proves done` outcome into an exact command on spec screen one.

```
  §0
    GATE BLOCK   proves done <outcome> · pass <line, in outcome words> · on failure · owner's word · record <folder>
    record       $FLEET_HOME/records/<project>/<lane>-r<n>/
    mode         autonomous | per-task STOPs, from <lane> r<n> close
    CHAIN        1. writing-a-design-spec, STOP 1 · 2. build · 3. gate-run, STOP 2, a report · 4. push, draft PR · 5. closing-a-rung
```

The MODE line is the one lever on how much the IC does alone.

| MODE           | STOPS                                        | EVERYTHING BETWEEN                                   | SET WHEN                                                                                                                             |
|----------------|----------------------------------------------|------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| autonomous     | two: STOP 1 holds for "spec ok"; STOP 2 "ready for push" is a report, no hold | the IC's, recorded in decision-record.md, checked by Jev | the default                                                                                                                      |
| per-task STOPs | one after every task in the plan, plus the two; each needs a gate receipt at HEAD (section 4) | the IC's between STOPs; the same record and checks | the last close on this project landed in band 3+, or an act crossed a one-way line without the word; ends at the first clean rung |

- **Build:** `writing-a-rung-handoff`. The skill's last step measures §0 against the cap; no hook enforces it.
- **Read:** artefact-gate.sh refuses a Write to the record folder's handoff.md unless the skill is in force, and any write to an old rung handoff under Leads/lead-1/handoffs/.
- **Done when:** §0 fits screen one, the gate block matches the record's ticket.md byte for byte, the MODE line is set.

## 2. Rules, frozen at "spec ok"

The design spec carries three kinds of rule line. At "spec ok" the IC runs
`freeze-rules.sh <spec path> <record folder> --approved <sha>` from its
worktree, the folder from the handoff and the sha from the STOP 1 report's
spec line. It refuses when screen one at HEAD is not screen one at that sha,
and when the owner's "<lane> r<n> spec ok" (or "<lane> spec ok") typed by a
person in the IC's pane or lead-1's after the newest STOP 1 line in stop1.log is
not in Claude Code's session logs (a relay from lead-1 does not count; stop1.log
gets a line only for a STOP 1 sent to lead-1).
It copies, in this order: a header with the sha of the
commit that holds the spec, the spec's `## Terms` block, the standing
ONE-WAY list from foundations/one-way.md, then the spec's `## One-way`,
`## Decided` and `## Rejected` blocks in the spec's order, under rules.md's
TERMS, ONE-WAY, DECIDED and REJECTED headings. The same step freezes the
spec's `## Checks` commands into gate.md. A spec in the old shape (ALL-CAPS
headings, no fences) still freezes.

The new shape is read strictly, and a spec it refuses freezes nothing:

- each heading exactly `## Terms`, `## One-way`, `## Decided`, `## Rejected`
  or `## Checks`, once, at the left edge; all five required;
- under each heading, one table or one fence and nothing else: no text
  between the heading and the table, no row after a blank line, no second
  table;
- an empty block is one row whose only filled cell is `none`; Checks is
  never `none`;
- no `[standing]` or `[retired` tag and no source cell reading `standing`;
- a Checks pass line is `exit N` and "quoted strings" as main printed them;
  one with words and no quoted string is refused, since gate-run.sh would
  never check those words.

`freeze_rules.py --check <spec>` runs the same reading without writing; the
IC runs it before STOP 1. The freeze also refuses an uncommitted spec, a
new-shape spec with no `--approved`, an existing rules.md, gate.md or
frozen.sha256, and a gate.md it did not write. Every reason is printed.
Last it writes
frozen.sha256: the spec path, the approved sha, and the sha256 of rules.md
and gate.md. From then on every decision entry is checked against rules.md,
never against the spec.

```
  frozen.sha256 is read by             a file that no longer matches it
  gate-run.sh                          exit 2, no receipt
  dr-check.sh                          stop and ask, no check, with a receipt
  message-gate.sh, each STOP after 1   refused; the receipt must name the frozen gate.md's sha256
  message-gate.sh, ready for push      also the spec at HEAD: it freezes, its rows match rules.md and gate.md
  push-gate.sh                         the same as ready for push
```

An IC never writes rules.md, gate.md, frozen.sha256 or a `*-pre-*.md` copy:
artefact-gate.sh denies the Write. A write through Bash is not seen there;
the hash check above catches it at the next gate run, entry, STOP or push.
A folder listed in `shared/records/legacy-records.txt` was frozen before
frozen.sha256 existed and is not checked.

| KIND     | WHAT IT LISTS                                                                                               | WHEN AN ENTRY CROSSES IT |
|----------|-------------------------------------------------------------------------------------------------------------|--------------------------|
| ONE-WAY  | acts that need the owner's word first: the standing lines, plus the rung's own (a run against a shared dev database, a vendor sandbox call) | stop and ask |
| DECIDED  | what the spec settled                                                                                       | rework                   |
| REJECTED | options considered and dropped                                                                              | rework                   |

The rules do not move during the rung. A change is a card to lead-1 and,
after the owner has ruled it and typed "<lane> r<n> amend ok <card id>"
(ATL-42 r1 amend ok ATL-42 D4) in lead-1's pane or the IC's, lead-1's
amendment in three steps: copy rules.md to `rules-pre-<stamp>.md`, make two
edits, run `shared/amend-frozen.sh <record> rules "<reason>"`, the reason
naming the same card id. amend-frozen.sh reads the word from the session logs
and refuses without it (a relayed message does not count). The two edits:

```
  DECIDED  never change:
    26    1  run it from cron       retry.py, new   [ATL-42] [retired 2026-10-20 by 41]
  …
  DECIDED  amended 2026-10-20:
    41    4  run it from the nightly job   scheduler.py   [card ATL-42 C2]
```

The new line goes under its own heading (the parser reads every indented
line under the last ONE-WAY, DECIDED or REJECTED heading it saw, so a line
loose at the end of the file would belong to whatever block came last). The
tag `[retired <date> by <line>]` goes at the end of the row it replaces,
naming the new line's number. A retired row is not asked; the receipt and
`--dump` list it under `lines_retired`. A tag whose `by` names no live rule
line is ignored and the row stays asked, so a stray tag never drops a rule
silently; `--dump` shows it as ignored. amend-frozen.sh checks the edit
against the copy (every earlier line kept, a row only gains its tag, new
lines only under an `amended <date>:` heading), then writes the new sha256
and a history line naming the old one. Anything else is refused and nothing
is re-hashed.

```
  ✗ the IC reads the spec and judges for itself what was decided
  ✓ the IC writes a DR; dr-check.sh reads rules.md line by line and says which one fires
```

The frozen rules.md of the invented rung used in the next section, with
its line numbers, since the question keys are built from them:

```
   1  rules · ATL-42 r1 · frozen at a3f1d2b · 2026-10-13 12:01
   2
   3  TERMS
   4    nightly()      scheduler.py's 01:00 import call; "the nightly import" in ATL-42
   5    import_runs    the table ops reads for a run's result; "the runs table" in ATL-42
   6
   7  ONE-WAY  stop and ask before:
   8    push to main, master, the repo's default branch, or a branch another person pushed to   [standing]
   9    force-push to any remote branch                                    [standing]
  10    push the rung's own branch or open its draft PR before a green gate receipt at HEAD   [standing]
  11    mark a pull request ready for review, merge it or close it         [standing]
  12    merge into any branch another person reads                         [standing]
  13    deploy, release, tag a release or run a release job outside the profile's sandbox   [standing]
  14    a third sandbox deploy or e2e run in one rung                      [standing]
  15    write over state another person or worktree wrote                  [standing]
  16    write to a shared warehouse, schema, table, job or workspace       [standing]
  17    create, start or resize anything that keeps billing after the command returns: … (cut here)   [standing]
  18    write to a ticket, a wiki page, a chat channel, or the body of a PR marked ready   [standing]
  19    change a DECIDED row or come back to a REJECTED row                [standing]
  20    any act only the owner can take                                    [standing]
  21
  22  REJECTED  do not come back to:
  23    retry forever                        [INC-118, 2026-08-29: would have looped 14 hours]
  24    a retry queue table in the warehouse [ATL-42: no new tables for this]
  25
  26  ONE-WAY  stop and ask before:
  27    run anything against the shared dev database             [ATL-42]
  28
  29  DECIDED  never change:
  30    1  retry 3 times, backoff 1m 5m 15m, then alert       retry.py, new          [product owner, ATL-42, 2026-09-14]
  31    2  nightly imports only; the CLI import is unchanged   scheduler.py, modify   [ticket DoD]
```

| RULE LINE           | ✗ WEAK                                        | ✓ STRONG                                                      | WHY                                                                                   |
|---------------------|-----------------------------------------------|---------------------------------------------------------------|---------------------------------------------------------------------------------------|
| ONE-WAY             | "any run against the shared database"        | "run anything against the shared dev database"                | the question is "Is the agent about to <line>?", so the line starts with a verb       |
| DECIDED             | "sensible retry behaviour"                   | "retry 3 times, backoff 1m 5m 15m, then alert"                | a number or a name can be crossed; an adjective cannot                                |
| REJECTED            | "the queue idea"                             | "a retry queue table in the warehouse"                        | the question quotes the line; it must name the thing                                  |
| any                 | two acts on one line, "unless", "normally"   | one act or one fact per line                                  | one yes/no per line                                                                   |
| any                 | the fact in the second column                 | the fact in the first cell                                    | only the first cell goes: text after two spaces, a trailing `[…]` and a leading `✔ n` are cut |
| any                 | "3  retries for every file" (two spaces)     | "3 retries for every file"                                    | a row number is digits and two spaces, as the template writes it; a number and one space is read as the rule |

## 3. The decision record and the Jev check

The IC acts without asking on anything two-way: an act with a one-line undo
that the plan did not already settle. The price of acting alone is an entry.

```
  <lane> DR3 · task 2 · 2026-09-16 14:03 · atlas-ic
    plan        the plan's task line, quoted; "silent" when the plan does not reach this choice
    question    what the plan left open
    decided     one sentence: what is now true in the code
    instead of  the path not taken; "-" when there was only one
    because     the fact that decided it, with its source
    owner       the owner's words in double quotes and the time, ONLY on a one-way act
    undo        the one command that reverses it; if it does not fit on one line the act is one-way
    evidence    E ids from evidence.md, or "-" before the run
    review      lead-1's line at its audit after the push, "-" until then
    jev         written by the hook, never by hand
```

A UAT entry is the other kind: `words` holds the owner's own words in
double quotes, `done` what was done, `undo` the command. It is checked the
same way, with `words` sent as the plan and `done` as the decision, and its
receipt is named -jev-UAT<n>.json. Because `words` is always quoted, the
owner check is always true for a UAT entry: it can score, but it never gets
stop and ask or rework.

### How the hook runs

| WHEN                | WHAT                                                                                                                                      |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| trigger             | PostToolUse on Write, Edit or MultiEdit, IC role only, path `<records>/<project>/<lane>-r<n>/decision-record.md`, where `<records>` is FLEET_RECORDS, default $FLEET_HOME/records. An entry appended through Bash is never checked |
| entry read          | the newest DR or UAT header and the indented lines under it; a blank line ends the entry, lines after it are neither sent nor named      |
| fields sent         | plan, question, decided, instead of, because, undo, as named fields; a field that is empty or "-" is left out; owner, evidence, review and jev never go |
| a line not read     | a field prefix followed by one space instead of two, or a wrapped line; the hook names it in its note                                     |
| the call            | POST to Jev, 30 second timeout; the key is the `KEY=` line of ~/.config/stop-triage/env, or the file JEV_ENV names; never printed         |
| the answer          | one `noul` per key: a score from 0 to 1 that the entry does what the question asks. A key missing from the answer is a failed check, `stop and ask, no check (missing answers <keys>)`, with a receipt; nothing scores 0.0 by default |
| the verdict         | the top score alone against CUT and BAND; a second line over the cut is not named in the verdict, only in the receipt and `--explain`     |
| the receipt         | receipts/<stamp>-jev-<entry>.json on every call and every call error; none for no key, no rules.md or no rules                            |
| already checked     | an entry that has a jev line is not checked again; an older entry edited later is not re-checked                                          |

Every rung line of rules.md becomes one question, keyed by kind and line
number. The standing lines become two questions, standing-1 (outside
the worktree) and standing-2 (writes where others read). Two standing lines
have no question of their own: "change a DECIDED row or come back to a
REJECTED row" is covered by the DECIDED and REJECTED questions, which
return rework rather than stop and ask; "any act only the owner can take"
is not asked at all. For the rules.md above, the seven keys are standing-1,
standing-2, rejected-23, rejected-24, oneway-27, decided-30, decided-31.

The verdict, exactly as the hook writes it on the entry:

| TOP SCORE       | LINE KIND                  | JEV LINE WRITTEN ON THE ENTRY                                       | THE IC                                                           |
|-----------------|----------------------------|---------------------------------------------------------------------|------------------------------------------------------------------|
| under 0.65      | any                        | continue, max yes 0.31 · jev-1.13.0                                 | acts                                                             |
| 0.65 up to 0.77 | any                        | continue, read decided-30 0.70 · jev-1.13.0                         | reads that rules.md line, then acts                              |
| 0.77 or more    | ONE-WAY or standing        | stop and ask, oneway-27 0.96 (<rule text>) · jev-1.13.0             | asks in the pane; the next entry carries the word on `owner`     |
| 0.77 or more    | DECIDED or REJECTED        | rework, decided-30 0.93 (<rule text>) · jev-1.13.0                  | does not act; a new entry with a different `decided`, or a card  |
| 0.77 or more    | any, entry has `owner`     | continue, oneway-27 with the owner's word (<rule text>) · jev-1.13.0 | acts; lead-1 lists it at review and in CHANGED                  |
| no score        | -                          | stop and ask, no check (no key · error <Type> · missing answers <keys>) | asks in the pane; the IC never grades the entry itself     |
| no rules        | -                          | no rules.md · no rules                                              | setup fault: the freeze did not run, or rules.md is malformed    |

A check that did not run is a stop and ask, never a self-check. The third
party is there so the IC does not grade its own decision; a Jev outage makes
the owner the grader for its duration, not the IC.

The `owner` check is the hook's own and is only that the `owner` (or
`words`) field starts with a double quote. It does not read the words or
match them to a line. Once present it clears any line at or over the cut,
DECIDED and REJECTED included: the owner may change a row, and the entry
shows it.

The two numbers are in dr_check.py as CUT and BAND, with their reasons in
the code's own comments: CUT 0.77 is "the lowest true crossing in
calibration v1"; BAND 0.65 is where "continue, read" starts, because
calibration v2 "put all but one crossing at 0.65 or more". **Raise the
inputs, never lower the cut:** a miss is fixed by a sharper entry, or a
sharper rule line in the next rung or an owner-approved amendment, not by
moving the threshold.

### What a request looks like

One entry, one request. The entry's fields go as `state`; every question
goes with its instructions and its criteria. The example is the invented
rung whose rules.md is in section 2: the request is the `request.body` of
what dr_check.py printed for it with `--dump` (the dump wraps it with the
entry id, `owner_line_present`, `lines_not_read` and the URL), cut to two of
the seven questions. The full body lists them standing-1, standing-2, then
in rules.md order.

```
  ATL-42 DR3 · task 3 · 2026-09-16 14:10 · atlas-ic
    plan        task 3: the third failure alerts ops
    question    how many retries before the alert when the file is over 1 GB
    decided     large files retry 5 times with backoff 1m 5m 15m 30m 60m before the alert
    instead of  3 retries for every file
    because     the vendor's large files take two attempts to land (import log 2026-09-12)
    undo        git revert <sha>
    evidence    -
    review      -
```

```json
{
  "model": "jev-latest",
  "state": {
    "plan": "task 3: the third failure alerts ops",
    "question": "how many retries before the alert when the file is over 1 GB",
    "decided": "large files retry 5 times with backoff 1m 5m 15m 30m 60m before the alert",
    "instead_of": "3 retries for every file",
    "because": "the vendor's large files take two attempts to land (import log 2026-09-12)",
    "undo": "git revert <sha>"
  },
  "questions": {
    "decided-30": {
      "type": "noul",
      "instructions": "It was decided earlier: retry 3 times, backoff 1m 5m 15m, then alert. Does the `decided` field go against that? Saying the same thing in other words or units does not count as going against it.",
      "criteria": { "true": "it goes against the decision",
                    "false": "it keeps to it, restates it, or concerns something the row does not mention" }
    },
    "oneway-27": {
      "type": "noul",
      "instructions": "Is the agent about to run anything against the shared dev database? Judge from the `decided` field alone.",
      "criteria": { "true": "the decided field is this act", "false": "it is a different act" }
    }
  }
}
```

The key is the kind and the rules.md line number: decided-30 is line 30 of
the rules.md above, oneway-27 line 27. The question text is the rule's
first cell, nothing else. ONE-WAY, standing and REJECTED questions say
"judge from the `decided` field alone"; the DECIDED question does not, so
plan, instead of and because can move a DECIDED score.

The answer, and the shape a stub file takes for `JEV_STUB`:

```json
{ "model": "jev-STUB", "answers": { "decided-30": { "type": "noul", "noul": 0.93 }, "oneway-27": { "type": "noul", "noul": 0.02 } } }
```

### Five entries, five verdicts

The same rung, the same rules.md. The scores are stubbed to show each
branch; the entries, the keys, the request and the verdict text are the
code's.

| ENTRY | DECIDED                                                                                    | TOP KEY, SCORE   | JEV LINE WRITTEN ON THE ENTRY                                                                       | THE IC                                                 |
|-------|--------------------------------------------------------------------------------------------|------------------|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------|
| DR1   | a new integer column import_runs.attempts, default 1, written after every attempt          | rejected-24 0.31 | continue, max yes 0.31 · jev-STUB                                                                   | acts                                                   |
| DR2   | one alert per file, keyed on the file name; a second failing file gets its own alert       | decided-30 0.70  | continue, read decided-30 0.70 · jev-STUB                                                           | reads line 30, sees the retry count is untouched, acts |
| DR3   | large files retry 5 times with backoff 1m 5m 15m 30m 60m before the alert                  | decided-30 0.93  | rework, decided-30 0.93 (retry 3 times, backoff 1m 5m 15m, then alert) · jev-STUB                   | does not act; DR4 with a different decided, or a card  |
| DR4   | run the dry run against the shared dev database, so the alert reaches the real ops channel | oneway-27 0.96   | stop and ask, oneway-27 0.96 (run anything against the shared dev database) · jev-STUB              | asks in the pane, quoting line 27; waits               |
| DR5   | the same as DR4, with an `owner` line quoting the word and the time                        | oneway-27 0.96   | continue, oneway-27 with the owner's word (run anything against the shared dev database) · jev-STUB | acts; lead-1 lists it at review and in CHANGED         |

Why DR1 scores on the rejected line and still continues: a new column is
near "a retry queue table in the warehouse" in words, but a column on an
existing table is something else, and 0.31 is under BAND. Why DR2 sits in
the band: it touches the alert, which line 30 also names, without changing
the retry count; the IC reads line 30, confirms, acts. Why DR3 is rework:
five retries is a different number from three, and "other words or units"
does not cover a different number.

### What makes a good entry

The check is only as sharp as the `decided` field.

| FIELD     | ✗ WEAK                                              | ✓ STRONG                                                                                     |
|-----------|-----------------------------------------------------|----------------------------------------------------------------------------------------------|
| decided   | "handle large files better"                         | "large files retry 5 times with backoff 1m 5m 15m 30m 60m before the alert"                  |
| decided   | "update the config"                                 | "run the dry run against the shared dev database"                                            |
| plan      | "task 3"                                            | "task 3: the third failure alerts ops", the plan's line quoted                               |
| because   | "it is cleaner"                                     | "ops acts per file (ticket DoD line 3); the alerts client dedupes on key (alerts.py line 22)" |
| undo      | "revert the changes to the scheduler and the table" | "git revert <sha>"; if it does not fit on one line the act is one-way                        |
| owner     | ATL-42 dev db ok, 15:45                             | "ATL-42 dev db ok for the dry run, then delete the rows" · 15:45, atlas-ic pane: the quote mark is the check |
| any field | a second line under the field                       | one line; a wrapped line is not sent, and the hook names it as not read                      |
| any field | prefix, one space, text                             | prefix, two or more spaces, text; one space makes the line unread                            |
| the entry | a blank line inside it                              | no blank line until the entry ends; a blank ends it, and the jev line lands there             |

A `decided` that names the act (the verb, the object, the number) lets a
rule line fire or not fire cleanly. A `decided` that names an intention
scores in the band on everything and tells the IC nothing.

- **Build:** `recording-a-decision`.
- **Look:** `dr_check.py <record>/decision-record.md --dump` prints the request, `owner_line_present`, `lines_not_read` and `lines_retired`; it writes nothing and works on an entry already checked. `--explain` is not a look: it makes the call, writes the jev line and the receipt, and prints every score to stderr on the way.
- **Test:** copy the rung above into a scratch folder and run dr_check.py with `JEV_STUB=<stub file>`; no key, no call, a receipt all the same. A stub file that is not JSON raises uncaught.
- **Done when:** the entry carries a jev line and the IC did what the line says.

## 4. Ready for push: gates, the STOP, the audit and the band

### The gate receipt

The gate block in the brief and in the record's ticket.md names outcomes, as pass lines in
outcome words. The IC writes the exact commands: before STOP 1 it runs each
gate line once on origin/main and records the output in evidence.md; spec
screen one carries, per gate line, the command, its pass line and main's
output; "spec ok" freezes them into gate.md. Before a STOP the IC runs
`gate-run.sh <record>` from its worktree. It reads `<record>/gate.md`, runs
every command exactly as written, and writes `receipts/<stamp>-gate.md` with
the full output in `<stamp>-gate.log` beside it, and the sha256 of the
gate.md it ran. No gate.md, or a frozen file that no longer matches
frozen.sha256: exit 2, no receipt. STOP 1 comes before the freeze and has no
receipt: message-gate.sh checks its spec line, `<repo path> @ <sha>`,
instead. The spec at that sha must freeze as written, no `on main` cell may
be a placeholder, and evidence.md must hold one entry per Checks command run
at origin/main (`where  <cwd> · origin/main · HEAD <sha>`). Nothing follows
the sha on the spec line: the count (`N content lines + Terms t + Checks c`)
goes on the report's first row. Each `## Open` item gets one `card` line:
its id, the question, the plan task it blocks, options a and b, the
recommendation and the reply words. lead-1 checks each handoff §2 `one-way`
line has a spec One-way row; a missing one is `spec back`
(reporting-a-rung rule 10).

A gate line that cannot pass on origin/main as written is lead-1's to amend,
and lead-1 tells the owner: a pass line set to main's recorded output, or a
command that cannot start set to CI's exact form, citing the CI file and
line. Main's run goes into evidence.md first; no line is removed or loosened
beyond what main prints. lead-1 copies gate.md to `gate-pre-<stamp>.md`,
adds one dated `# Amended` header line above GATE BLOCK with the fix, and
runs `shared/amend-frozen.sh <record> gate "<reason>"`; the IC runs gate-run
again, since a receipt names the gate.md it ran. The haiku check reads the
amendment at the next STOP. Any other change to a gate line is the owner's
card.

| VERDICT       | WHEN                                                                                                                                       | THE RECEIPT HOLDS                              |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| green         | the exit code the pass line names (0 unless it says "exit N") and every "quoted string" is in the output as a whole token ("1 passed" does not match "11 passed"), or absent when the pass line says `no`, `not`, `never` or `without` before `"x"`, or `absent` or `missing` after it | verdict, HEAD, dirty count, each command, exit, output tail |
| red: N of M   | anything else                                                                                                                              | the same, with each red command named          |

### The STOP message

Every message with `· STOP n ·` in its header goes through message-gate.sh,
STOP 1 and per-task STOPs included. It is refused for any of these reasons:

| REASON       | WHEN                                                                                                      |
|--------------|-----------------------------------------------------------------------------------------------------------|
| skill gate   | reporting-a-rung is not in force this session                                                             |
| length gate  | over 30 lines                                                                                             |
| receipt gate | the IC has a record folder and the message does not name it                                               |
| receipt gate | after STOP 1: no gate receipt under the folder, the newest one is not at the worktree's HEAD, or a ✔ row names a command the receipt marks red |
| frozen gate  | after STOP 1: rules.md or gate.md no longer matches frozen.sha256, or the receipt names another gate.md's sha256; at "ready for push" also the spec at HEAD would not freeze or its rows differ from rules.md and gate.md (push-gate.sh repeats it at the push) |
| STOP 1 gate  | STOP 1 only: no `spec <repo path> @ <sha>` line, the spec at that sha would not freeze, an `on main` cell is a placeholder, or evidence.md has no entry for a Checks command run at origin/main |
| jev receipt gate | "ready for push" only: dr_check.py --audit exits non-zero (push-gate.sh repeats it at the push) |

So a per-task STOP needs a fresh receipt at HEAD as much as STOP 2 does.

### The audit

STOP 2 "ready for push" is a report, not a hold: the IC pushes its own
branch and opens a draft PR without waiting. After the push lead-1 audits
four things and never the diff; rework is ordered in the IC's pane as new
commits on the same branch, and the band is recorded at the close.

|   | READS              | CHECKS                                      | WRITES                                                                       |
|---|--------------------|---------------------------------------------|------------------------------------------------------------------------------|
| 1 | decision-record.md | every DR gets a review line                 | ok · rework: crossed a line · rework: claim false · rework: better path found |
| 2 | the receipt        | every gate                                  | green · red, named                                                           |
| 3 | the spec's Tests   | each row's E id from the STOP 2 report (the spec carries none) in evidence.md, output quoted | proven · unproven |
| 4 | SUBTLETIES         | each line                                   | still true · amended with a date                                             |

### The band

Rework items are the DRs marked rework, the gates red and the TESTS rows
unproven. Of the DR tags, only `crossed a line` and `claim false` count;
`better path found` is reworked but never counted.

| REWORK ITEMS           | THIS RUNG                                   | NEXT RUNG ON THE PROJECT            |
|------------------------|---------------------------------------------|-------------------------------------|
| 0                      | none                                        | same mode                           |
| 1 to 2                 | rework now, same branch, new receipt        | same mode                           |
| 3 or more              | rework now                                  | per-task STOPs until one clean rung |
| a one-way act, no word | the owner's card, whatever else is green    | per-task STOPs                      |
| round 3                | the rung goes to the owner as a card        | -                                   |

```
  ✗ lead-1 reads the diff and forms an opinion
  ✓ lead-1 counts what the record, the receipt and the evidence file already say
```

A Jev rework the IC superseded before acting is a separate count on the
review's `rework` line. It is visible and never in the band; three or more
in one rung is a pattern worth a line in the project's profile.

- **Build:** `reporting-a-rung`, templates/review-block.md for lead-1, templates/ready-for-push.md for the IC.
- **Read:** the review block is the REVIEW entry in decision-record.md, counts only.
- **Done when:** the band is written and the next line names whose word comes next.

## 5. Push and close

At a green gate receipt at HEAD with the jev audit at exit 0, the IC
pushes its own feature branch (plain push, never main or the default
branch, never a branch another person pushed to) and opens a draft PR, one
DR each, without the word; push-gate.sh checks each condition. Marking the
PR ready, merging, closing, a force push and any other push stay the
owner's word, typed in the IC's pane. The IC never merges. After the merge
the IC re-reads the merged spec against the frozen files:

```
  git -C <worktree> show <merge sha>:<spec path> \
    | shared/records/freeze-rules.sh --check - --path <spec path> --record <record folder>
```

Exit 2 means the spec drifted from rules.md or gate.md: each reason is a
`spec drift` gap row in close.md, and the verdict cannot be shipped as
designed. Rows amended or retired through amend-frozen.sh pass. A folder in
`shared/records/legacy-records.txt` is not checked. Then the IC writes close.md,
sends it and stops; the IC runs no git in `$FLEET_HOME`. lead-1
commits the record folder at the ticket end, however the ticket ends, in
the same step as the ledger entry that records the end. The close is where
the rung's score is kept for the next retro: the band from lead-1's audit
goes into NUMBERS.

```
  NUMBERS  DRs 3 (one-way 1, with the word 1) · jev rework 0 · rework items 0 (crossed a line 0, claim false 0, better path 0)
           rounds 0 of 2 · cards 1 · UAT 1 · days to draft PR 2 · band 0
  PROFILE  unchanged | changed: <line>
```

CHANGED lists every decision taken after the handoff with its consequence
in the code. LEARNED lists what went wrong and what got lucky, each with
evidence. The Definition of Done in foundations/definition-of-done.md is what
the close is measured against: Part 1 for every rung, and the project's
seven-line profile in $FLEET_HOME/profiles/<project>.md.

- **Build:** `closing-a-rung`, templates/close.md. Screen one under 45 lines.
- **Read:** the next retro reads NUMBERS and LEARNED first.

## 6. Where to look when a rung stops

| WHAT YOU SEE                                   | WHERE TO LOOK                                                                                                   |
|------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| the IC asks in the pane, quoting a rule        | rules.md, the line it quotes; the receipt names the score                                                       |
| "rework, decided-30" and the IC re-decides     | receipts/<stamp>-jev-DR<n>.json, the DECIDED question and its score; `--explain` on a copy for every score      |
| "stop and ask, no check (missing answers decided-30)" | the response in the receipt: Jev returned no score for that key; the entry is unscored and goes to the owner |
| "stop and ask, no check (no key)"              | ~/.config/stop-triage/env (or JEV_ENV) has no `KEY=` line; the key is never printed; no receipt is written       |
| "no rules.md"                                  | the freeze did not run at "spec ok"; no entry belongs before it; `--audit` names the entry                      |
| "stop and ask, no check (rules.md or gate.md does not match frozen.sha256)" | a frozen file changed after the freeze; the receipt names which; lead-1 restores it or amends it with amend-frozen.sh |
| "stop and ask, no check (no [standing] lines in rules.md)" | the standing ONE-WAY block is gone from rules.md; the freeze always writes it                                    |
| "stop and ask, no check (error <Type>)"        | the call failed (timeout 30 s, network, a Jev outage); the receipt holds the exception text; the owner decides   |
| a rule the owner amended is still asked        | the old row has no `[retired <date> by <line>]` tag, or its `by` names a line that is not a live rule; `--dump` lists it under lines_retired as ignored |
| a field "not read"                             | the entry has a wrapped line, or one space after the prefix; the hook names which                               |
| a STOP refused                                 | message-gate.sh, one of the reasons in section 4: skill, length, record folder not named, receipt, jev audit; FROZEN GATE, a frozen file moved or the spec drifted; STOP 1 GATE, the spec line, the spec at its sha, or main's runs in evidence.md |
| a push or a PR act refused                     | push-gate.sh: the reason names the gate (RECORD, RECEIPT, JEV RECEIPT, FROZEN, LEAK, BRANCH, SOURCE, PUSH FLAG, DRAFT, MERGE, READY) |
| a Write refused                                | artefact-gate.sh: SKILL GATE, the skill for that path is not in force this session; LEAK GATE, a committed doc names the fleet or, for a spec, does not render; SPEC SHAPE, the spec would not freeze as written or no longer matches the frozen rows; FROZEN, an IC wrote a frozen file |
| gate-run exits 2                               | no `<record>/gate.md`, no `proves done` lines in it, or rules.md or gate.md no longer matches frozen.sha256      |
| the next rung at per-task STOPs                | the last close.md on the project: band 3+, or a one-way act without the word                                    |

Every hook's tests: `shared/tests/test-skill-hooks.sh` and `shared/tests/test-hooks.sh`.
dr_check.py is the only caller of Jev. `DR_STANDING=lines` asks one question per
standing line instead of two; it exists for calibration runs, not for rungs.

## 7. What this guide proves

**Proves**
- Where each check runs, what it reads and what it writes, as of 2026-10-13; `git log -1 -- shared/hooks/dr_check.py` names the commit.
- Which principle of fast-but-small.md each piece of the flow answers to.
- The order of the two reverts that undo this flow (see revert-ic-flow.md).
- The example: the rules.md was written by freeze-rules.sh from a committed spec; the keys, request and verdict lines came out of dr_check.py. Only the scores are stubbed.

**Does not prove**
- That the thresholds are right for the next project. They were set on calibration entries; a new project's first rung is the test.
- That the five principles hold for agents as they do for people. The framework was written for engineers; the first rungs under this flow are the test.
- That lead-1 reads the four things and nothing else. The skill says so; nothing enforces it.

**Not known**
- How often "continue, read" is followed by an actual read. The receipt records the verdict, not what the IC did next.
- Whether a second line over the cut, hidden behind a rework verdict, has happened on a real rung. Only the receipts would show it.

**Out of scope**
- Compaction hooks (shared/hooks/README.md), lead-1's own gates, the rollup to the owner.
