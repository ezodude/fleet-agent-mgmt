# Evidence template. Path: $FLEET_HOME/records/<project>/<lane>-r<n>/evidence.md
# Header first (the Write tool). Each entry is written with shared/records/record-add.sh <record folder> e,
# which numbers it, stamps the time and appends it at the end; never by Edit.
# One entry per run, written when the run ends, never edited. Outputs quoted as
# printed. Example values INVENTED (project atlas, ticket ATL-42, IC atlas-ic).
# Replace every value; keep the order. Delete these comment lines.

# ATL-42 rung 1 · evidence · atlas-ic

## E1 gate line 1 on origin/main · 2026-09-14 14:20
  ran       make test
  where     ~/Projects/atlas/.claude/worktrees/atlas-ic · origin/main · HEAD 5a7f3d0
  exit      0
  output    145 passed, 0 failed in 11.8s
  proves    gate line 1 starts and meets its pass line on main, before any change; spec screen one quotes it
  does not  prove the line on the rung's branch; the receipt at HEAD does that

## E3 importer.run on a partial file · 2026-09-15 10:12
  ran       uv run python -c "from atlas.importer import run; print(run('tests/fixtures/short.csv'))"
  where     ~/Projects/atlas/.claude/worktrees/atlas-ic · feat/atl-42-retry · HEAD 9b2e7c1
  exit      0
  output    RunResult(ok=True, rows=3)
  proves    run() returns a short count and does not raise on a partial file (importer.py line 55)
  does not  prove what the scheduler does with ok=True and rows < expected

## E4 test suite after task 2 · 2026-09-15 11:40
  ran       make test
  where     ~/Projects/atlas/.claude/worktrees/atlas-ic · feat/atl-42-retry · HEAD 4e1d9a2
  exit      0
  output    148 passed, 0 failed in 12.3s
  proves    the retry wrapper breaks nothing in the existing suite
  does not  prove the retry itself; tests/test_retry.py lands in task 3

## E7 gate: make test and the dry run · 2026-09-16 13:40
  ran       receipts/2026-09-16-1340-gate.md  (shared/records/gate-run.sh, both commands of the gate block)
  where     ~/Projects/atlas/.claude/worktrees/atlas-ic · feat/atl-42-retry · HEAD c3d4e5f
  exit      0, 0
  output    green: "151 passed, 0 failed" = pass; "attempt 3 of 3 failed, alert sent to ops" = pass
  proves    both gate pass lines, at this HEAD
  does not  prove the 15 minute wait end to end (the dry run stubs the clock, tests/conftest.py line 12)

## E8 migration read-back on dev · 2026-09-16 13:44
  ran       psql "$DEV_URL" -c '\d import_runs'
  where     ~/Projects/atlas/.claude/worktrees/atlas-ic · feat/atl-42-retry · HEAD c3d4e5f
  exit      0
  output    attempts | integer | not null | default 1
  proves    migration 0008 applied on the dev copy, column and default as designed
  does not  prove the migration on any other database
