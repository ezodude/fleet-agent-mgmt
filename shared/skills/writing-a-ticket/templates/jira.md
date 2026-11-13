# Jira PO view template
# Saved as <record>/jira-po.md. This file is the only text that goes to Jira,
# on the owner's word. The fleet ticket (templates/fleet-ticket.md, saved as
# <record>/ticket.md) keeps the gate block, the standing block and the
# PROFILE; none of them appears here. Written from ticket.md by the checklist
# in SKILL.md "The PO view".
# Fill every <field>. Delete these comment lines. The first line is a header
# for the record folder: delete it when you paste into Jira.
# Example values INVENTED: project atlas, ticket ATL-42. Replace all of them;
# outcomes and pass lines come from the brief, never from here.
# Plain words only: no rung, gate, standing, PROFILE, IC, lead-1, roster name,
# pane, owner's word, DR, STOP, decision record, evidence file, local path.

# <ATL-42> · Jira PO view, the description as Jira holds it · set <date time> · the fleet ticket is ticket.md

# The Jira summary field (one plain line, in ticket.md, no "rung"):
#   A failed nightly import retries three times with backoff, then alerts ops
# Project <ATL> · <Story|Task> · parent <ATL-40> · priority <Medium> · labels <Imports>
# are fields of the issue, also in ticket.md.

**Overview**

<Under 10 lines. What breaks and its evidence, what this ticket delivers,
then the one steer that is easy to miss on its own line, last. No commands.>

A nightly import that fails is skipped silently today; ops learns of it
from a customer (ops channel, 2026-08-29). This ticket wraps the
scheduler's call in a three-attempt retry with backoff and alerts the ops
channel on the third failure.

Steer: the retry wraps the scheduler's call, never the inside of
importer.run(), because the CLI import runs by hand with a human watching.

**Definition of Done**

<Under 15 lines. Plain done-lines a PO reads: one outcome each, no
commands. The last line points at the checks in Further detail. No standing
block, no PROFILE: they are in ticket.md.>

- A failed nightly import is retried three times, then ops gets one alert.
- A file that succeeds on a retry sends no alert.
- Each attempt is counted on the import's run record.
- Each line is proven by the checks below, first in Further detail.

**Further detail**

<In this order. The checks first, a plain list of outcomes with what each
must show: the gate block's `proves done` and `pass` lines under the
heading CHECKS, numbered; no `on failure`, `owner's word` or `record`
line. Under it one proof line per done-line the checks do not cover.
Layout diagram when the ticket changes a layout or topology, else omit.
Design rules, one per bullet, the why on the same line. Rejected, one per
line. Revert runbook, numbered, when the ticket moves shared state, else
omit. Merge order when one step must precede another, else omit. Read first
with repo-relative paths and one why each. Pre-commit checks from the
repo's CI. Conventions that bite, the repo's own. Not in this ticket,
always.>

```
CHECKS
  proves done   1 the test suite passes
                2 a dry-run import of a file that always fails retries three times, then alerts ops once
  pass          1 exit 0, 0 failed
                2 exit 0, the log shows attempt 3 of 3 failed and one alert sent to ops
```

- `import_runs.attempts` exists: migration 0008 applied in the dev database, the table shows the column, default 1.
- A good file on attempt 2 sends no alert: a test for that case passes.

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

Rejected, one per line
- retry forever: hides a dead feed for days (INC-118, 2026-08-29, would have looped 14 hours).
- a manual rerun button: nobody watches a button; ops asked for an alert.
- a new import_attempts table: a second table for one integer column.

```
revert on dev
  1. git revert <the retry commits>        scheduler.py calls importer.run() directly again
  2. leave migration 0008 in place         an unused column with DEFAULT 1 harms nothing; dropping it is a new migration
  import_runs rows                         untouched throughout
```

Merge order: migration 0008 on dev before the merge that deploys the scheduler change, because the scheduler writes the new column on its first run.

Read first
- `atlas/importer.py` lines 40 to 58, the failure path today.
- `atlas/scheduler.py` lines 1 to 35, single thread.

Pre-commit checks, from the repo's Makefile
- `make lint`, `make test`; `make migrate-check` before any migration commit.

Conventions that bite
- Migrations are numbered and never edited after merge; 0008 is next.

Not in this ticket
- The CLI import, the vendor's partial-file format (ATL-43), and the ops dashboard tile for retries.
