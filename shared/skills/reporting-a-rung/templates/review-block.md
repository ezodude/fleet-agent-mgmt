# Review block, lead-1 side, under the recap rows in the first message to the
# owner after the audit after the push: the IC has pushed its branch and
# opened a draft PR; the audit reads the record. The same facts are the
# REVIEW entry in the rung's decision-record.md. Counts only; the DR bodies
# stay in the record. The band is recorded at the close (close.md NUMBERS).
# Example values INVENTED (atlas-ic, ATL-42 rung 1). Replace all.

review · atlas-ic · ATL-42 r1 · audit after the push · 2026-09-16 14:10

  decisions   DR1 ok · DR2 ok, owner changed DECIDED 2 · DR3 ok, push · DR4 ok, draft PR   4 of 4, one-way 0
  push        feat/atl-42-retry at c3d4e5f, plain push, draft PR #88; DR3 and DR4 name receipt 13:40
  gates       2 of 2 green, receipt 13:40 at c3d4e5f
  tests       3 of 3 proven, E7 E8
  subtleties  2 of 2 true
  uat         1 entry, acted on, commit c3d4e5f
  rework      0 (crossed a line 0, claim false 0, better path 0), round 0 of 2 · jev 0 superseded before the act
  band        0: next rung same mode, recorded at the close
  next        marking PR #88 ready is your word in the atlas-ic pane: "ATL-42 ready ok"

# ---- a rework example ----

review · atlas-ic · ATL-42 r1 · audit after the push · 2026-09-16 14:10

  decisions   DR1 rework: better path found · DR2 rework: crossed a line (DECIDED 2) · DR3 ok, push · DR4 ok, draft PR   4 of 4, one-way 0
  push        feat/atl-42-retry at c3d4e5f, plain push, draft PR #88; DR3 and DR4 name receipt 13:40
  gates       2 of 2 green, receipt 13:40 at c3d4e5f
  tests       2 of 3 proven, TESTS 3 unproven: ticked, no E id (claim false)
  subtleties  2 of 2 true
  uat         0
  rework      3 items, 2 count (crossed a line 1, claim false 1), better path 1; round 1 of 2 ordered 14:12 · jev 2 superseded before the act
  band        1 to 2: rework now, same mode, recorded at the close
  next        nothing from you; rework lands as new commits on feat/atl-42-retry, the draft PR updates, a new receipt
