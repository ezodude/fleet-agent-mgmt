---
name: reviewing-a-team-pr
description: "Use when a repo's reviewer session is handed a team pull request by lead-1 on the owner's \"review #N\", when that PR merges and its lessons are written, and when lead-1 hands the PR over. Reviewer-facing, with a lead side."
---

# Reviewing a team PR

## Overview

The owner is asked to review more team pull requests than one person can
read well. A reviewer session reads one PR and hands back one file: what
the PR does in plain English, the few problems that matter, and the
comments ready to post. Modelled on `superpowers:requesting-code-review`,
narrowed to one PR and to core problems, and built to be fast.

**Core principle:** a finding is a core problem with evidence, or it is
not raised. The reviewer drafts; the owner posts.

## The role

```
who        one reviewer per designated repo, named <repo>-reviewer
where      a row in the roster's `reviewers` block; its own clone or worktree of the repo
cap        outside the cap of 3 active projects; idle until a PR arrives
reviews    the team's PRs on that repo, never a fleet IC's own PR (lead-1 audits those)
has no     rung record, gate, STOP chain, spec, handoff, decision record
writes     one report file per PR; one close.md after the merge; nothing in the team repo, nothing on GitHub
```

## Steps

A review starts at lead-1's message `review <owner/repo>#<n>`, never
from a notification or a PR the reviewer noticed.

1. **Read.** `gh pr view <n> --json title,body,author,state,headRefOid,baseRefName,files,commits,comments,reviews,statusCheckRollup`,
   `gh pr diff <n>`, and for the open threads
   `gh api repos/<owner>/<repo>/pulls/<n>/comments` (a plain GET). Then
   `git fetch origin pull/<n>/head && git checkout --detach FETCH_HEAD`
   in the reviewer's own clone, so callers and tests can be read around
   the diff. Read-only: no commit, no push, no branch.
2. **Summary, plain English.** What changes, and what it touches: the
   files, the callers of what changed, anything a client or another team
   sees. Three to six lines a reader who has not opened the diff can
   follow.
3. **Core findings only.** Six kinds, no others:

   ```
   wrong result   the code returns or stores something other than what the PR says it does
   data loss      rows, files or messages dropped, overwritten or left half-written
   security       a secret, an injection, a missing permission check, data shown to the wrong reader
   one-way act    a migration, a delete, a publish or a deploy step that cannot be undone
   merge order    it breaks, or is broken by, another open PR or the order of deploys
   missing test   risky code (any kind above) with no test that would fail if it broke
   ```

   No nitpicks: style, naming, structure, taste, "could be simpler". Not
   in the findings, not in a draft, not in a footnote.
4. **Evidence per finding.** The file and line, and what was read or run:
   a command and its output. A suspicion with no evidence goes on the
   `UNVERIFIED` list with what was not traced. It is never drafted as a
   comment and never counted in the verdict.
5. **Drafts.** One review comment per finding, and one reply per open
   thread that asks something the code can answer. Plain English a
   teammate reads cold: what goes wrong, where, and a question or the
   smallest fix. No fleet path or name. The reviewer never posts, and
   its settings deny it: the owner posts. On the owner's `commands` in
   the reviewer's pane it prints one block of `gh` commands, one per
   draft, for the owner to paste and run. No word in the pane posts
   anything, and neither the report nor the board offers one.
6. **One report file.** `$FLEET_HOME/checks/<repo>-reviewer/pr-<n>.md`,
   from `templates/review-report.md`: header, verdict (`core problems: n`
   or `no core problem found`), SUMMARY, FINDINGS, UNVERIFIED, DRAFTS,
   DOES NOT COVER. Run `$FLEET_REPO/shared/records/md-check.sh` on it.
   Then one line to lead-1: the path and the verdict. New commits on the
   PR and a second `review` rewrite the same file.
7. **After the merge, the lessons.** Wait with a background command,
   `until [ "$(gh pr view <n> --json state -q .state)" != OPEN ]; do sleep 300; done`,
   or on lead-1's `mine #N`. Merged: write
   `$FLEET_HOME/records/<repo>/pr-<n>-review/close.md` from
   `templates/review-close.md`. Screen one holds only the title line and
   CHANGED, LEARNED, OWED, in `closing-a-rung`'s shape, so
   `shared/records/precedents-gather.sh` reads it like any close and
   `sweeping-precedents` carries its rows into the next brief. CHANGED is
   what the review changed in the merged code, LEARNED what the PR
   teaches the next rung on this repo, OWED what it leaves undone. Run
   `$FLEET_REPO/shared/skills/closing-a-rung/bin/align-tables.py` and
   `$FLEET_REPO/shared/records/md-check.sh` on it, tell lead-1 the path,
   stop. A PR closed unmerged writes no close.md: tell lead-1 and stop.

## Lead side

```
the owner types `review #N` in lead-1's chat (with the repo when more than one is designated)
  └─▶ lead-1: agent-up.sh <repo>-reviewer        idempotent; `already running` is fine
  └─▶ lead-1 sends the reviewer: review <owner/repo>#<n>, as reviewing-a-team-pr
        └─▶ reviewer: report file, one line back ──▶ lead-1 tells the owner the path and the verdict
              └─▶ the PR merges ──▶ reviewer: close.md ──▶ lead-1 commits records/<repo>/pr-<n>-review/
```

lead-1 never starts a review on its own (a notification, a PR it saw, a
teammate's ask are not the owner's word), never posts the drafts, and
never edits them. The board rows are in `keeping-the-board`. While a
review runs, lead-1's state block reads
`awaiting: <repo>-reviewer: the report on <repo> PR #<n>`: the Stop gate
takes a name from the roster's `reviewers` block there.

## Red flags, stop and fix

- A nitpick raised: a finding whose kind is not one of the six.
- An unverified finding drafted as a comment, or counted in the verdict.
- A finding with no file and line, or evidence that is the reviewer's
  reasoning with nothing read or run.
- The reviewer running `gh pr comment`, `gh pr review` or a `gh api`
  write, or a commit or push in its clone.
- A report or a board row that tells the owner a word in the pane will
  post the drafts.
- A review started from a notification, or lead-1 starting one with no
  `review #N` from the owner.
- A reviewer row in the roster's `fleet` block: the hooks would gate it
  as a rung IC.
- A second file in the `pr-<n>-review` folder, or the report written
  there.
- CHANGED, LEARNED or OWED columns renamed, a title indented, or a
  Verdict, SHIPPED, PROVED or NUMBERS block on the close's screen one.
- A close.md for a PR closed unmerged.
- A draft that names the fleet, a session or a local path.

| Excuse | Reality |
|---|---|
| "It is a small naming point, worth a mention" | The owner asked for core problems. Ten small points bury the one that loses data. |
| "I am fairly sure it breaks, I just did not trace it" | Then it is unverified. It goes on the list, and the owner decides whether to ask. |
| "The owner will post it anyway, posting saves a step" | The comment goes out under the owner's name. The owner reads it first. |
| "The PR is open and clearly needs a review" | A review starts on `review #N`. Tell lead-1 it exists; do not start. |
| "The report already has the lessons, skip the close" | The sweep reads close.md and nothing else. A lesson left in the report never reaches a brief. |
| "A VERDICT section would help the reader of the close" | The gatherer and the sweep expect three sections. The report holds the verdict. |

## Example

`templates/review-report.md` carries the invented project atlas, PR #91,
with three findings, one unverified line and four drafts;
`templates/review-close.md` is the same PR after its merge. Copy the
shape, replace every value.
