# Rung handoff template. lead-1 writes it from the brief. §0 = title line to
# the line before `## 1`, blanks included, under 45. Below §0 no line cap:
# the brief, one section per DECIDED row, one constraint per line with its
# source, each fact once. Example values INVENTED (project atlas, ticket
# ATL-42, IC atlas-ic). Replace every value. Open every path before you
# write its line; a path you did not open is not anchored. Delete these
# comment lines.

# ATL-42 · atlas · rung 1, retry failed nightly imports · atlas-ic · 2026-09-14 10:20

## 0. Gate, on this screen, read before anything
GATE BLOCK  (byte-identical to the gate block in the record's ticket.md)
  proves done   the test suite passes
                a dry-run import of a file that always fails retries three times, then alerts ops once
  pass          test suite: exit 0, 0 failed
                dry run: exit 0, the log shows attempt 3 of 3 failed and one alert sent to ops
  on failure    do not tick; report the failing line. A fix inside the worktree:
                fix, one DR, re-run, at most 2 re-runs per line; a third red
                goes to the owner. Anything outside the worktree: stop, ask.
  owner's word    typed in the atlas-ic pane before any run against the shared dev database.
  record        $FLEET_HOME/records/atlas/atl-42-r1/  (evidence.md, decision-record.md, receipts/, close.md)

TASK    a failed nightly import retries, then alerts ops once per failing file. Today it is skipped silently.
RECORD  $FLEET_HOME/records/atlas/atl-42-r1/   (evidence.md, decision-record.md, receipts/, close.md)
MODE    autonomous: STOP 1 holds; STOP 2 is a report, no hold; plus any ONE-WAY ask in this pane
BRANCH  feat/atl-42-retry   the rung's own; the IC pushes only this branch and opens its draft PR from it
SANDBOX the IC's local atlas-db container (make dev-db); only this rung writes to it   (profile; from BRANCH, at most 2 deploys or e2e runs)

DECIDED  (the hows the owner holds, from the brief's constraints; changing a row is one-way; the why is in §2)
  ✔ 1  retry 3 times, backoff 1m 5m 15m, then alert                 the owner, ATL-42 brief Q2, 2026-09-14
  ✔ 2  alert goes to the ops channel through alerts.ops()           the owner, ATL-42 brief Q3, 2026-09-14
  ✔ 3  nightly imports only; the CLI import is unchanged            the owner, ATL-42 brief Q4, 2026-09-14

OPEN  (the IC settles these in the spec; the owner reviews direction at STOP 1)
  where the 21 minute wait runs; the scheduler thread is single and shared      blocks the retry's shape
  whether a partial file counts as failed                                        blocks the dry-run fixture
  where the attempt count lives                                                  blocks the migration, if any

CHAIN  (in order, each a Skill call, none skipped; the brief was the brainstorm)
  1  design spec   writing-a-design-spec, a public repo doc (foundations/public-docs.md); Checks: per gate line its command,
                   pass line, origin/main's output; spec @ sha, source, record, card lines, reply words on the STOP 1 report  -> STOP 1, hold
  2  freeze        shared/records/freeze-rules.sh <spec path> <record folder> --approved <the STOP 1 sha> on "spec ok": rules.md, gate.md, frozen.sha256   no STOP
  3  plan          superpowers:writing-plans, saved to <record>/plan.md, never in the repo; plan: line in the record header   no hold
  4  build         superpowers:subagent-driven-development; recording-a-decision before any choice the plan
                   leaves open; recording-evidence on every run; on failure and SANDBOX as in §0; the word before ONE-WAY
  5  ready         shared/records/gate-run.sh, then STOP 2 "ready for push" report to lead-1   no hold
  6  push, PR      green receipt at HEAD, jev audit exit 0: push BRANCH, open a draft PR, one DR each, no word   no hold
  7  ready, merge  lead-1 audits the record after the push; marking the PR ready on the owner's word in this pane
                   (one DR with the owner line); the owner merges; the IC never merges   -> closing-a-rung
  superpowers:verification-before-completion before STOP 1, STOP 2 and the push

## 1. Read first  (absolute paths, opened by lead-1 today, one reason each)
  brief        $FLEET_HOME/records/atlas/atl-42-r1/brief.md       the grill's close; §2 is its copy
  ticket       ~/Projects/atlas/docs/tickets/ATL-42.md            the DoD; §0 is its copy
  state        $FLEET_HOME/checks/atlas-ic/STATE.md               rung 0 facts; schema beside it
  gate source  ~/Projects/atlas/Makefile lines 12-30              defines `make test`; no dry-run target yet, see §3
  importer     ~/Projects/atlas/atlas/importer.py lines 40-58     run(): the failure path today, one bare except
  scheduler    ~/Projects/atlas/atlas/scheduler.py lines 1-35     single thread; DECIDED 1 must not block it, §2.1
  alerts       ~/Projects/atlas/atlas/alerts.py lines 18-30       ops() exists, reuse; rate limit at line 22
  runs table   ~/Projects/atlas/migrations/0007_import_runs.sql   the table an attempt count would extend
  (gate source: omit the row when no Makefile, CI file or script defines the commands the IC will write)

LIVE STATE  (read by lead-1 at 10:15, not from memory)
  worktree  ~/Projects/atlas/.claude/worktrees/atlas-ic
  branch    feat/atl-42-retry   HEAD 9b2e7c1   rung 0 merged   make test: 148 passed

## 2. Brief  (copied from the brief file; nothing here is new to the owner)
  problem   a nightly import that fails is skipped silently; ops learns of it from a customer  [ops channel, 2026-08-29]
  goal      a failed nightly import is retried, then ops gets one alert per failing file, and the attempts are visible in the run records
  why now   the quarter-end run on 2026-10-01; the last silent skip cost a support ticket
  at risk   none beyond the rung; the shared dev database is touched only with the word
  one-way   run anything against the shared dev database                            brief, gate block; profile atlas one-way line
            apply migration 0008 anywhere but the sandbox                           brief, this grill Q5

### 2.1 retry 3 times, backoff 1m 5m 15m, then alert
  why         the vendor's outages last 2 to 20 minutes: 6 of 7 outages, ops channel 2026-08-11 to 2026-09-10
  rejected    retry forever            hides a dead feed for days; incident INC-118 (2026-08-29) would have looped 14 hours
              manual rerun button      nobody watches a button; ops asked for an alert, not a control
              one immediate retry      covers 1 of the 7 outages
  constraint  the wait must not block the scheduler's single thread for 21 minutes     scheduler.py line 30, the 02:00 report

### 2.2 alert through alerts.ops()
  why         one channel ops already watches; a new channel is a new thing to forget
  rejected    email                    the on-call rota lives on the channel, not on email
  constraint  ops() is rate-limited to one call per minute per key                      alerts.py line 22
              the key is the file name, not a constant, or two failing files alert once   same line

### 2.3 nightly imports only
  why         the CLI import runs by hand with a human watching; a retry there hides the error from them
  constraint  retry wraps the scheduler's call, never the inside of importer.run()       cli.py line 40 calls run() directly

## 3. Unknowns  (settle each in the spec, citing the line that settles it)
  - does importer.run() raise on a partial file or return a short count; importer.py 40-58 reads as return. Decides the second OPEN line.
  - is alerts.ops() synchronous; a blocking call on the scheduler thread doubles the constraint in §2.1.
  - no dry-run command exists at 10:15; the IC names one on screen one (a new make target or the script directly).

## 4. Sketch
  none: the IC draws it in the spec. DECIDED 3 fixes only where the retry wraps (outside importer.run()).

## 5. Rules that bite  (only what causes damage if missed; the rest is in the repo's CLAUDE.md)
  - commits one line `type: ATL-42 description`, no AI attribution                     CLAUDE.md line 14
  - repo files (spec, PR body, commit, doc) carry no "Ruled by" line and name no person behind a ruling: keep the rule, drop the name
  - never run against the shared dev database without the owner's word in this pane          gate block, §0
  - migrations are numbered and never edited after merge; 0008 is next                  migrations/README.md line 3
  - a permission or classifier block is reported, never relayed or retried
  - STATE.md written before every STOP, schema $FLEET_REPO/shared/hooks/STATE-schema.md
  - STATE.md updated in any turn the owner or lead-1 wrote in (stop, awaiting, next, updated), else touched: the stop gate bounces once
  - STATE.md `awaiting:` opens with none, owner:, lead-1: or a roster name, owner: first: the stop gate bounces any other line
  - the record folder is the owner's: never inside a repo, never deleted, every entry before the act it records

## 6. Report shape
STOP 1 is the spec's screen one; the report, never the spec, carries the spec's repo path at the commit
(nothing after the sha), the count on the spec row, source (this handoff and its time), record (the folder), one card line per open item
(its id, the plan task it blocks, the reply) and the reply words "ATL-42 spec ok" or
"ATL-42 spec back: <line>"; end the turn and hold. STOP 2 is "ready for push" after
shared/records/gate-run.sh, a report, not a hold: at a green receipt at HEAD and the jev audit exit 0 the IC
pushes BRANCH and opens the draft PR without waiting. Between STOP 1 and STOP 2 the only messages to
lead-1 are ONE-WAY asks, each quoting the rules.md line, and a third red on one gate line. Every STOP
opens "atlas-ic · ATL-42 r1 · STOP n ·", then the rows (one per step and per proof, glyph first, pass
line beside the actual output), stakes, options, unverified, files (stop file, evidence.md,
decision-record.md, the newest receipt). Rework from lead-1's audit after the push comes in this pane:
new commits on BRANCH, the draft PR updates. Shape: `reporting-a-rung`. Cold-reader rule: the report is
read by someone running a different ticket.

# Chore variant (SKILL.md, "A chore: no spec, no STOP 1"). Delete this section
# from a rung's handoff: a `## Checks` heading makes the record a chore's, and
# the spec freeze refuses it. In a chore's handoff the title says `chore`;
# MODE, OPEN and the CHAIN below replace the rung's; §3's unknowns are settled
# with a DR; §6 names STOP 2 "ready for push" only; no line anywhere names the
# spec step, STOP 1, --approved or a spec freeze (the freeze refuses it); and
# the `## Checks` table goes after the CHAIN, before `## 1`. lead-1 runs each
# command once on origin/main, writes what it printed under `on main`, then runs
# shared/records/freeze-rules.sh --chore <record folder>/handoff.md before launch.

# ATL-50 · atlas · chore, tidy the public retry spec · atlas-ic · 2026-10-20 09:10

MODE    autonomous: STOP 2 is a report, no hold; plus any ONE-WAY ask in this pane
OPEN    none

CHAIN  (in order, each a Skill call, none skipped; lead-1 froze the Checks below before launch)
  1  build         recording-a-decision before any choice the handoff leaves open; recording-evidence
                   on every run; on failure as in §0; the word before ONE-WAY
  2  ready         shared/records/gate-run.sh, then STOP 2 "ready for push" report to lead-1   no hold
  3  push, PR      green receipt at HEAD, jev audit exit 0: push BRANCH, open a draft PR, one DR each, no word   no hold
  4  ready, merge  the owner's word in this pane (one DR with the owner line); the owner merges   -> closing-a-rung
  superpowers:verification-before-completion before STOP 2 and the push

## Checks

| command | pass | on main |
|---|---|---|
| `make docs-lint` | exit 0, "0 problems" | exit 1, "4 problems" |
| `make test` | exit 0, "148 passed" | exit 0, "148 passed" |
