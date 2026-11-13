# Fleet ticket template, for any external-tracker target (Jira, a GitHub
# issue, a later one). Saved as <record>/ticket.md. The fleet reads this
# file: the handoff copies the gate block from it, the review checks the
# standing block in it. It never leaves the fleet. What a tracker holds is
# its PO view, written from this file: templates/jira.md for Jira,
# templates/github-issue.md for a GitHub issue, <tracker>-po.md for any other
# (SKILL.md "The PO view").
# Fill every <field>. Delete these comment lines. Header line first.
# Example values INVENTED: project atlas, ticket ATL-42 rung 1, IC atlas-ic.
# Replace all of them; outcomes and pass lines come from the brief, never
# from here. No commands in the gate block: the IC writes them in gate.md.
# The standing block is pasted from foundations/definition-of-done.md Part 1 and
# $FLEET_HOME/profiles/<project>.md, never typed.

# <ATL-42> · <Jira <url> | GitHub issue <repo>#<n> | <other tracker> <url>> · <Story|Task> · parent <ATL-40> · priority <Medium> · labels <Imports> · filed <date time> · the tracker holds the PO view: <jira-po.md | github-po.md | <tracker>-po.md>; this file is the fleet ticket

## Summary

<One line: what this rung delivers, in the reader's words.>
ATL-42 rung 1: a failed nightly import retries three times with backoff, then alerts ops

## Description

**Overview**

<Under 10 lines. What breaks and its evidence, what this rung delivers,
then the one steer that is easy to miss on its own line, last. No commands.>

A nightly import that fails is skipped silently today; ops learns of it
from a customer (ops channel, 2026-08-29). Rung 1 wraps the scheduler's
call in a three-attempt retry with backoff and alerts the ops channel on
the third failure.

Steer: the retry wraps the scheduler's call, never the inside of
importer.run(), because the CLI import runs by hand with a human watching.

**Definition of Done**

<Under 15 rung lines. Plain done-lines a PO reads: one outcome each, no
commands. The last rung line points at the gate block in Further detail.
Then the standing block, pasted byte for byte, not counted.>

- A failed nightly import is retried three times, then ops gets one alert.
- A file that succeeds on a retry sends no alert.
- Each attempt is counted on the import's run record.
- Each line is proven by the gate block and the proofs below it, first in Further detail.

Standing, every rung on atlas  (pasted from foundations/definition-of-done.md Part 1 and $FLEET_HOME/profiles/atlas.md, byte for byte)
DONE, standing
  the IC pushes its own branch and opens a draft PR only at a green gate receipt at HEAD; ready, merge and every other push are the owner's word; the IC never merges
  commits one line each, no AI attribution
  the project's test command exits 0 and its "N passed" line is quoted in the evidence file
    (Platform: the CI checks stand in; there is no local test command)
  confidentiality sweep on every tracked file the rung touched: no client name, key, path or person
  superpowers:verification-before-completion run before every STOP and before "ready for push"
  evidence file and decision record complete, and audited by lead-1 after the push
  every shipped doc line checked against the code it describes
  the spec's SUBTLETIES still true at close, or amended with a date
PROFILE atlas  (atlas-ic)
  ticket      filesystem docs/tickets
  gates       make test: exit 0 and "0 failed"; make import-dry-run FILE=<file>: exit 0, last log line names the outcome
  ci          none
  deploy      the owner, by hand; UAT in the atlas-ic pane
  one-way     any run against the shared dev database
  docs        README
  sandbox     the IC's local atlas-db container (make dev-db); only this rung writes to it

**Further detail**

<The fold, in this order. The gate block first, verbatim, four fields;
under it one proof line per done-line the gate does not cover. Layout
diagram when the rung changes a layout or topology, else omit. Design
rules, one per bullet, the why on the same line. Revert runbook, numbered
and drawn, when the rung moves shared state (a schema, a deploy target, a
bundle), else omit. Read first with absolute paths and one why each.
Pre-commit gates verbatim from the repo. Conventions that bite. Not in
this rung, always.>

```
GATE BLOCK
  proves done   the test suite passes
                a dry-run import of a file that always fails retries three times, then alerts ops once
  pass          test suite: exit 0, 0 failed
                dry run: exit 0, the log shows attempt 3 of 3 failed and one alert sent to ops
  on failure    do not tick; report the failing line. A fix inside the worktree:
                fix, one DR, re-run, at most 2 re-runs per line; a third red
                goes to the owner. Anything outside the worktree: stop, ask.
  owner's word    typed in the atlas-ic pane before any run against the shared dev database.
  record        $FLEET_HOME/records/atlas/atl-42-r1/  (evidence.md, decision-record.md, receipts/, close.md)
```

- `import_runs.attempts` exists: migration 0008 applied in the sandbox, the table shows the column, default 1.
- A good file on attempt 2 sends no alert: a test for that case passes.
- Evidence file complete: `$FLEET_HOME/records/atlas/atl-42-r1/evidence.md`, every run with its exit code (recording-evidence).

```
atlas/
├── atlas/scheduler.py          nightly(): wraps the import call in the retry     MODIFY
├── atlas/retry.py              with_backoff(fn, attempts, waits)                 NEW
├── atlas/importer.py           run(): untouched; the retry wraps it from outside
├── atlas/alerts.py             ops(key, message): reused, key = file name
└── migrations/0008_*.sql       import_runs.attempts INT NOT NULL DEFAULT 1       NEW
```

Design rules
- The retry wraps the scheduler's call, never the inside of `importer.run()`: the CLI import runs by hand with a human watching.
- One alert per failing file: the alert key is the file name, because `alerts.ops()` rate-limits per key.
- Attempts live on `import_runs`, not in the log: the log rotates after 7 days and ops asks the table.

Rejected at the grill, one per line
- retry forever: hides a dead feed for days (INC-118, 2026-08-29, would have looped 14 hours).
- a manual rerun button: nobody watches a button; ops asked for an alert.
- a new import_attempts table: a second table for one integer column.

```
revert on dev
  1. git revert <the retry commits>        scheduler.py calls importer.run() directly again
  2. leave migration 0008 in place         an unused column with DEFAULT 1 harms nothing; dropping it is a new migration
  import_runs rows                         untouched throughout
```

Read first
- Importer: `~/Projects/atlas/atlas/importer.py` lines 40 to 58, the failure path today.
- Scheduler: `~/Projects/atlas/atlas/scheduler.py` lines 1 to 35, single thread.
- Style source for the IC's spec and report: the fleet skill templates (writing-a-design-spec, reporting-a-rung); no repo document.

Pre-commit gates, from CLAUDE.md "Quality gates"
- `make lint`, `make test`; `make migrate-check` before any migration commit.

Conventions that bite
- Commits one line, `type: ATL-42 description`, no AI attribution. Never `git add -A`.
- Migrations are numbered and never edited after merge; 0008 is next.

Not in this rung
- The CLI import, the vendor's partial-file format (ATL-43), and the ops dashboard tile for retries.
