<!--
Analysis template. Screen one = the title line to the `---` fold, under 45
content lines: blank lines, headings and fence lines are not counted.
Example values INVENTED (project atlas, ticket ATL-17). Replace every
value; keep the order. Delete this comment.
-->

# ATL-17 · atlas · duplicate rows in nightly imports · 2026-09-14

**Verdict:** one fault, not two; the importer commits per chunk and a retried chunk is inserted twice. 312 of 3,412 runs affected.

## Found

```
✔ every duplicated row sits in a run with a mid-file retry     312 runs, all with a "chunk retry" log line; 0 without
✔ the importer commits after each 500-row chunk                importer.py line 47, `commit()` inside the chunk loop
✔ a retried chunk restarts from row 0 of the chunk              importer.py line 52, offset reset on exception
✔ the vendor file itself carries no duplicates                  `sort | uniq -d` on the 2026-09-12 file: 0 lines
✔ a unique index on (run_id, source_row) rejects the duplicates  dry run 2026-09-13 on a dev copy: 0 duplicates, 312 runs replayed
```

## Decides

- the fix is one change: keep the chunk offset across a retry, plus the index as a guard
- the 4,180 existing duplicate rows can be deleted by (run_id, source_row) with no data loss

## Open

```
? Open 1 · delete the existing 4,180 duplicates, or leave them · before the fix PR
   stakes     the monthly report (reports/monthly.sql) counts rows; it has over-counted since 2026-06
   decide     a) delete them in the fix migration                recommended
              b) leave them, fix forward                          the report stays wrong for June to September
              c) delete and restate the four monthly reports       ops owns the reports, not us
   why a      the rows are exact copies; the report corrects itself on the next run
   trace      appendix, Open 1
```

```
? Open 2 · unverified: the 2026-05 chunking change introduced it · before the fix PR
   stakes     if it did, the same author's export job may carry the same reset
   decide     a) bisect the two releases, 1h                      answered on the record
              b) fix without knowing                              recommended, the fix is the same either way
   why b      the fault is known; the origin changes nothing about the fix
   trace      appendix, Open 2
```

---

## Appendix

### Open 1

```
mechanism   commit per chunk, then an exception resets the offset to the chunk start; rows 0 to n of the chunk insert twice
the count   312 runs × up to 500 rows; 4,180 exact duplicates by (run_id, source_row) on dev, 2026-09-13
rejected    c) restating reports is ops' call, not ours; b) leaves a known over-count on the record
evidence    scripts/check_duplicates.sql, run on the dev copy 2026-09-13
```

### Open 2

The chunk loop landed 2026-05-02 (git log importer.py); the first duplicate run is 2026-05-06. Correlation only, no diff read.

### History

2026-03 the importer loaded whole files in one transaction; 2026-05 chunking added for the 2 GB vendor files.
