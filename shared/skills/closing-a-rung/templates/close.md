# Close report template, IC side, the last act on a rung, after the merge.
# Path: $FLEET_HOME/records/<project>/<lane>-r<n>/close.md. The IC
# writes it, sends it and stops; the IC runs no git in $FLEET_HOME. lead-1
# commits the folder at the ticket end, with the ledger entry that records the end.
# Screen one = title line to `---` inclusive,
# blank lines not counted, under 45. A blank line above and below every
# table: a markdown viewer pulls a line written straight under a table into
# it as a one-cell row. Run
# $FLEET_REPO/shared/skills/closing-a-rung/bin/align-tables.py
# on the file: it pads the tables, adds missing blank lines and prints the
# screen one count. Every block of aligned plain text (SHIPPED, NUMBERS and
# PROFILE, the appendix lists) goes in a ``` fence, or a viewer runs its
# lines into one paragraph; fence lines are not counted. A <word> outside
# backticks or a fence is read as an HTML tag and vanishes: write `<line>`.
# Then run $FLEET_REPO/shared/records/md-check.sh on the file:
# exit 0 before the close is sent.
# Example values INVENTED (project atlas,
# ticket ATL-42, IC atlas-ic). Replace every value; keep the order; delete
# these comment lines.

close · atlas-ic · ATL-42 rung 1 · retry failed nightly imports · 2026-09-16 15:40 · merged 7c1e2a9

Verdict: ✔ shipped as designed with one gap, below. Reply `ATL-42 close ok` or `ATL-42 close back: <line>`.

SHIPPED, what exists now

```
designed   scheduler ──▶ retry.with_backoff() ──sleep──▶ importer.run()
built      scheduler ──▶ retry.schedule_retry() ──reschedule──▶ importer.run()
gap        the wait is a reschedule, not a sleep · ATL-42 D2 b, 2026-09-15 · the 02:00 report shares the scheduler thread
```

PROVED, every gate in the ticket

  | GATE                  | PASS LINE                                  | ACTUAL OUTPUT                  | DOES NOT PROVE     |
  |-----------------------|--------------------------------------------|--------------------------------|--------------------|
  | ✔ make test           | exit 0, "0 failed"                         | exit 0, "148 passed, 0 failed" | the 15 minute wait |
  | ✔ make import-dry-run | "attempt 3 of 3 failed, alert sent to ops" | exit 0, same line              | ops read the alert |

not proved by any gate:
  - the retry runs on prod's scheduler, the release train proves it

CHANGED, decisions taken after the handoff (from decision-record.md)

  | ID          | QUESTION                      | DECIDED                                | CONSEQUENCE IN THE CODE           | BY, REVIEW                     |
  |-------------|-------------------------------|----------------------------------------|-----------------------------------|--------------------------------|
  | ATL-42 DR1  | what the retry wraps          | scheduler.nightly(), not importer      | retry.py wraps the scheduler call | atlas-ic, ok                   |
  | ATL-42 D2   | where the 21 minute wait runs | b) reschedule the job                  | retry.schedule_retry(), no sleep  | owner, 2026-09-15              |
  | ATL-42 UAT1 | the alert names the file      | message `import <file> failed 3 times` | alerts call in retry.py, test 3   | owner's words, ok              |
  | ATL-42 DR3  | push the branch               | feat/atl-42-retry pushed, plain push   | none, the branch on origin        | IC, at green receipt 13:40, ok |
  | ATL-42 DR4  | open the PR                   | PR #88 opened as a draft               | none, body from the spec summary  | IC, at green receipt 13:40, ok |
  | ATL-42 DR5  | mark the PR ready             | PR #88 ready for review                | none                              | owner's word 14:18             |

```
NUMBERS  DRs 5 (one-way 1, with the word 1) · jev rework 0 · rework items 0 (crossed a line 0, claim false 0, better path 0)
         rounds 0 of 2 · cards 1 · UAT 1 · days to draft PR 2 · band 0, audit 14:10
PROFILE  unchanged
```

LEARNED, what bites the next rung

  | KIND       | FACT                                                               | EVIDENCE                  |
  |------------|--------------------------------------------------------------------|---------------------------|
  | went wrong | the grill assumed a sleep was safe; the scheduler thread is shared | scheduler.py line 30      |
  | got lucky  | a second failing file in the same minute would have been swallowed | alerts.py line 22, test 3 |

OWED, what this rung leaves behind

  | ITEM                                | OWNER  | STATE            |
  |-------------------------------------|--------|------------------|
  | partial-file format from the vendor | ATL-43 | filed 2026-09-16 |
  | ops dashboard tile for retries      | owner  | to decide        |

---
## Appendix

### Trail

  | STOP | DATE, TIME       | WHAT                                                | PATH                                                     |
  |------|------------------|-----------------------------------------------------|----------------------------------------------------------|
  | 1    | 2026-09-14 15:10 | design spec, 6 components, 1 new card               | docs/superpowers/specs/2026-09-14-atl-42-retry-design.md |
  | -    | 2026-09-15 10:00 | spec ok, rules.md and gate.md frozen; plan, 5 tasks | rules.md, gate.md · plan.md                              |
  | 2    | 2026-09-16 13:41 | ready for push sent; pushed 13:42, draft PR 13:45   | receipts/2026-09-16-1340-gate.md, audit 14:10            |

### Commits

```
7c1e2a9 merge, PR #88, 5 commits: feat: ATL-42 retry with backoff · feat: ATL-42 attempts column · ...
record folder: $FLEET_HOME/records/atlas/atl-42-r1/, lead-1 commits it at the ticket end
```

### Amendments, copied from the spec

```
2026-09-15  ATL-42 D2 b: the wait reschedules; the sleep branch removed from retry.py
```

### Not measured

```
the 15 minute wait end to end: the dry run stubs the clock (tests/conftest.py line 12)
```

### Glossary

```
gate          a command in the ticket's gate block with a pass line declared before the run
owner's word  the owner's typed go-ahead in the IC's pane, required for a one-way act: marking a PR ready, a merge, a deploy outside the sandbox
band          lead-1's score from its audit after the push: 0, 1-2 or 3+ rework items; it sets the next rung's mode
amendment     a dated line in the design spec recording a change after STOP 1
```

### More information

```
ticket      ~/Projects/atlas/docs/tickets/ATL-42.md
handoff     $FLEET_HOME/records/atlas/atl-42-r1/handoff.md
spec        ~/Projects/atlas/docs/superpowers/specs/2026-09-14-atl-42-retry-design.md
record      $FLEET_HOME/records/atlas/atl-42-r1/  (evidence.md, decision-record.md, receipts/, rules.md, gate.md)
```

screen one: 36 lines
