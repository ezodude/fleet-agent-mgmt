# STATE: the 15 lines a session needs to resume after compaction

One block per session, same keys for lead and IC, plain `key: value`
lines, no prose, fenced as ```state so a markdown viewer shows one line
per key. Written BEFORE anything that changes it lands (a commit,
a STOP, a push, a notice), read FIRST after a compaction by
`postcompact-boot.sh`, and gated by `state-gate.sh` (a turn cannot end
while the block is older than the newest commit; for lead-1 a commit that
includes LEDGER.md is the block's own write and passes; nor while the block
breaks the shape rules below; for an IC, a turn also bounces once when a
prompt arrived in its pane after STATE.md was last written).

Where it lives:

```
  lead-1   the top of Leads/lead-1/LEDGER.md, fenced as ```state (above "## Cross-project linkage")
  an IC    ~/.fleet-agent-mgmt/checks/<roster name>/STATE.md   e.g. ~/.fleet-agent-mgmt/checks/atlas-ic-1/STATE.md
           (outside the repo, per roster name: one session per name at a time; the block names the rung)
           the file opens with the ```state fence, then "## log" below it
  solo     none; no gate
```

The 15 keys, in this order, with an invented example (atlas-ic-1 at 20:58; its
`awaiting` line rewritten in the form below):

```state
session: atlas-ic-1
role: ic
rung: ATL-68 r1, sample re-grounding (Stage A copy, Stage B check loop)
handoff: ~/.fleet-agent-mgmt/records/atlas/atl-68-r1/handoff.md
repo: ~/Projects/atlas/.claude/worktrees/w1
branch: feat/atl-68/reground
head: c8463c0
pushed: no (no upstream)
dirty: 0
stop: STOP 2 reached 2026-09-09 17:05; report SENT to lead-1
awaiting: owner: PR ready and merge; lead-1: ATL-68 S5, S6 (audit after the push)
notice: none
next: green receipt at HEAD and jev audit exit 0: git push -u origin feat/atl-68/reground, then gh pr create --draft, one DR each; no hold
updated: 2026-09-09 20:58 BST (19:58Z)
evidence: ~/.fleet-agent-mgmt/checks/atlas-ic-1/
```

Rules:

- `handoff` is absolute: the boot hook's FIRST ACTION names it.
- `head` is the short SHA of `repo` at the time of writing; `pushed` is
  `yes <remote/branch>` or `no (<why>)`; `dirty` is the `git status --short`
  line count.
- `stop` and `awaiting` say what was SENT and what was NOT sent, by name.
- `awaiting` opens with exactly one of four forms, free text after:

  ```
    none            nothing awaited; the whole value, nothing after it
    owner:          the owner; the only form shown as "waiting on you"
    lead-1:         lead-1
    <roster name>:  a session named in the ```fleet block of $FLEET_HOME/roster.md
  ```

  A colon form is `<who>: <text>`: the colon, a space, then text. A line
  that waits on the owner and others opens `owner:` and names the rest
  after it, so "waiting on both" is written owner-first. After any other
  opening, the owner named again with a colon is a fault: `owner:` in any
  case, or the name on the roster's `**owner: <name>**` line followed by a
  colon (`lead-1: the D3 ruling; Robin: merge` faults when the roster says
  `**owner: Robin**`). The owner named in prose, with no colon after the
  name, is not a wait and passes. Anything else (`nothing`, the owner's own
  name as the opening, `lead-1/<name>:`, `none; ...`) is a shape fault.
  Examples:

  ```
  awaiting: none
  awaiting: owner: "ATL-42 spec ok" on the STOP 1 report sent 10:05
  awaiting: lead-1: ATL-42 D3 ruling (card sent 14:20)
  awaiting: owner: PR #88 ready and merge; lead-1: audit after the push
  ```
- `updated` is read from the clock, local with UTC beside it.
- The gate sees two things: a commit newer than the block, and, for an IC,
  a prompt in its pane (the owner's or lead-1's) newer than STATE.md
  (`prompt-mark.sh` touches `.last-prompt` beside it). On a prompt bounce,
  update stop, awaiting, next and updated if the turn changed them;
  otherwise `touch` the file. A STOP, a send, or an armed notice in a turn
  with neither is not seen: update the block at those moments by rule (the
  rung handoff's required blocks say so).
- lead-1 changes an IC's STATE.md only through `shared/ledger/state-set.sh <ic>
  key="value"`: the old line goes under `## log` as `- superseded <date>:
  <old line>`, and the file's mtime is kept, so the gate still sees the
  IC's own staleness. Since the mtime does not move, an IC changes its
  STATE.md line by line, and reads it again before any rewrite of the whole
  file, so a line lead-1 set is not lost.

Shape, checked by `state-gate.sh` at the end of every turn:

- Each line is one of the 15 keys, each key once: the line says where
  things are now, not how they got there.
- No line is over 400 characters; `md-check.sh`'s "wide" fault (over 160) does not apply inside the block.
- The `awaiting` line opens with one of its four forms (Rules, above); the
  gate reads the roster names and the owner's name from `$FLEET_ROSTER`,
  by default $FLEET_HOME/roster.md; with no `**owner: <name>**` line there, every
  opening but `none` and `owner:` faults. `ledger-add.sh` checks an `awaiting=` value the same way.
- The gate reads lead-1's ```state fence, and an IC's STATE.md down to a
  `## log` heading. Fence lines, blank lines and `#` headings are skipped.

`## log` (IC STATE.md only; lead-1's history is the ledger itself): when a
line's old content still matters (a ruling, a run id, a merge sha), move it
under this heading below the block, word for word, newest last, as a `- `
bullet so a viewer shows each on its own line. A `<word>` in it is written
in backticks, or a viewer drops it as an HTML tag. The gate never reads the
log; the boot hook and the fleet console stop at it. Example:

````
```state
session: atlas-ic
...
next: wait for the owner's "ATL-42 close ok"
updated: 2026-10-22 15:40 BST (14:40Z)
evidence: ~/.fleet-agent-mgmt/records/atlas/atl-42-r1/evidence.md
```

## log
- merged: PR #88 merged 2026-10-22 08:58Z as 7c1e2a9
- rerun: dev deploy re-run 10:38 on the owner's word, success 10:51
- plan: `<record>`/plan.md frozen at 3f0a9b2
````
