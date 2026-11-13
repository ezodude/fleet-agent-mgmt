#!/bin/bash
# Read-only fleet audit. Checks every roster row against the filesystem, git,
# tmux and the conventions in Leads/shared/CHARTER-lead.md, and prints one
# line per finding:  OK | WARN | FAIL  <row>: <what>.
# Exit 1 if any FAIL, 0 otherwise. Changes nothing. `fleet-fix.sh` repairs
# what this flags as fixable.
#
# Conventions checked (charter "Worktree layout", "Fleet provisioning"):
#   - row dir exists and is a registered git worktree, not prunable
#   - it lives at <repo>/.claude/worktrees/<name>, never a sibling dir
#   - .claude/ is ignored in that repo (tracked .gitignore or info/exclude)
#   - the standing IC layer reaches the worktree: CLAUDE.local.md linked in
#     where the repo root has one; .claude/settings.json is NOT a symlink to a
#     repo worker-settings.json (retired 2026-09-10: the IC pin is
#     shared/launch/ic-settings.json on the agent-up.sh launch line)
#   - the repo has a setup-worker-worktrees.sh (provisioning is scripted)
#   - extra flags (--plugin-dir) point at existing dirs
#   - tmux: every live session is a roster row
#   - roster hygiene: tab-separated rows, unique names, *-ic, *-ic-N or lead-* names
#   - shared/: no unreferenced files
#   - hooks: shared/tests/test-hooks.sh passes (the compaction hooks e2e)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/paths.sh"
ROSTER="${ROSTER:-$FLEET_HOME/roster.md}"   # override for tests
ok=0; warn=0; fail=0
say() { case "$1" in OK) ok=$((ok+1));; WARN) warn=$((warn+1));; FAIL) fail=$((fail+1));; esac; printf '%-4s %s\n' "$1" "$2"; }

rows() { awk '/^```fleet/{f=1;next} /^```/{f=0} f && NF>=1' "$ROSTER"; }

# repo root for a worktree dir: the parent of its .git common dir
repo_of() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##'; }

# --- roster hygiene ---------------------------------------------------------
names=()
while IFS= read -r line; do
  nf=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
  n="$(printf '%s' "$line" | cut -f1)"
  if [ "$nf" -lt 2 ] || [ "$nf" -gt 3 ]; then say FAIL "roster: row '$n' has $nf tab-separated fields (need 2 or 3)"; fi
  case "$n" in lead-*|*-ic|*-ic-[0-9]) ;; *) say WARN "roster: name '$n' is not lead-*, *-ic or *-ic-N";; esac
  for seen in "${names[@]:-}"; do [ "$seen" = "$n" ] && say FAIL "roster: duplicate row '$n'"; done
  names+=("$n")
done < <(rows)

