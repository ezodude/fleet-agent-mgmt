# STOP 2, "ready for push", IC side. A report, not a hold. Sent only when
# shared/records/gate-run.sh wrote a green receipt at this HEAD (0 red lines); a
# red one is a STOP report. One row per gate from the receipt, one per
# TESTS row of the spec with its E id, then the counts. 30 lines max; a
# hook refuses it with no receipt newer than HEAD, a ✔ over red, or a jev
# audit that does not exit 0. Save to $FLEET_HOME/checks/<ic>/stop-<n>.md,
# send, then push the rung's own branch and open a draft PR. No wait.
# Example values INVENTED (atlas-ic, ATL-42 rung 1). Replace all of them.

atlas-ic · ATL-42 r1 · STOP 2 · ready for push · 2026-09-16 13:50 · pushing, draft PR next

  ✔ gate  make test              13:40   exit 0 · "151 passed, 0 failed"                   = pass    receipt
  ✔ gate  make import-dry-run    13:40   exit 0 · "attempt 3 of 3 failed, alert sent to ops" = pass  receipt
  ✔ test  retry stops on ok      13:40   E7 · test_ok_on_second_attempt passed             = TESTS 1
  ✔ test  one alert per file     13:40   E7 · test_rate_limit passed                        = TESTS 2
  ✔ test  attempts on the row    13:44   E8 · "attempts | integer | not null | default 1"   = TESTS 3

  record     DR 2 (0 one-way) · UAT 1 · SUBTLETIES 2 of 2 true · jev 0 rework · jev audit exit 0
  stakes     none beyond the rung; ready, merge and any deploy wait for the word in this pane
  next       plain push of feat/atl-42-retry, draft PR; DR3 the push, DR4 the PR, each naming receipt 13:40
  options    a) the owner marks the draft PR ready, after lead-1's audit   one word in this pane
             b) rework on any DR or row lead-1's audit marks                new commits on feat/atl-42-retry, the draft PR updates
  unverified the 15 minute wait end to end: the dry run stubs the clock (E7 does not)
  new fact   none
  word       the owner's, in this pane, 10:40 (shared dev database, E8)
  files      stop $FLEET_HOME/checks/atlas-ic/stop-2.md · record $FLEET_HOME/records/atlas/atl-42-r1/ (evidence.md, decision-record.md, receipts/2026-09-16-1340-gate.md)
