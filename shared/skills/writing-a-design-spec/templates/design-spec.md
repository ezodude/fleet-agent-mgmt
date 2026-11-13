<!--
Design spec template. Delete this whole comment before the first commit:
an HTML comment does not render, but anyone with repo access can read it.

The reader is public: the team, PR reviewers and anyone with repo access read
this file on GitHub, as rendered markdown. Nothing in it names the fleet. The
leak list is foundations/public-docs.md: no local paths, no record folder or
its files, no fleet names or roles, no fleet process words, no fleet ids.
Sources cite what the team can open: the ticket, a repo file and line, an
incident, a dated team message, a PR.

Render: a blank line between every block and before the --- fold; section
titles are ## headings; Terms, Rejected, One-way, Decided and Checks are
Markdown tables (a fence still freezes); diagrams sit inside ``` fences; prose
and lists stay outside; every fence is closed; a `|` inside a cell is `\|`.

Title to the --- fold: under 45 content lines. Blank lines, headings, fence
lines, table header and |---| rows, and the rows of the Terms and Checks
tables are not counted. Never
cut blank lines to fit; move detail below the fold.

The three rule blocks (One-way, Decided, Rejected) are one act or fact per
row with the source in its own column: a decision model reads each as a
yes/no question. One-way has a row for every line of the handoff's one-way
block. Checks: one command per outcome of the ticket, each run once on
origin/main before STOP 1; `pass` is `exit N` plus each output fact as a
"quoted string" copied from that run (words outside quotes are never
checked); `on main` is that output, never `-`, TODO or empty. The appendix
below the fold is written after "spec ok".

Each block heading is spelled exactly as here, once, one table under it, no
text between the heading and the table, nothing between the rows. An empty
block is one row whose only filled cell is `none`; Checks is never empty.
A `#` column holds a row number only: 1, 1., ✔ 1 or D1 (never Q1 or a
word). A `source` cell is never `standing` or `retired ...`: those tags
are the freeze's. No block heading sits in a quote or a list, none is
underlined, and every fence opens at the left edge (three spaces at most).
The freeze reads only that, and a hook checks it at every write: a block it
cannot read is a block the rung runs without.

Above the --- fold nothing moves after STOP 1: the push and the rule
check compare it with the STOP 1 commit. Subtleties and Building stay.
Amendments is the last section, `none` or one dated line per new fact.

The spec path and sha, the count, the record folder, the source, one card line
per open item (its id, the plan task it blocks, the reply words) and the reply
words go on the STOP 1 report, never in this file.

Example values are INVENTED (project atlas, ticket ATL-42). Replace every
value; keep the order.
-->

# ATL-42: Retry failed nightly imports

**Problem:** when a nightly import fails, it is skipped without a message, and ops learns of it from a customer (ATL-42; ops channel, 2026-08-29).

**Verdict:** buildable as drawn. One open question, where the wait runs, changes no component.

## Terms

| name | what it is |
|---|---|
| `nightly()` | scheduler.py's 01:00 import call; "the nightly import" in ATL-42 |
| `import_runs` | the table ops reads for a run's result; "the runs table" in ATL-42 |

## Direction

Wrap nightly() in a three-attempt retry, alert through the channel ops watches, and count attempts on import_runs.

Because the vendor's outages last 2 to 20 minutes (6 of 7, ops channel 2026-08-11 to 2026-09-10), and ops reads import_runs for a run's result while the log rotates in 7 days (ATL-42).

## Rejected

| do not come back to | source |
|---|---|
| retry forever | INC-118, 2026-08-29: would have looped 14 hours |
| a manual rerun button | ATL-42: nobody watches a button; ops asked for an alert |

## Subtleties

- The wait is a reschedule, not a sleep: the 02:00 report shares the scheduler thread (scheduler.py line 30).
- One alert per failing file, not per attempt: alerts.ops() rate-limits per key, and the key is the file name (alerts.py line 22).

