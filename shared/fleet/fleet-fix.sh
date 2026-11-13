#!/bin/bash
# Applies the repairs `fleet-audit.sh` marks fixable. Idempotent: a second run
# changes nothing. Prints every action. `--dry-run` prints without acting.
#
# Fixes:
#   - missing worktree dir      -> git worktree add --detach <dir> origin/main (or main)
#   - prunable worktree entries -> git worktree prune
#   - CLAUDE.local.md at repo root, absent in worktree -> relative symlink
#   - .claude/settings.json symlinked to a repo worker-settings.json -> rm (retired 2026-09-10:
#     the IC pin is shared/launch/ic-settings.json on the agent-up.sh launch line)
#   - .claude/ not ignored      -> append `.claude/` to .git/info/exclude (never the tracked .gitignore)
# Never touches: git state of an existing worktree, tmux sessions, the roster,
# tracked files, the charter, shared/ orphans. Those are a human's call and are
# listed at the end.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/paths.sh"
ROSTER="${ROSTER:-$FLEET_HOME/roster.md}"   # override for tests
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" -eq 1 ]; then echo "would: $*"; else echo "do:    $*"; "$@"; fi; }

rows() { awk '/^```fleet/{f=1;next} /^```/{f=0} f && NF>=2' "$ROSTER"; }
repo_of() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##'; }
manual=()

while IFS=$'\t' read -r n dir extra; do
  [ "$n" = "lead-1" ] && continue
  base="$(basename "$dir")"
  # the charter layout lets the repo be derived from the row itself
  repo="${dir%/.claude/worktrees/$base}"
  if [ "$repo" = "$dir" ] || [ ! -d "$repo/.git" ]; then manual+=("$n: dir is not <repo>/.claude/worktrees/<name>, cannot derive the repo: $dir"); continue; fi

  # 1. ignore rule first, so a new worktree never shows as untracked
  if ! git -C "$repo" check-ignore -q ".claude/worktrees/$base"; then
    ex="$repo/.git/info/exclude"
    run sh -c "echo '.claude/' >> '$ex'"
  fi

  # 2. prune dead entries before adding
  if [ -n "$(git -C "$repo" worktree prune --dry-run 2>&1)" ]; then run git -C "$repo" worktree prune; fi

  # 3. missing worktree
  if [ ! -d "$dir" ]; then
    if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
      run git -C "$repo" fetch -q origin
      run git -C "$repo" worktree add --detach "$dir" origin/main
    else
      run git -C "$repo" worktree add --detach "$dir" main
    fi
  elif ! git -C "$repo" worktree list --porcelain | grep -qxF "worktree $dir"; then
    manual+=("$n: $dir exists but is not a registered worktree of $repo (move it aside, then re-run)")
    continue
  fi

  # 4. standing IC layer
  if [ -f "$repo/CLAUDE.local.md" ] && [ ! -e "$dir/CLAUDE.local.md" ]; then
    run ln -sfn ../../../CLAUDE.local.md "$dir/CLAUDE.local.md"
  fi
  if [ -L "$dir/.claude/settings.json" ] && [[ "$(readlink "$dir/.claude/settings.json")" == *worker-settings.json ]]; then
    run rm "$dir/.claude/settings.json"
  fi

  # 5. things only a human should do
  if [ -n "${extra:-}" ]; then
    pd="$(printf '%s' "$extra" | sed -n 's/.*--plugin-dir[ =]\([^ ]*\).*/\1/p')"
    [ -n "$pd" ] && [ ! -d "$pd" ] && manual+=("$n: --plugin-dir missing: $pd")
  fi
  if [ ! -f "$repo/scripts/setup-worker-worktrees.sh" ] && [ ! -f "$repo/.claude/scripts/setup-worker-worktrees.sh" ]; then
    manual+=("$(basename "$repo"): no setup-worker-worktrees.sh (copy another repo's variant into .claude/scripts/)")
  fi
done < <(rows)

if command -v tmux >/dev/null && tmux ls >/dev/null 2>&1; then
  for s in $(tmux ls -F '#S'); do rows | cut -f1 | grep -qx "$s" || manual+=("tmux: session '$s' is not a roster row (kill it or add a row)"); done
fi

if [ "${#manual[@]}" -gt 0 ]; then
  echo
  echo "needs a human:"
  for m in "${manual[@]}"; do echo "  - $m"; done
fi
echo
echo "re-audit: $HERE/fleet-audit.sh"
