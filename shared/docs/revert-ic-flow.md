# Reverting the autonomous IC flow

Three levers, from the smallest to the full rollback. Try them in this
order; most of the time the first one is enough.

| LEVER | WHAT                    | REACH          | CHANGE                               | RESULT                                    |
|-------|-------------------------|----------------|--------------------------------------|-------------------------------------------|
| 1     | the handoff's MODE line | one rung       | none                                 | the IC stops after every task             |
| 2     | the dr-check hook       | every IC       | one entry in shared/launch/ic-settings.json | no Jev check; the record is still written |
| 3     | git revert, two commits | the whole flow | shared/ back to the tag pre-retros-r | the ICs as before the flow                |

The ICs load hooks by path from shared/ at every launch, so levers 2 and 3
reach a running IC only after a restart.

## 1. One rung back to per-task STOPs

In the handoff, before the IC starts:

```
  mode   per-task STOPs, from <lane> r<n> close
```

The IC sends a STOP after every task in the plan and holds. The decision
record, the Jev check and the gate receipt still run. This is the same mode
the band sets after a 3+ rung, so nothing is new to the IC.

- Done when: the IC's first message after the spec is a STOP, not a commit.
- Undo: `mode   autonomous` on the next handoff.

## 2. Switch the Jev check off

Remove the dr-check.sh block from shared/launch/ic-settings.json: the PostToolUse
entry whose matcher is `Write|Edit|MultiEdit`. The entries for skill-boot,
skill-mark, artefact-gate, message-gate and stop-skill-gate stay; they
predate this flow.

```
  ✗ delete dr-check.sh or dr_check.py      the settings still name them; every write errors
  ✓ remove the hook entry, restart the IC   the IC writes DRs with no jev line; lead-1 reads rules.md at review
```

Then restart each IC:

```
  tmux kill-session -t <ic name>
  shared/launch/agent-up.sh <ic name> --resume
```

- Done when: a new DR entry lands with no `jev` line and no receipt under receipts/.
- Undo: put the block back (it is in git at main), restart.

## 3. Full rollback

Two reverts, in this order. Reverting the merge first conflicts on
skill-boot.sh, because the later commit touched it.

```
  cd "$FLEET_REPO"
  git revert 81bd031                 the lead-1 skill gates (drafting-handoff, the 15-line rule)
  git revert -m 1 daa3e94            the merge: hooks, skills, settings, foundations
```

Proven clean on a throwaway worktree of main: after both reverts, the only
difference from the tag `pre-retros-r` under shared/ is roster.md, which
carries the fleet log and must stay.

```
  ✗ git reset --hard pre-retros-r      drops lead-1's ledger commits and the roster rows since
  ✓ two reverts                        history kept; the roster and the ledger untouched
```

Then the skill links. Three skills exist only in the merged tree; their
links under ~/.claude/skills dangle after the revert:

```
  rm ~/.claude/skills/brief-grilling ~/.claude/skills/recording-a-decision ~/.claude/skills/recording-evidence
```

The other eight links point at directories that exist in both trees and
need no change. Restart every IC and lead-1 as in lever 2.

What the revert does not touch:

| NOT TOUCHED                      | STATE AFTER THE REVERT                                           |
|----------------------------------|------------------------------------------------------------------|
| $FLEET_HOME/records/     | stays; nothing reads it after the revert                         |
| ~/.config/stop-triage/env        | the Jev key; unused, left in place                               |
| $FLEET_HOME/checks/<ic>/ | markers and STATE; the next launch clears what it needs          |
| Leads/lead-1/handoffs/           | handoffs already written keep their MODE line; the IC ignores it |

- Done when: `git diff pre-retros-r main -- shared/` shows roster.md only, and `ls -l ~/.claude/skills` shows no dangling link.
- Undo: `git revert` the two revert commits, in reverse order; relink the three skills.

## What this guide proves

**Proves**
- The two reverts apply cleanly in that order, on the tree as of commit 86cb9ba.

**Does not prove**
- That a later commit to shared/ keeps it clean. Re-run the dry run in a throwaway worktree before reverting for real.

**Out of scope**
- Rolling back a rung's code in its project repo. That is the rung's own `undo` lines in decision-record.md.
