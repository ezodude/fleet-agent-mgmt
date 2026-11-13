```
Brief template, lead-1 side, the close of a brief-grilling. Path:
$FLEET_HOME/records/<project>/<ticket-lowercase>-r<n>/brief.md, saved after "brief ok".
Under 45 lines, title to the last line, counting each field and each list item once
(the gate block's four field lines too): wrapped text is not counted. Every field present, "none" when
empty. Example values INVENTED (project atlas, ticket ATL-42, IC atlas-ic).
A probed fact carries "probed <time>: <result>" in its brackets; a fact
that cannot be probed goes to open as "assumed: <fact>". A row carried
from the record's precedents.json (sweeping-precedents) carries
"[precedent: <record> close.md <SECTION> <n>; <status>]"; this first rung
on atlas has none (precedents.json: {"none": "first rung on atlas"}). Gate block in
outcome words, no commands: the IC writes them before STOP 1.
Markdown: the title is a heading, the rung's purpose and status one plain line under
it, and each field below is a "##" heading with its text under it. constraints and open are
numbered lists, one item each, the source in brackets at the end of the item; one-way is a bullet list.
Only the gate block sits in a fence: it keeps its four fixed field columns because the ticket
and the handoff copy it byte for byte. No line over 150 characters: a long item wraps with its
continuation lines flush left, never indented (an indented line is flagged by md-check).
shared/records/md-check.sh on the file exits 0 before the draw and before the save.
Replace every value; keep the order. Delete this block.
```

# ATL-42 · atlas · brief · rung 1

retry failed nightly imports · 2026-09-14 10:05 · brief ok 10:02

## problem

a nightly import that fails is skipped silently; ops learns of it from a customer  [ops channel, 2026-08-29]

## goal

a failed nightly import is retried, then ops gets one alert per failing file, and the attempts are visible in the run records

## why now

the quarter-end run on 2026-10-01; the last silent skip cost a support ticket

## constraints

(the hows the owner holds; each becomes a DECIDED row in the handoff)

1. three attempts, backoff 1m 5m 15m, then alert  [owner, this grill Q2: 6 of 7 vendor outages under 20 minutes]
2. the alert goes through alerts.ops(), the channel ops already watches  [owner, this grill Q3; probed 09:41: channel exists, the IC's bot
may post, last alert 2026-09-12]
3. the CLI import is unchanged: a human watches it  [owner, this grill Q4; cli.py line 40]

## at risk

none beyond the rung; the shared dev database is touched only with the word

## one-way

(beyond foundations/one-way.md and PROFILE atlas)

- any run against the shared dev database  [gate block]
- applying migration 0008 anywhere but the sandbox  [this grill Q5]

## kind

build

## gate block

```
GATE BLOCK
  proves done   the test suite passes
                a dry-run import of a file that always fails retries three times, then alerts ops once
  pass          test suite: exit 0, 0 failed
                dry run: exit 0, the log shows attempt 3 of 3 failed and one alert sent to ops
  on failure    do not tick; report the failing line. A fix inside the worktree:
                fix, one DR, re-run, at most 2 re-runs per line; a third red
                goes to the owner. Anything outside the worktree: stop, ask.
  owner's word  typed in the atlas-ic pane before any run against the shared dev database
```

## open

(the IC settles these in the spec; the owner reviews direction at STOP 1)

1. where the 21 minute wait runs: the scheduler thread is single and shared with the 02:00 report
2. whether a partial file counts as failed
3. where the attempt count lives
4. assumed: the production scheduler starts the nightly at 02:00 (production, not probed)

## not in rung

the CLI import, the vendor's partial-file format, the ops dashboard tile

## profile

atlas born today: ticket filesystem docs/tickets · gates make test, make import-dry-run · ci none · deploy owner by hand,
UAT in the pane · one-way shared dev database · docs README · sandbox the IC's local atlas-db container (make dev-db), only this
rung writes to it
