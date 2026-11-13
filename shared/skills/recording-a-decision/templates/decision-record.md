# Decision record template. Path: $FLEET_HOME/records/<project>/<lane>-r<n>/decision-record.md
# Header first (the Write tool), then entries, append-only. Every line present, "-" when empty.
# Each DR and UAT entry is written with shared/records/record-add.sh <record folder> dr|uat, which
# numbers it, stamps the time, appends it at the end and runs the Jev check; never by Edit.
# The `jev` line is appended by shared/hooks/dr-check.sh (its receipt under
# receipts/), the `review` line by lead-1. Example values INVENTED (project atlas, ticket ATL-42, IC atlas-ic).
# Replace every value; keep the order. Delete these comment lines.

# ATL-42 rung 1 · decision record · atlas-ic
goal: a failed nightly import is retried, then ops gets one alert per failing file, and the attempts are visible in the run records
rules: 9b2e7c1  (rules.md, frozen 2026-09-14 11:02)
plan: $FLEET_HOME/records/atlas/atl-42-r1/plan.md

ATL-42 DR1 · task 2 · 2026-09-15 11:42 · atlas-ic
  plan        2 "wrap the nightly import in the retry"
  question    does the retry wrap scheduler.nightly() or importer.run(), which the CLI import also calls?
  decided     the retry wraps scheduler.nightly(), not importer.run()
  instead of  wrapping importer.run(), which would give the CLI import retries too
  because     the CLI import runs by hand with a human watching [handoff §2 brief; cli.py line 40]
  undo        git revert 4e1d9a2; nothing outside the repo changes
  evidence    E4
  review      ok
  jev         continue, max yes 0.06 · jev-1.13.0

ATL-42 DR2 · task 3 · 2026-09-15 16:20 · atlas-ic
  plan        3 "wait 1m, 5m, 15m between attempts"
  question    is the wait a sleep or a reschedule, given the 02:00 report shares the scheduler thread?
  decided     the wait is a reschedule through scheduler.schedule_at(), not a sleep (supersedes nothing; settles ATL-42 D2 b)
  instead of  time.sleep() inside the retry
  because     the 02:00 report shares the scheduler thread [scheduler.py line 30]; owner ruled ATL-42 D2 b, 2026-09-15 15:58
  undo        git revert 7b03c1e
  evidence    E5, E6
  review      ok
  jev         continue, max yes 0.11 · jev-1.13.0

ATL-42 UAT1 · 2026-09-16 10:05 · atlas-ic
  words       "the alert should name the file, not the run id" (atlas-ic pane, 10:04)
  done        alert message is now "import <file> failed 3 times"; test 3 asserts the file name
  commit      c3d4e5f
  undo        git revert c3d4e5f
  jev         continue, max yes 0.03 · jev-1.13.0

ATL-42 DR3 · task 5 · 2026-09-16 13:42 · atlas-ic
  plan        5 "push the branch and open a draft PR at a green gate receipt"
  question    -
  decided     push feat/atl-42-retry to origin, a plain push
  instead of  -
  because     gate receipt 2026-09-16-1340 at HEAD c3d4e5f, 0 red; jev audit exit 0 [receipts/]
  undo        git push --delete origin feat/atl-42-retry
  evidence    E7
  review      ok
  jev         continue, max yes 0.07 · jev-1.13.0

ATL-42 DR4 · task 5 · 2026-09-16 13:45 · atlas-ic
  plan        5 "push the branch and open a draft PR at a green gate receipt"
  question    -
  decided     open PR #88 as a draft, body from the spec summary
  instead of  -
  because     gate receipt 2026-09-16-1340 at HEAD c3d4e5f, 0 red; jev audit exit 0 [receipts/]
  undo        gh pr close 88 (closing is the owner's word)
  evidence    E7
  review      ok
  jev         continue, max yes 0.09 · jev-1.13.0

ATL-42 REVIEW 1 · audit after the push · 2026-09-16 14:10 · lead-1
  DR1 ok · DR2 ok · DR3 ok · DR4 ok
  gates       2 of 2 green, receipt 13:40
  tests       3 of 3 proven, E7 E8 E9
  subtleties  2 of 2 true
  band        0: next rung same mode; the close carries it on NUMBERS

ATL-42 DR5 · task 5 · 2026-09-16 14:20 · atlas-ic
  plan        5 "mark the PR ready on the owner's word; the owner merges"
  question    -
  decided     mark PR #88 ready for review
  instead of  -
  because     REVIEW 1 ok 14:10; gate receipt 13:40 green at HEAD c3d4e5f
  owner       "ATL-42 ready ok" typed in the atlas-ic pane, 14:18
  undo        gh pr ready 88 --undo (reviewers were notified: one-way)
  evidence    E7
  review      -
  jev         continue, standing-1 with the owner's word (mark ready) · jev-1.13.0
