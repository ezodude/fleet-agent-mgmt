---
name: recording-a-decision
description: Use when a fleet IC (AgentMgmt Lead and ICs) makes a choice the plan is silent on or leaves open, takes a one-way act on the owner's word, re-runs a red gate line, deploys to its sandbox, pushes its own branch or opens its draft PR, or acts on the owner's UAT feedback in its pane; and when lead-1 writes the review, its audit of the record after the push. The entry is written before the act. IC-facing; lead-1 reads it at the audit.
---

# Recording a decision

## Overview

The decision record is the rung's audit log: what was decided, instead
of what, why, how to undo it, the evidence it rests on, and what the
review said. It is read after the fact by someone who was not there,
possibly in a regulated review, to answer one question in one grep.
It lets the fleet run as if always under a regulated review, able to
explain every choice, without slowing its execution.

**Core principle:** the entry comes before the act, and is never edited
after. A change of mind is a new entry that supersedes the old one.

**REQUIRED BACKGROUND:** `foundations/one-way.md` (the line between
decide-and-log and stop-and-ask), `recording-evidence` (what the
`evidence` line points at).

## Where it lives

```
  $FLEET_HOME/records/<project>/<lane lowercase>-r<n>/
    decision-record.md   this file: DR, UAT and REVIEW entries, append-only
    evidence.md          E entries, recording-evidence
    receipts/            one file per gate run (<stamp>-gate.md) and per Jev check (<stamp>-jev-DR<n>.json)
    rules.md             screen one's rule blocks frozen at the approval sha (shared/records/freeze-rules.sh, writing-a-design-spec step 5)
    gate.md              screen one's gate commands, frozen with rules.md in the same step; gate-run.sh runs it
    frozen.sha256        the spec path, the approved sha and the sha256 of rules.md and gate.md, written by the freeze
    rules-pre-<stamp>.md the copy lead-1 takes before an amendment; gate-pre-<stamp>.md the same for gate.md
    close.md             the close report (closing-a-rung); lead-1 commits the folder at the ticket end
```

`<project>` is the repo name as the profile files in
`$FLEET_HOME/profiles/` spell it. The folder is outside
every repo and outside AgentMgmt: it is the owner's artefact. lead-1
creates it with the brief (brief.md, then ticket.md, the PO view
`<tracker>-po.md` when a tracker holds the ticket, and handoff.md); the
IC adds its files from the first entry. The path goes on the `record` line of the STOP 1 report and on the `files`
line of every STOP report. Never in the spec: it is a public repo doc
(`foundations/public-docs.md`).

rules.md and gate.md are hash-checked. The decision-record check,
gate-run, the STOP gate and the push compare each with frozen.sha256
before reading it (`shared/frozen.py verify`). The IC never writes
rules.md, gate.md, frozen.sha256 or a `*-pre-*` copy; a hook denies it.
An amendment is lead-1's alone, on the owner's yes or for a gate line
main cannot pass: copy the file to `rules-pre-<stamp>.md` or
`gate-pre-<stamp>.md`, edit it (a dated `<KIND>  amended <date>:` block
with the new rows and a `[retired <date> by <line>]` tag on the row it
replaces, or a `# Amended` header line in gate.md), then run
`shared/amend-frozen.sh <record> rules|gate "<reason>"`, which checks
the edit and re-hashes. A folder in `shared/records/legacy-records.txt` froze
before frozen.sha256 existed and is not checked.

## When an entry is written

```
  WRITE A DR    the plan is silent or leaves a choice, and a reviewer would see the result in the PR
                any act on foundations/one-way.md or the spec's `## One-way` block, with the owner's word
                each re-run of a red gate line after a fix inside the worktree: what was red, the fix, the receipt
                each sandbox deploy or e2e run, numbered on `decided`: "sandbox 1 of 2", "sandbox 2 of 2"
                the push of the rung's own branch, and the draft PR, one entry each, at a green receipt at HEAD
  WRITE A UAT   the owner typed feedback in the pane and the IC acted on it (the two-way loop)
  DO NOT WRITE  a choice the plan already made; a line of code nobody would ask about; a rename
  lead-1 WRITES the REVIEW entry at its audit after the push, and the `review` line of each DR
