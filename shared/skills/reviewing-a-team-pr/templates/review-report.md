# Review report template, reviewer side: the one file a review writes.
# Path: $FLEET_HOME/checks/<repo>-reviewer/pr-<n>.md. A second review of
# the same PR (new commits) rewrites this file with the new head sha.
# Order is fixed: header, verdict, SUMMARY, FINDINGS, UNVERIFIED, DRAFTS,
# DOES NOT COVER. KIND is one of six: wrong result, data loss, security,
# one-way act, merge order, missing test. Anything else is not a finding.
# Every FINDINGS row has evidence the reviewer read or ran; a suspicion
# with none goes under UNVERIFIED and gets no draft. One draft per finding
# and one per open thread, in plain English, no fleet path or name: the
# team reads them on GitHub. The reviewer posts none of them.
# A blank line above and below every table; aligned plain text in a fence.
# Example values INVENTED (project atlas, PR #91, reviewer atlas-reviewer).
# Replace every value; keep the order; delete these comment lines.

review · atlas-reviewer · atlas PR #91 · cap the import retry queue · 2026-09-17 10:05 · head 71c0e2f

Verdict: core problems: 3. Drafts below, not posted: you post them. Say `commands` in the atlas-reviewer pane for the gh commands to paste.

SUMMARY, what changes and what it touches

```
changes   the retry queue for nightly imports gets a cap of 500 jobs; a job past the cap is dropped
touches   queue.py (the cap), settings.py (RETRY_QUEUE_CAP), migrations/0042 (adds jobs.attempts)
callers   scheduler.nightly() is the only caller of queue.push(); no API or schema seen by clients changes
tests     2 new tests for the cap value; none fills the queue
size      4 files, +86 -12, 3 commits, author dana
```

FINDINGS, core problems only

  | ID | KIND         | WHERE               | WHAT GOES WRONG                                        | EVIDENCE                                               |
  |----|--------------|---------------------|--------------------------------------------------------|--------------------------------------------------------|
  | F1 | data loss    | queue.py:48         | a job past the cap is dropped with no log and no alert | lines 46-49 return None; grep alerts queue.py: 0 lines |
  | F2 | merge order  | migrations/0042     | PR #89 adds the same column; the second deploy fails   | gh pr diff 89, migrations/0042, same column name       |
  | F3 | missing test | tests/test_queue.py | no test reaches the cap, so the drop in F1 passes CI   | grep -c cap tests/test_queue.py: 2, both read settings |

UNVERIFIED, not raised

```
the cap may be read once at import time, so a settings change needs a restart: settings.py not traced to its loader
```

DRAFTS, for the owner to post

F1 · queue.py:48

```
When the queue is at the cap this returns without logging or alerting, so the import for that
file is lost and nobody finds out. Could it call alerts.send() the way the retry path does, or
is dropping silently intended here?
```

F2 · top-level comment

```
This adds jobs.attempts in migration 0042, and #89 adds the same column in its own 0042.
Whichever deploys second will fail on the duplicate. Which one should merge first?
```

F3 · tests/test_queue.py:1

```
Neither new test fills the queue, so the behaviour at the cap is not covered. A test that
pushes cap + 1 jobs and checks what happens to the last one would pin it.
```

thread 3104 · settings.py:12 · asked by lee: "why 500?"

```
The description gives no source for 500. The nightly run on 2026-09-10 queued 212 retries
at its peak (job log linked in the PR), so 500 leaves room; a line saying so would help.
```

DOES NOT COVER

```
not run     the test suite: read only, CI status taken from gh pr checks (green at 71c0e2f)
not read    the vendored client under third_party/
not judged  style, naming, structure: out of scope for this review
```
