# The gate block

One block, written once at the end of the grill, copied verbatim into every
place a rung is described. It is the only definition of "done" a rung has.
It exists because one rung's handoff named the e2e commands and never
said what passing meant, so a failed run was recorded as a completed step.

## The four fields, all required

```
  GATE BLOCK
    proves done   the outcomes that prove the rung done, in outcome words; no commands
    pass          the outcome the run proves: exit code, task state, count, keys
    on failure    do not tick; report the failing line. A fix inside the worktree:
                  fix, one DR, re-run, at most 2 re-runs per line; a third red
                  goes to the owner. Anything outside the worktree: stop, ask.
    owner's word    where it is typed (the IC's pane), before which actions
```

The owner is the person accountable for the work, named on the `owner:`
line of `$FLEET_HOME/roster.md`; every skill,
the charter and the hooks say `the owner` and `owner's word` for that
person. A block with a field missing is not a gate block. A skill that writes a
ticket or a handoff refuses to proceed until all four are present.

The brief and the ticket hold outcomes only. The exact commands are the
IC's to write, in the spec's `## Checks` section, and they are frozen into
`<record>/gate.md` at "spec ok" (Where the block is copied, below).

## On failure, the four clauses

```
  do not tick           a red line is never ticked
  report                the failing line, in the next STOP report
  re-run inside         the fix stays in the IC's worktree (code, tests, local cache,
  the worktree          local tools): fix, re-run, no word needed. One DR per re-run:
                        what was red, what the fix was, the receipt. At most 2 re-runs
                        per line. A third red on the same line: stop, report it; it
                        goes to the owner as a card via lead-1
  stop and ask          a re-run that touches anything outside the worktree (a remote
  outside it            environment, a shared resource) needs the word, unless the
                        profile's sandbox covers it (one-way.md, Two-way)
```

## Outcomes, not edit sizes

A pass line names what the run proved. Completion, task states read back,
tests passed with ids on red, keys or rows present. Never an edit size.

    wrong   git diff --stat shows 2 files, 26 insertions, 26 deletions
    right   each bundle root validates, exit 0, 0 duplicate-key collisions,
            finance 13 job keys with all 11 e2e case keys present

The owner, on that rung: "Outcomes that matter and signify progress."
The same narrowing read 8/8 next sitting and the gate went red.

## Where the block is copied

```
  brief gate block     outcomes, written at the end of the grill
       │
  ticket.md DoD        the source of truth for outcomes, in the record folder
       │                 (the fleet ticket; every external tracker gets a PO view cut
       │                  from it, jira-po.md or github-po.md, with CHECKS in place of
       │                  the block; filesystem: ticket .md is the one file); no commands
       ├──▶ handoff §0    verbatim, on screen 1, before the task line
       │      │
       │      └──▶ spec ## Checks    a table; the IC turns each outcome into a
       │             │               command; per gate line: the exact command, its pass
       │             │               line, main's output (run once on origin/main before
       │             │               STOP 1, recorded in evidence.md; no E ids in the spec)
       │             └──▶ <record>/gate.md   the commands, frozen with rules.md at
       │                                     "spec ok" (shared/records/freeze-rules.sh);
       │                                     shared/records/gate-run.sh runs this file
       ├──▶ STOP report   the IC quotes the pass line beside the actual output
       └──▶ recap token   gates n/m: gates proven over gates asked, this IC,
                          this ticket
```

Verbatim means byte-identical. A paraphrase is where the pass line goes
missing. The ticket keeps the outcomes; `gate.md` keeps the commands.

## Worked example, invented: ATL-42 on project atlas

The ticket and handoff §0:

```
  proves done   the test suite passes
                a dry run of a bad import file retries three times, then alerts ops
  pass          tests: exit 0 and "0 failed" in the summary line
                dry run: exit 0, last log line "attempt 3 of 3 failed, alert sent to ops"
  on failure    do not tick; report the failing line. A fix inside the worktree:
                fix, one DR, re-run, at most 2 re-runs per line; a third red
                goes to the owner. Anything outside the worktree: stop, ask.
  owner's word    typed in the atlas-ic pane before any run against the shared dev database
```

The spec's `## Checks` section, a table, one row per command. The spec
is public (foundations/public-docs.md): no E ids, no paths outside the
repo. A `|` inside a command is written `\|`.

```
| command | pass | on main |
|---|---|---|
| `make test` | exit 0 and "0 failed" in the summary line | exit 0, "212 passed, 0 failed" |
| `make import-dry-run FILE=tests/fixtures/bad.csv` | exit 0, last log line "attempt 3 of 3 failed, alert sent to ops" | red, this change builds it |
```

At "spec ok" freeze-rules.sh writes `<record>/gate.md` from it, without
the `on main` column, as `proves done` and `pass` labels, the format
gate-run.sh reads (a fenced block in those labels still freezes). The on-failure,
owner's word and record lines are fleet lines and never sit in the spec.

## The values come from the project, the shape does not

`make import-dry-run` belongs to atlas. The outcomes and pass lines are
written at the grill and copied at ticket-writing time. The commands are
read from the repo's own quality gates (Makefile, CLAUDE.local.md
"Quality gates") by the IC when it writes `## Checks`. The on-failure line
and the word line are the same in every project.

## When a gate line cannot pass on origin/main

A gate line can fail on origin/main as written: at STOP 1, when main's run
shows it red, or at any later STOP, when a receipt shows a red line that
also fails on origin/main. lead-1 amends `gate.md` itself and tells the
owner in a report, not a card. A line that proves what the rung builds is
red on main by design and is never amended: it stays as written, and
`## Checks` marks main's output "red, this change builds it". Two kinds only:

```
  a  a pass line                     set to main's recorded output
  b  a command that cannot start     set to CI's exact form, citing the CI file and line
```

The guard:

```
  main's run goes into evidence.md first
  never remove a line
  never loosen beyond what main prints
  a copy of gate.md as it was before, kept:
    cp <record>/gate.md <record>/gate-pre-<stamp>.md
  a dated header line at the top of gate.md, above GATE BLOCK:
    # Amended <date time> by lead-1 (C3): <line n>, <kind a|b>, <source>
  then shared/amend-frozen.sh <record> gate "<reason>": it checks the edit
    against the copy and re-hashes frozen.sha256; until then gate-run,
    the STOP gate and the push refuse
  the IC runs gate-run again: a receipt names the gate.md it ran
  the haiku check reads the amendment at the next STOP
```

Anything else stays the owner's card: a pass line main cannot meet for a
real reason, a line to drop.

## One-way acts

The `owner's word` line names the acts of this rung that need the word
before they happen. The standing list every rung inherits is
`foundations/one-way.md`; the project's extra acts are in its profile,
`$FLEET_HOME/profiles/<project>.md`. The handoff's §2 `one-way`
block carries both, one act per line. The spec's `## One-way` section, a
table of `stop and ask before` rows, has one row per line of that block in
the team's words, never the standing list; freeze-rules.sh writes the
standing lines into rules.md above them. The freeze does not read the
profile, so an act with no row is never checked.

## Why it works

A gate is a command plus an expected result. A command alone lets the IC
decide what counts. See grove-monitoring.md: the manager sets the check,
the report carries the evidence, the manager reads the exception.