## One-way

| stop and ask before | source |
|---|---|
| run anything against the shared dev database | ATL-42 |
| apply migration 0008 to any database but the local dev container (make dev-db) | ATL-42 |

## Decided

| # | never change | lands in | source |
|---|---|---|---|
| 1 | retry 3 times, backoff 1m 5m 15m, then alert | retry.py, new | product owner, ATL-42, 2026-09-14 |
| 2 | nightly imports only; the CLI import is unchanged | scheduler.py, modify | ATL-42, definition of done |

## Building

```
nightly() ──▶ retry.py with_backoff(run, 3, [1m 5m 15m]) ──▶ importer.py run(file)
    ok ──▶ import_runs.attempts = n
    third failure ──▶ alerts.py ops(key=file) ──▶ import_runs.status = failed
```

## Open

- **Where the 21 minute wait runs.** Raised by the design, not by ATL-42; settled before the build starts.
  - a) sleep on the scheduler thread: blocks the 02:00 report job (scheduler.py line 30).
  - b) reschedule the job with a delay, recommended: scheduler.schedule_at() already exists (scheduler.py line 12), so no new thread and no blocked job.

## Checks

| command | pass | on main |
|---|---|---|
| `make test` | exit 0, "0 failed" in the summary line | exit 0, "212 passed, 0 failed" |
| `make import-dry-run FILE=tests/fixtures/bad.csv` | exit 0, last log line "attempt 3 of 3 failed, alert sent to ops" | red, this change builds it |

## Tests

| Test | Proves | Does not prove |
|---|---|---|
| bad.csv fails 3 times, then alerts | the chain | the wait lengths |
| alerts.ops called once, key = file name | the rate-limit key | that ops receives it |

---

## retry.py, new

```
contract    with_backoff(fn, attempts: int, waits: list[timedelta]) -> RunResult; returns the last result, raises nothing
inputs      fn returns RunResult(ok: bool, rows: int); waits has attempts - 1 entries
errors      fn raising is caught and counted as a failed attempt; the exception is kept on RunResult.error
failure     attempt 1 ──fail──▶ wait 1m ──▶ attempt 2 ──fail──▶ wait 5m ──▶ attempt 3 ──fail──▶ RunResult(ok=False, attempts=3)
must not    import scheduler.py or alerts.py; retry does not know who called it
source      ATL-42; the wait follows the answer to Open, where the wait runs
```

## scheduler.py, modify lines 28-35

```
contract    nightly() calls retry.with_backoff instead of importer.run; on ok=False calls alerts.ops(key=file, message=last error)
data        writes import_runs.attempts and import_runs.status after the last attempt
errors      alerts.ops raising is logged and swallowed; the run stays failed
must not    touch cli.py's import command (Decided 2)
source      ATL-42; alerts.py line 22 for the rate-limit key
```

## migrations/0008_import_runs_attempts.sql, new

```
data        ALTER TABLE import_runs ADD COLUMN attempts INT NOT NULL DEFAULT 1
errors      none expected; DEFAULT covers the 3,412 existing rows    `SELECT count(*) FROM import_runs` on dev, 2026-09-14: 3412
must not    edit 0007 (migrations/README.md line 3)
source      ATL-42
```

## alerts.py, reuse

```
contract    ops(key: str, message: str), unchanged; key = file name so each failing file alerts on its own
source      alerts.py lines 18-30
```

## Risks and watch

| Risk | How often | Watch |
|---|---|---|
| vendor outage longer than 21 minutes | 1 of 7 outages last month, ops channel | alert count per week |
| two files fail in the same minute | rate limit drops the second alert | test 2 |

## Glossary

- **RunResult**: importer.py's return type, an ok flag and a row count.

## More information

- ATL-42, the ticket.
- INC-118, the incident of 2026-08-29.
- scheduler.py, alerts.py, migrations/README.md in this repo.

## Amendments

none
