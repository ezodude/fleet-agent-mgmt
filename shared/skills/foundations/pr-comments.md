# Review comments on the rung's pull request

The team reviews the rung's pull request on GitHub. The IC that opened
it answers each comment itself, as it arrives: it checks the comment
against the code, says in plain words what it means, then fixes or
replies. This is a step of the existing rung IC, not another IC. It
rests on `superpowers:receiving-code-review`: verify first, never agree
to be agreeable.

This step holds for every rung from 2026-11-27. The rule it stands on is
in `foundations/one-way.md`, Two-way: a reply on the rung's own pull
request is two-way on four conditions.

## When

```
  from   the draft pull request opens (CHAIN step `push, PR`)
  until  pr-watch.sh prints `state merged <sha>` or `state closed`
  STOP   none. No hold, no report to lead-1. Marking ready and merging stay the owner's word.
```

It runs before and after the pull request is marked ready, beside the
`ready, merge` step.

## Subscribe

Right after `gh pr create --draft`, from the worktree, as a Bash command
with `run_in_background`:

```
  $FLEET_REPO/shared/records/pr-watch.sh <pr number>
```

It polls once a minute and exits on the first batch of new comments, so
the session is told once per batch. Handle the batch, then start it
again. Not a Monitor: a monitor expires every 30 minutes and wakes the
session each time, for days. While it watches, STATE.md reads
`awaiting: none`.

```
  comment review 2101 · <author> · <path>:<line> · <first 160 chars> · <url>    a comment on a line of the diff
  comment issue 3001 · <author> · - · <first 160 chars> · <url>                  a comment on the conversation
  comment summary 4002 · <author> · - · <first 160 chars> · <url>                a review's summary text
  state merged <sha> | state closed                                               stop watching; go to the close
  watch error: gh failed 5 times                                                  exit 1: say so in the pane, start it again
```

The line is a pointer. Read the whole comment and its thread before
anything else: `gh api repos/<o>/<r>/pulls/comments/<id>` (a line
comment), `gh api repos/<o>/<r>/issues/comments/<id>` (the conversation).

## Per comment

**REQUIRED SUB-SKILL:** `superpowers:receiving-code-review`, as a Skill
call, once per session before the first comment.

```
  1  read     the whole comment and its thread, not the 160 characters
  2  open     the file and line it names, at HEAD of BRANCH
  3  verify   is it true of this code? run the test, read the caller, cite the E id
              (recording-evidence). Never thank, never agree before this step.
  4  say      in the pane, plain words, three lines:
                says     what the comment says
                touches  which change of the rung it is about (file, function, spec row)
                verdict  right | wrong | unclear, and why
  5  act      one of the three outcomes below
```

## The three outcomes

```
  right ──▶ DR (record-add.sh):  decided  fix review comment <id> on PR #<n>: <the fix in one line>
            fix inside the worktree, a new commit on BRANCH
            gate-run.sh: a green receipt at the new HEAD
            a plain push (push-gate.sh, the five push conditions)
            DR:  decided  reply in thread <id> on PR #<n>: fixed in <sha>, <what changed>
            post the reply, naming the commit sha

  wrong ──▶ DR:  decided  reply in thread <id> on PR #<n>: <the answer in one line>
            post the reply with the evidence: file and line, the test's output, the spec row

  unclear ─▶ DR:  decided  reply in thread <id> on PR #<n>: ask <the one question>
             post the reply as one question; no fix until it is answered
```

One DR per fix and one per post, each written before the act, each with
no `owner` line. Read the `jev` line before acting: `continue` is act;
`stop and ask` or `rework` is do not post (the REPLY GATE of
push-gate.sh refuses the post too).

The `decided` line of a post opens exactly `reply in thread <id> on PR
#<n>:` or `post a comment on PR #<n>:`, and says in one line what the
reply says. The gate holds the post to it:

```
  the newest entry is not a reply's             refused: write the reply's entry first
  it names PR #88, the command posts on #91     refused
  it already let one post through               refused: a second post, or a post that failed, takes a new entry
  two posts in one command                      refused: one command per post
  gh pr review --approve | --request-changes    refused always: an IC gives no verdict on a pull request
```