```

The re-run, sandbox, push and draft PR entries carry no `owner` line:
`because` names the receipt, and for the push and the PR also the jev
audit's exit 0. A re-run is at most 2 per gate line; a third red on the
same line, or a third sandbox run, goes to the owner. Marking the PR
ready, merging, closing it, a push to main or the default branch, any
force push and a deploy outside the sandbox still need the `owner` line.
A push or draft PR over a red receipt line needs one too: the owner types
`<lane> r<n> override <checks>: <reason>` in this pane, and the next DR's
`owner` line quotes those words verbatim with the time; `push-gate.sh`
reads both, the typed line in this session's log and the quote here.
A one-way act with no `owner` line is a breach, whatever the reason;
it is always the owner's card.

## The entries

Fixed prefixes, so each question is one grep. Header, then the lines at
one indent, in this order, every line present (`-` when empty).

```
<lane> DR<n> · task <n> · <date time> · <IC>
  plan        the plan's task line, quoted verbatim; "silent" when the plan does not reach this choice
  question    what the plan left open, as one question the lines below answer
  decided     one sentence: what is now true in the code or the run
  instead of  the path not taken, one line; "-" when there was only one
  because     the fact that decided it, with its source in brackets
  owner       the owner's words verbatim and the time, ONLY on a one-way act; absent otherwise
  undo        the one command that reverses it; if it does not fit on one line the act is one-way
  evidence    E ids from evidence.md, or "-" before the run
  review      lead-1's line, "-" until the review: ok | rework: crossed a line | rework: claim false | rework: better path found

<lane> UAT<n> · <date time> · <IC>
  words       the owner's words verbatim, the pane and the time
  done        what changed, one line
  commit      the sha
  undo        git revert <sha>, or the one command

<lane> REVIEW <n> · audit after the push · <date time> · lead-1
  DR1 ok · DR2 rework: crossed a line · ...        one tag per DR, two reasons only
  gates       n of m green, receipt <time>
  tests       n of m TESTS rows proven, E ids
  subtleties  n of m true
  band        <0 | 1-2 | 3+> and what it moves; the close carries it on NUMBERS
```

## How an entry is written

The header (rule 2) is the one write with the Write tool. Every DR and
UAT entry after it goes through `shared/records/record-add.sh`, run from the
worktree, as `gate-run.sh` is:

```
  $FLEET_REPO/shared/records/record-add.sh <record folder> dr <<'EOF'
  task 5
    plan        5 "push the branch and open a draft PR at a green gate receipt"
    question    -
    decided     push feat/atl-42-retry to origin, a plain push
    instead of  -
    because     gate receipt 2026-09-16-1340 at HEAD c3d4e5f, 0 red; jev audit exit 0 [receipts/]
    undo        git push --delete origin feat/atl-42-retry
    evidence    E7
    review      -
  EOF
