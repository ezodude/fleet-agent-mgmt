# GitHub issue template
# Fill every <field>. Delete these comment lines. Created on the owner's word only.
# The PO view for a GitHub issue: the same content as the Jira PO view
# (jira.md), ordered for two readers. Every external tracker gets only its
# PO view; ticket.md never leaves the fleet.
#
# Rules
# - Saved as <record>/github-po.md. This file is the only text that goes to
#   GitHub, on the owner's word. The fleet ticket (templates/fleet-ticket.md,
#   saved as <record>/ticket.md) keeps the gate block, the standing block and
#   the PROFILE; none of them appears here. Same checklist as the Jira view
#   (SKILL.md "The PO view").
# - First line of the file, a header for the record folder, deleted when you
#   paste into GitHub: <ATL-42> · GitHub PO view, the description as GitHub
#   holds it · set <date time> · the fleet ticket is ticket.md
# - Public facing. Assume a stranger reads it.
# - No personal machine paths. Repo-relative only. External docs by name and link.
# - No client identifiers: client name, project key, workspace or profile id.
# - No people's names. Say "the account lead", "the conference host".
# - Plain words only: no rung, gate, standing, PROFILE, IC, lead-1, roster name,
#   pane, owner's word, DR, STOP, evidence file, record folder.
# - The PO reads screen one: title, Goal, Done when. The folds hold the rest.
#
# Example values INVENTED: project atlas, ticket ATL-42. Replace all of them.
# Outcomes and pass lines come from the brief, never from here.

Title: <ATL-NN: the outcome this ticket delivers, one line, not the activity>

ATL-42: a failed nightly import retries three times, then alerts ops

## Goal

<Two sentences. Who needs what, and why. Then the deadline, if there is one.>

Ops needs a failed nightly import to retry and then raise an alert. A silent
skip is found by a customer today. Ops needs this before the quarter-end run
on 2026-10-01.

## Done when

<Five or six lines. Each one a visible outcome a non-engineer can tick. Plain
words. No commands, no file paths, no jargon.>

- [ ] A failing import is tried three times before it is given up on.
- [ ] Ops gets one alert per failing file, not one per attempt.
- [ ] A file that works on the second try raises no alert.
- [ ] The attempt count is visible in the import records, not only in the logs.
- [ ] Each line above is proven by the checks below.

<details>
<summary>Checks</summary>

<A plain list of outcomes with what each must show: the gate block's
`proves done` and `pass` lines under the heading CHECKS, numbered. No
`on failure`, `owner's word` or `record` line.>

```
CHECKS
  proves done   1 the test suite passes
                2 a dry-run import of a file that always fails retries three times, then alerts ops once
  pass          1 exit 0, 0 failed
                2 exit 0, the log shows attempt 3 of 3 failed and one alert sent to ops
```

</details>

<details>
<summary>Further detail</summary>

Read first, repo-relative paths only
- `atlas/importer.py` lines 40 to 58 : the failure path today.
- `atlas/scheduler.py` lines 1 to 35 : single thread, nothing concurrent.
- `atlas/alerts.py` : `ops(key, message)` rate-limits per key.

Design rules
- The retry wraps the scheduler's call, never the inside of `importer.run()`: the CLI import runs by hand with a human watching.
- One alert per failing file: the alert key is the file name, because `alerts.ops()` rate-limits per key.
- Attempts live on `import_runs`, not in the log: the log rotates after 7 days and ops asks the table.

Rejected, one per line
- Retry forever: hides a dead feed for days.
- A manual rerun button: nobody watches a button.

Pre-commit checks, verbatim from `Makefile` target `check`
- `make lint`, `make test`; `make migrate-check` before any migration commit.

Conventions that bite
- Migrations are numbered and never edited after merge; 0008 is next.

Not in this ticket
- The CLI import, the vendor's partial-file format, and the ops dashboard tile.

</details>