A reply entry is asked one more Jev question than any other, standing-3:
does the reply promise, agree to or announce a merge, a deploy, a
release, a force push, marking ready, a changed rule, a follow-up
ticket, a later pull request, a new feature or a change in another
repo? Write the `decided` line as the reply reads; a line that leaves
the promise out is a false record, and lead-1 reads the post beside it. The `undo` of a fix is
`git revert <sha>`; the `undo` of a reply is the one command that
deletes it, `gh api -X DELETE repos/<o>/<r>/pulls/comments/<reply id>`
(`issues/comments/<reply id>` for a comment on the conversation). The
post prints the reply's id: put it on the E entry for the post.

A comment that is right but asks for more than the rung holds (another
feature, a refactor of code the rung did not touch) is not a fix: it is
the stop below. No hook catches this one. Jev reads the entry, not the
handoff, so `fix review comment <id>: add the metrics endpoint` reads
`continue` (the known-limit row of the reply calibration). The IC checks
the fix against the handoff's scope itself, and lead-1's second REVIEW
entry reads every review fix against it.

## Who posts, and when the IC stops

The IC posts its own two-way replies. No owner's word, no message to
lead-1.

```
  post it yourself     a fix report that names the commit
                       an answer with its evidence
                       a question

  stop, ask in the pane, quoting the standing line
  `post a pull request comment or reply that commits to a one-way act or to work outside the rung`
                       the reply would promise or agree to a merge, a deploy, a release, a force push,
                         marking ready, or a change to a DECIDED or REJECTED row
                       the reply would promise work outside the rung: a follow-up ticket, another
                         feature, a change in another repo
                       the comment is on a pull request that is not the rung's own
                       the branch holds another author's commit (a suggestion applied on GitHub):
                         the next push is one-way, and so is a pull of it
```

After the word, the DR carries the `owner` line quoting it, then the
post.

## The reply text

- Plain English, short, written for the reviewer: what was checked,
  what was found, what changed. No thanks, no "great point".
- No fleet path or name: the record folder, the handoff, a session
  name, a DR or E id. The team reads the reply on GitHub; the LEAK GATE
  refuses it. Cite the repo file and line, the commit, the test.
- Reply in the thread, so the answer sits under the comment:
  `gh api repos/<o>/<r>/pulls/<n>/comments/<id>/replies -f body="..."`
- A comment on the conversation, or an answer to a review's summary:
  `gh pr comment <n> --body "..."`
- After each post: `$FLEET_REPO/shared/records/pr-watch.sh <n> --mark <new id>`,
  so the watcher does not hand the IC its own reply.

## What reaches lead-1

Nothing, unless the IC stops to ask: then the ask is in the IC's pane,
as any one-way ask. The record carries the rest. DRs written after
lead-1's REVIEW entry (review fixes and replies) get their `review`
lines in a second REVIEW entry before the close is accepted. That entry
is the guard for the two things no hook proves: each review fix is
inside the rung's scope, and each post on GitHub says what its entry's
`decided` line says (`replies-posted.log` in the record lists the posts
the gate let through, one line per entry). The close
report's CHANGED lists each fix and reply, and LEARNED has one row per
comment that was right about a wrong result (closing-a-rung).

## Red flags, stop and fix

| Red flag | What it should be |
|---|---|
| Thanking the reviewer or agreeing before the code was opened | Verify first; the reply states what was checked. |
| A fix with no DR, or a DR written after the commit | The DR comes before the fix, one per comment fixed. |
| A reply with no DR, or two replies under one DR | One DR per post, written before it. The gate refuses the second. |
| A `decided` line that does not open `reply in thread <id> on PR #<n>:` or `post a comment on PR #<n>:` | The gate refuses the post; write the entry in that form. |
| A `decided` line that leaves out what the reply promises | The line says what the reply says. A promise is asked in the pane first. |
| Approving the PR or requesting changes | Never. Comment or reply only. |
| A reply that promises a merge, a release or a follow-up ticket | One-way: ask in the pane first, quoting the standing line. |
| `git commit --amend` or a force push to tidy the fix | A new commit on BRANCH and a plain push. History on the remote is never rewritten. |
| A fix pushed with no new gate receipt | gate-run.sh at the new HEAD; the push gate refuses a stale receipt. |
| A reply naming the record, the handoff or a session | Cite the repo file, the commit or the test. |
| Fixing a comment that asks for work outside the rung | Stop and ask; the owner decides the scope. |
| Waiting for the owner before a two-way reply | The IC answers; the record is the account. |
| A comment left unanswered at the merge | Each comment ends in a fix, an answer or a question. |
| pr-watch.sh exited and was not started again | Start it after every batch, until `state merged` or `state closed`. |
