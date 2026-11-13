# Migration and rollback

This moves the fleet from the old repo into a reusable clone, with the owner's data copied into the state folder, `FLEET_HOME` (default `$HOME/.fleet-agent-mgmt`). The old repo's path is written `<AgentMgmt>` below: it is the old checkout's path. The clone sits beside it at `$HOME/Projects/fleet-agent-mgmt`. The team keeps running through the move; nothing is moved or deleted in `<AgentMgmt>`, and no step writes into Claude Code's history store.

Where to run: steps 1 to 3 run from a worktree of `<AgentMgmt>` on this branch, never the live checkout (the live checkout stays on main; checking out this branch there breaks every running session, see Landing), before the clone exists, and name the state folder as `"$HOME/.fleet-agent-mgmt"` because `install.sh` has not set `FLEET_HOME` yet. Steps 4 to 7 run from the clone, with `FLEET_HOME` exported as step 4 says.

Every step names its commands, the line that means it passed, and why it is there. A step that does not print its pass line stops the migration. The seven steps run in this order.

## Landing

The code ships to `fleet-agent-mgmt` through `shared/migrate/make-repo.sh` (step 3). This branch is never merged into `<AgentMgmt>`'s main: the user-level Stop hook points at `<AgentMgmt>`'s `shared/hooks/state-gate.sh`, and a merge would move the live launch paths, delete `shared/roster.md` and move `<AgentMgmt>`'s HEAD after the ledger copy, so the running fleet would break and `check-frozen.sh` would fail. The branch stays as `make-repo.sh`'s source until `<AgentMgmt>` is frozen (step 7).

## 1. Wait until no brief is mid-flight

```
shared/board/fleet-board.sh list
```

Pass: the board lists no brief in flight. Why: the cut-over changes hook paths, and a brief running through it would hold the old ones.

## 2. Copy the data, check it, write the owner's three files

```
shared/migrate/copy.sh <AgentMgmt> "$HOME/.fleet-agent-mgmt"
shared/migrate/check-copy.sh "$HOME/.fleet-agent-mgmt"
```

Pass: `N files, 0 missing, 0 differing`. Why: `copy.sh` copies `Leads/` and `lead-ux/` (copy, never move) and records a sha256 manifest and `<AgentMgmt>`'s HEAD; `check-copy.sh` proves the copy matches. It also writes `roster.md` into the state folder, with every row under `<AgentMgmt>/Leads/` or `<AgentMgmt>/lead-ux/` rewritten to the same place in the state folder (so lead-1 starts in `$HOME/.fleet-agent-mgmt/Leads/lead-1`); other rows are kept as they are. `TechLeads/` and `archive/` are not copied: they stay in `<AgentMgmt>`.

Then write three files into the state folder by hand:

```
$EDITOR "$HOME/.fleet-agent-mgmt/legacy-records.txt" "$HOME/.fleet-agent-mgmt/lane-prefixes.txt" "$HOME/.fleet-agent-mgmt/leak-tokens.txt"
```

Pass: the three files exist, one entry per line. Why: they hold the owner's own values, so they live in the state folder and never in the repo.

- `legacy-records.txt` holds the record folders frozen before hash checking, one per line. `shared/records/freeze_rules.py` reads it, beside the repo's own `shared/records/legacy-records.txt`, to skip the hash check on those folders.
- `lane-prefixes.txt` holds the lane names, one per line, lowercase. `shared/board/fleet-board.sh` reads it to recognise `<lane>-N` and `<lane> #N` as ticket keys.
- `leak-tokens.txt` holds the owner's private tokens, one per line. The scan in step 3 and the push gate read it and fail if any token appears.

## 3. Make the clean repo

```
shared/migrate/make-repo.sh "$HOME/Projects/fleet-agent-mgmt"
```

Pass: the command exits 0, prints `owner tokens: 0 hits`, and the folder exists as one commit on `main`. Why: the new repo carries the code without `Leads/`, `TechLeads/`, `lead-ux/` or `archive/`, and no history; `make-repo.sh` runs `shared/tests/test-clean-clone.sh scan` on its own output and exits 1 on a hit. This folder is the clone.

## 4. Install, then check no old path is live

From the clone, rehearse first in a scratch home:

```
cd "$HOME/Projects/fleet-agent-mgmt"
shared/migrate/check-live.sh --rehearsal
```

Pass: `old-repo paths: 0`, `rehearsal lead turn: ok`, `rehearsal launch: ok`. Then install for real, and export the state folder for the steps after:

```
shared/migrate/install.sh --repo "$HOME/Projects/fleet-agent-mgmt"
export FLEET_HOME="$HOME/.fleet-agent-mgmt"
shared/migrate/check-live.sh
```

Pass: `old-repo paths: 0`. Why: `install.sh` writes absolute hook paths and skill links for the clone, sets `FLEET_REPO` and `FLEET_HOME` in the user-level env block, and stamps `$FLEET_HOME/migrate/install-stamp` when the settings change; a wrong path would stop every Claude session on the machine, so the rehearsal comes first.

## 5. The lead relaunches in its new folder

Rehearse the resume first. Start a throwaway session (not the lead) in one folder, then resume it by id from a second folder:

```
claude --resume <throwaway session id>
```

Pass: the throwaway session resumes with its history. A failed rehearsal stops the migration. Then copy the ledger, the last write to `<AgentMgmt>`:

```
shared/migrate/copy.sh --ledger <AgentMgmt> "$FLEET_HOME"
shared/migrate/check-copy.sh "$FLEET_HOME"
```

Pass: `0 missing, 0 differing`. Then end the old lead-1 session (its tmux session, after its last turn) and relaunch the lead through the launcher, with its session id:

```
shared/launch/agent-up.sh lead-1 --resume-id <lead session id>
shared/migrate/check-cutover.sh lead
```

Pass: `lead-1: resumed <lead session id>`, and after three lead turns `lead: ok`. Why: the launcher starts the lead in the roster's lead-1 folder (`$FLEET_HOME/Leads/lead-1`, written by step 2) with the lead settings, name, plugin and launch receipt on the line; a bare `claude --resume` would drop all of them. `check-cutover.sh lead` is red unless the roster's lead-1 cwd is that folder. Claude Code finds a session id across project folders when one copy exists, so nothing is copied into its history store.

## 6. Each worker relaunches at its close

Each worker relaunches in its new folder when its ticket closes, through `shared/launch/agent-up.sh <name>`; until then it keeps its old paths, which still work.

```
shared/migrate/check-cutover.sh worker
```

Pass: `worker: ok`. Why: a relaunched worker writes its receipt under the new paths.

## 7. Freeze the old repo

When every worker has moved, make the old ledger read-only, then check:

```
chmod a-w <AgentMgmt>/Leads/lead-1/LEDGER.md
shared/migrate/check-frozen.sh
```

Pass: `frozen: ok` and `old ledger: read-only`. Why: `<AgentMgmt>` is now the archive; its HEAD and tree equal what was recorded at the ledger copy.

## Rollback

```
shared/migrate/install.sh --repo <AgentMgmt>
shared/migrate/check-live.sh --rolled-back
```

Pass: `new-repo paths: 0`. Why: this points the user-level hooks and skill links back at `<AgentMgmt>`; the lead resumes there, and the copy stays in `FLEET_HOME`. `--rolled-back` proves the rollback in a scratch home; run `shared/migrate/check-live.sh` with no flag against the live home to confirm it there.
