# Review close template, reviewer side, written once after a team PR merges.
# Path: $FLEET_HOME/records/<repo>/pr-<n>-review/close.md, the only file in
# that folder. The reviewer writes it, tells lead-1 and stops; the reviewer
# runs no git in $FLEET_HOME. lead-1 commits the folder.
# Screen one = title line to `---` inclusive, and holds the title line and
# three sections only: CHANGED, LEARNED, OWED, with the titles and columns
# below, so shared/records/precedents-gather.sh reads it like a rung's close.
# No Verdict, SHIPPED, PROVED or NUMBERS. Each title sits at the left edge,
# then a blank line, then an indented table; an empty section is the title,
# a blank line and an indented `none`. Do not rename a title or a column.
# CHANGED: one row per finding or thread that changed the PR before the
# merge; ID is `PR <n> F<k>`. LEARNED kinds: went wrong, went well, got
# lucky, missing guardrail. OWED: what the merged PR leaves undone.
# Run $FLEET_REPO/shared/skills/closing-a-rung/bin/align-tables.py and
# $FLEET_REPO/shared/records/md-check.sh on the file: exit 0 before lead-1
# is told. A <word> outside backticks or a fence is read as an HTML tag.
# Example values INVENTED (project atlas, PR #91, reviewer atlas-reviewer).
# Replace every value; keep the order; delete these comment lines.

close · atlas-reviewer · atlas PR #91 · cap the import retry queue · 2026-09-18 11:20 · merged 4b8d1e7

CHANGED, what the review changed

  | ID       | QUESTION                           | DECIDED                         | CONSEQUENCE IN THE CODE         | BY, REVIEW             |
  |----------|------------------------------------|---------------------------------|---------------------------------|------------------------|
  | PR 91 F1 | what happens to a job past the cap | logged and alerted, not dropped | queue.py line 48 sends an alert | author, commit 9a3c5d2 |
  | PR 91 F2 | which PR merges first, #91 or #89  | #89 first, #91 rebased on it    | the column exists at deploy     | owner, 2026-09-17      |

LEARNED, what bites the next rung

  | KIND              | FACT                                                             | EVIDENCE                         |
  |-------------------|------------------------------------------------------------------|----------------------------------|
  | went wrong        | a full queue dropped the job silently in the first version       | queue.py line 48 at head 71c0e2f |
  | missing guardrail | no test fills the queue, so the drop passed CI                   | tests/test_queue.py, no cap case |
  | got lucky         | #89 and #91 touch the same migration and were opened a day apart | migrations/0042, both PR diffs   |

OWED, what this PR leaves behind

  | ITEM                               | OWNER  | STATE     |
  |------------------------------------|--------|-----------|
  | a test that fills the queue to cap | author | not filed |

---
## Appendix

```
pull request  https://github.com/acme/atlas/pull/91
report        $FLEET_HOME/checks/atlas-reviewer/pr-91.md
```
