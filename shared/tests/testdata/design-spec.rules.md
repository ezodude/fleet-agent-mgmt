
TERMS
  `nightly()`    scheduler.py's 01:00 import call; "the nightly import" in ATL-42
  `import_runs`  the table ops reads for a run's result; "the runs table" in ATL-42

ONE-WAY  stop and ask before:
  push to main, master, the repo's default branch, or a branch another person pushed to   [standing]
  force-push to any remote branch                                    [standing]
  push the rung's own branch or open its draft PR before a green gate receipt at HEAD   [standing]
  mark a pull request ready for review, merge it or close it         [standing]
  merge into any branch another person reads                         [standing]
  deploy, release, tag a release or run a release job outside the profile's sandbox   [standing]
  a third sandbox deploy or e2e run in one rung                      [standing]
  write over state another person or worktree wrote                  [standing]
  write to a shared warehouse, schema, table, job or workspace       [standing]
  create, start or resize anything that keeps billing after the command returns: a cluster, a warehouse or SQL endpoint, a job schedule, a subscription or paid plan   [standing]
  write to a ticket, a wiki page, a chat channel, or the body of a PR marked ready   [standing]
  change a DECIDED row or come back to a REJECTED row                [standing]
  any act only the owner can take                                    [standing]

REJECTED  do not come back to:
  retry forever          [INC-118, 2026-08-29: would have looped 14 hours]
  a manual rerun button  [ATL-42: nobody watches a button; ops asked for an alert]

ONE-WAY  stop and ask before:
  run anything against the shared dev database                                    [ATL-42]
  apply migration 0008 to any database but the local dev container (make dev-db)  [ATL-42]

DECIDED  never change:
  1  retry 3 times, backoff 1m 5m 15m, then alert       retry.py, new         [product owner, ATL-42, 2026-09-14]
  2  nightly imports only; the CLI import is unchanged  scheduler.py, modify  [ATL-42, definition of done]