```

The first line is what goes between the id and the time (`task 5`,
`push`); a UAT entry has none, its lines start at `words` (`record-add.sh
<record folder> uat`). The script reads the next number from the file,
stamps the time, takes the lane and the IC from the header and appends
the entry at the end of the file. It then runs the Jev check below on
it, so the `jev` line lands under it, then the jev audit, and prints the
entry id, the `jev` line, the check's note and the audit. It refuses,
writing nothing: a number, lane or IC in the body that is not the next
one or the file's, a file with no header, a blank line inside the entry, a
`jev` line, a `review` line other than `-`. `record-add.sh --dump
<record folder> dr` shows the entry without writing it.

Quote the heredoc delimiter, `<<'EOF'`: with a bare `<<EOF` the shell runs
any `$(...)` or backtick in the body before the entry is written, and the
hook denies the command. Run it with none of JEV_STUB, JEV_URL or
DR_STANDING set: the receipt records them, and the audit at "ready for
push" and at the push does not count a receipt made with one.

An entry goes only at the end because the check reads an entry as its
header and the indented lines under it, up to the first line that is not
indented. An Edit that anchored DR3 on UAT1's `undo` line put DR3 above
UAT1's `jev` line: the check read that line as DR3's, checked UAT1 again,
never checked DR3, and the audit failed at the push. So a hook denies an
IC's Edit that does not append at the end of the file, or that appends
anything but the next entry's header and lines (an indented line under the
last entry, text on the last line, a `jev` line), a Write over the file
once it has text, and a Bash write to it outside `record-add.sh`. The
audit fails an entry with no `jev` line and an id written twice.

## The Jev check

The hook `shared/hooks/dr-check.sh` (logic in `dr_check.py`, run it with
`--dump` to see the request) appends one line to a DR or UAT entry after
the write, then runs the jev audit on the file and shows its result, so
an entry that took another entry's `jev` line shows at the write, not
first at the push. `record-add.sh` runs the same two steps. Jev sees six lines of the entry as named fields: `plan`,
`question`, `decided`, `instead of`, `because`, `undo`; `owner`,
`evidence` and `review` never go. A field is one line: a second line is
not read, and the hook names every line it skipped. Each call leaves
`receipts/<stamp>-jev-DR<n>.json` beside the record, the request as sent,
the answers and the verdict. Keys name the
kind and the rules.md line: `oneway-19`, `decided-28`, `rejected-15`,
`standing-1` (outside the worktree), `standing-2` (writes where others
read); for both, the push of the rung's own branch and its draft PR are
not, push-gate.sh holds them.

```
  jev  continue, max yes 0.08 · jev-1.13.0                  act
  jev  continue, read decided-28 0.45 · …                   read the line, then act
  jev  continue, oneway-19 with the owner's word (apply, …) · …   act; the `owner` line is the receipt
  jev  continue, decided-26 with the owner's word (4 credentials …) · …   act; the owner changed the row,
                                                            lead-1 lists it at the review and in CHANGED
  jev  stop and ask, oneway-19 0.95 (apply, …) · …          do not act; ask in this pane, quoting the line;
                                                            the next entry carries the word on `owner`
  jev  rework, decided-28 0.91 (exact plan …) · …           do not act; next entry with a different
                                                            `decided`, or a card to the owner via lead-1
  jev  stop and ask, no check (no key | error … | missing …)  the check did not run: ask in this pane, never
                                                            grade the entry against rules.md yourself
  jev  stop and ask, no check (rules.md or gate.md does not match frozen.sha256)
                                                            a frozen file changed after the freeze: ask in this
                                                            pane; lead-1 restores it or amends it properly
  jev  stop and ask, no check (no [standing] lines in rules.md)
                                                            the standing block is gone: ask; lead-1 re-freezes
  jev  no rules.md                                          the entry came before the freeze; the audit names it