# --- per row ----------------------------------------------------------------
while IFS=$'\t' read -r n dir extra; do
  [ -n "$n" ] || continue
  if [ ! -d "$dir" ]; then say FAIL "$n: directory missing: $dir"; continue; fi

  if [ "$n" = "lead-1" ]; then
    [ -f "$dir/CLAUDE.md" ] && say OK "$n: dir + CLAUDE.md" || say FAIL "$n: no CLAUDE.md in $dir"
    continue
  fi

  repo="$(repo_of "$dir")"
  if [ -z "$repo" ] || [ ! -d "$repo/.git" ]; then say FAIL "$n: not a git worktree: $dir"; continue; fi

  # registered, not prunable
  if git -C "$repo" worktree list --porcelain | grep -qxF "worktree $dir"; then
    if git -C "$repo" worktree list | grep -F "$dir" | grep -q prunable; then say FAIL "$n: worktree registered but PRUNABLE"; else say OK "$n: worktree $(git -C "$dir" rev-parse --short HEAD) $(git -C "$dir" rev-parse --abbrev-ref HEAD)"; fi
  else
    say FAIL "$n: dir exists but is not a registered worktree of $repo"
  fi

  # layout
  base="$(basename "$dir")"
  [ "$dir" = "$repo/.claude/worktrees/$base" ] && say OK "$n: layout <repo>/.claude/worktrees/$base" || say FAIL "$n: worktree not under $repo/.claude/worktrees/ (charter)"
  # pinned name: worktree basename == row name (roster "Naming", 2026-09-10)
  case "$n" in dbx-*) [ "$base" = "$n" ] && say OK "$n: worktree basename == row name" || say WARN "$n: worktree basename '$base' != row name (roster Naming: dbx rows are pinned path = name)";; esac

  # ignore rule
  git -C "$repo" check-ignore -q ".claude/worktrees/$base" && say OK "$n: .claude/ ignored in $(basename "$repo")" || say FAIL "$n: .claude/worktrees NOT ignored in $repo"

  # standing IC layer
  if [ -f "$repo/CLAUDE.local.md" ]; then
    [ -e "$dir/CLAUDE.local.md" ] && say OK "$n: CLAUDE.local.md present" || say WARN "$n: repo has CLAUDE.local.md but the worktree does not (fixable: symlink)"
  fi
  if [ -L "$dir/.claude/settings.json" ] && [[ "$(readlink "$dir/.claude/settings.json")" == *worker-settings.json ]]; then
    say WARN "$n: .claude/settings.json still symlinks worker-settings.json (retired; fixable: rm)"
  else
    say OK "$n: .claude/settings.json not pinned by symlink"
  fi
  if [ -f "$repo/scripts/setup-worker-worktrees.sh" ] || [ -f "$repo/.claude/scripts/setup-worker-worktrees.sh" ]; then
    say OK "$n: provisioning script present"
  else
    say WARN "$n: no setup-worker-worktrees.sh in $(basename "$repo") (provisioning by hand)"
  fi
  if [ ! -f "$dir/CLAUDE.md" ] && [ ! -f "$dir/AGENTS.md" ] && [ ! -f "$dir/README.md" ]; then
    say WARN "$n: no tracked instruction file (CLAUDE.md / AGENTS.md / README.md) at the worktree root"
  fi

  # extra flags
  if [ -n "${extra:-}" ]; then
    pd="$(printf '%s' "$extra" | sed -n 's/.*--plugin-dir[ =]\([^ ]*\).*/\1/p')"
    if [ -n "$pd" ]; then [ -d "$pd" ] && say OK "$n: --plugin-dir exists" || say FAIL "$n: --plugin-dir missing: $pd"; fi
  fi
done < <(rows)

# --- per repo: prunable entries --------------------------------------------
for repo in $(rows | cut -f2 | while read -r d; do [ -d "$d" ] && repo_of "$d"; done | sort -u); do
  [ -d "$repo/.git" ] || continue
  p="$(git -C "$repo" worktree prune --dry-run 2>&1)"
  [ -n "$p" ] && say WARN "$(basename "$repo"): prunable worktree entries (fixable: git worktree prune): $(printf '%s' "$p" | head -1)"
done

# --- tmux --------------------------------------------------------------------
if command -v tmux >/dev/null && tmux ls >/dev/null 2>&1; then
  for s in $(tmux ls -F '#S'); do
    rows | cut -f1 | grep -qx "$s" && say OK "tmux: $s is a roster row" || say WARN "tmux: session '$s' is not in the roster"
  done
fi

# --- shared/: orphans --------------------------------------------------------
# The scripts inside the groups (launch records ledger fleet) and any file left at the top of shared/.
for f in "$HERE"/../launch/* "$HERE"/../records/* "$HERE"/../ledger/* "$HERE"/../fleet/* "$HERE"/../*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  rel="${f#"$HERE"/../}"
  case "$b" in roster.md|agent-up.sh|fleet-audit.sh|fleet-fix.sh) continue;; esac
  grep -rqF "$b" "$HERE/.." "$FLEET_HOME/Leads/shared" 2>/dev/null --exclude="$b" && continue
  say WARN "shared/$rel: not referenced by the roster, the launcher or the charter (orphan?)"
done

# --- hooks: the compaction-hooks e2e test ------------------------------------
if [ -x "$HERE/../tests/test-hooks.sh" ]; then
  hs="$("$HERE/../tests/test-hooks.sh" 2>/dev/null | tail -1)"
  case "$hs" in *", 0 fail") say OK "hooks: $hs";; *) say FAIL "hooks: ${hs:-test-hooks.sh did not run} (run shared/tests/test-hooks.sh for the cases)";; esac
else
  say FAIL "hooks: shared/tests/test-hooks.sh missing or not executable"
fi

echo
echo "ok=$ok warn=$warn fail=$fail"
[ "$fail" -eq 0 ]