```

A `rework` or `stop and ask` entry stays in the record and the next
entry says `(supersedes DRn)`. lead-1 counts them at the review and the
close as `jev n rework, superseded before the act`; they do not move the
band, since nothing reached the code; three or more in one rung go into
the project's profile as a pattern.

The owner's word clears any line, a DECIDED or REJECTED row included:
the `owner` line quotes the words and the time, the `jev` line names the
row it cleared, and the receipt holds the scores. rules.md stays frozen;
lead-1 tags the entry `DRn ok · owner changed DECIDED 4` at the review
and the close's CHANGED table carries the ruling: the word clears the
line as long as it is logged in the decision record.

## Rules

1. **Append-only.** Never edit an entry's lines after writing them; a
   later entry says `(supersedes DR3)` on its `decided` line. The only
   lines written later are `review` (lead-1), `jev` (the hook) and
   `goal amended` (lead-1, rule 2). A new entry goes at the end of the
   file, through `record-add.sh`.
2. **Header first.** The first write of the file is the header:
   `# <lane> rung <n> · decision record · <IC>`, then `goal: <the
   brief's goal, verbatim>`, `rules: <sha>` (the approval sha from
   `writing-a-design-spec` step 5) and `plan: <path>`. No entry before the header; no header before "spec ok".
   The `goal:` line is never rewritten. When the brief's goal is amended
   after the header (`brief-grilling` step 7), lead-1 adds a line directly
   under it: `goal amended <date time>: <the brief's new goal,
   verbatim>  [<the ruling, verbatim, venue>]`, and tells the IC. A later
   amendment adds another such line under the last one; the newest is the goal in force.
3. **One act per entry.** Two decisions are two entries. A decision
   with two `undo` commands is two decisions or one one-way act.
4. **Numbers from the record, not from memory.** `DR<n>` is the next
   number in the file. `record-add.sh` reads it; a number written in the
   body must agree.
5. **Plain words.** The entry is read by someone who does not know the
   lane: no bare id without its meaning, no "as discussed". The `plan`
   and `question` lines are why the entry exists: a reader who has not
   opened the plan sees what it said, what it left to the IC and why
   the IC went beyond it. The `decided`
   line names things as the spec's `## Terms` block does
   (writing-a-design-spec, One name per thing).
6. **A spec amendment gets one entry.** The spec's `## Amendments` line
   cites only what the team can open; the fleet link lives here. The
   entry's `decided` names the amendment line by its date and first
   words (`2026-09-20 "the wait runs on schedule_at()"`), `because`
   names the card or STOP report that raised it, and the `owner` line
   quotes the owner's word when a frozen rule changed. lead-1's rules.md
   or gate.md amendment for the same change cites this DR as its reason.

## Red flags, stop and fix

- An entry written after the commit it describes.
- `undo` reading "revert the changes" or "n/a".
- `because` restating `decided` instead of naming a fact.
- An `owner` line on a two-way entry (it reads as cover), or missing on
  marking a PR ready, a merge, a push to main or the default branch, a
  force push, a deploy outside the sandbox, a third sandbox run or a
  shared write.
- A push or draft PR entry whose `because` names no receipt, or a
  receipt that is not at HEAD or has a red line.
- A third re-run of the same gate line, or a "sandbox 3 of 2".
- A `review` line written by the IC.
- An entry added with Edit or Write, or anywhere but the end of the file:
  `record-add.sh` writes every DR and UAT entry.
- A spec `## Amendments` line with no DR naming it, or a DR that names
  no card or STOP report as its source.
- rules.md, gate.md or frozen.sha256 edited by the IC, or by lead-1
  without `shared/amend-frozen.sh`.
- A DR for every task of the plan: the plan already decided those.
- A record folder inside a repo, a worktree or AgentMgmt.

| Excuse | Reality |
|---|---|
| "I'll write the entries at the STOP, from memory" | The entry is the thinking as it happened. One rung reached STOP 21 on prose claims nobody could trace. |
| "It is a tiny choice, nobody will ask" | Then `because` is one line and costs nothing. If someone asks in six months, this is the only place the answer lives. |
| "The Jev line said rework but the rule is wrong" | Then the rule is a card to the owner. The act waits; the record keeps the attempt. |
| "The owner said yes in the lead-1 pane" | The word for a one-way act is typed in this pane (gate block). Ask here, quote it here. |

## Example

`templates/decision-record.md` carries the invented lane atlas / ATL-42
rung 1: the header, two two-way DRs, a UAT entry, the push and draft
PR entries at a green receipt, lead-1's audit after the push, and a
one-way DR with the owner's word (marking the PR ready). Copy the shape,
replace every value.
