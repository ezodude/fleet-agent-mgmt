#!/bin/bash
# The fleet check ledger-add.sh runs before it writes any entry. Read-only:
# prints one line per finding, FAIL or WARN, each followed by its fix, then
# "fleet-check: N faults, M warnings". Exit 1 on any FAIL, 0 otherwise.
# ledger-add.sh refuses the entry on exit 1; run it alone to see what it
# would refuse:
#   shared/fleet/fleet-check.sh
#
# FAIL, the entry is refused:
#   a  a record folder records/<project>/<folder>/ has close.md and is not
#      fully committed
#   b  a record folder with any committed file has uncommitted changes
#      (modified or untracked files): a committed record is closed
#   c  profiles/ has untracked or modified files
#   d  a checks/*/STATE.md fails the state gate's shape check (its keys, or
#      an awaiting line that does not open with none, owner:, lead-1: or a
#      roster name), or md-check reports a fault other than "wide"
#   e  a live AgentMgmt file names the old checks folder under ~/.claude
#      (the folder moved to ~/.fleet-agent-mgmt/checks)
# WARN, the entry is still written:
#   an untracked record folder with no close.md whose newest file is over
#   3 days old, unless records/open.txt lists it (one line each:
#   "<project>/<folder>, <reason>"; the bare folder name also matches)
#
# The shape check is state-gate.sh's own shape(), read from that file at run
# time, so the gate and this check cannot drift apart and the live gate is
# not edited. If shape() cannot be read, that is a fault.
#
# Paths, overridable for tests:
#   FLEET_HOME         ~/.fleet-agent-mgmt (a git repo: records/, profiles/, checks/)
#   FLEET_CHECK_SCAN   the AgentMgmt tree scanned for (e)
#   FLEET_CHECK_SKIP   paths (extended regex) (e) does not count: other
#                      worktrees of this repo, test fixtures that record
#                      past runs, and lead-1's retired tickets/ and briefs/
#                      (history: they may not be edited, so they would
#                      refuse every entry for good)
#   FLEET_STATE_GATE   where shape() is read from
#   FLEET_ROSTER       the roster shape() reads the names an awaiting line
#                      may open with, and the owner's name, from (shape()
#                      reads it itself)
#   FLEET_MD_CHECK     the md-check script
set -u
HERE="$(cd -P "$(dirname "$0")" && pwd)"
. "$HERE/../lib/paths.sh"
FH="$FLEET_HOME"
SCAN="${FLEET_CHECK_SCAN:-$FLEET_REPO}"
SKIP="${FLEET_CHECK_SKIP:-/\.claude/worktrees/|/test/fixtures/|/Leads/lead-1/(tickets|briefs)/}"
GATE="${FLEET_STATE_GATE:-$HERE/../hooks/state-gate.sh}"
MDC="${FLEET_MD_CHECK:-$HERE/../records/md-check.sh}"
OLD='.claude/checks'   # the old folder, relative to home; spelled this way so this file does not match (e)
faults=0; warns=0
bad()  { faults=$((faults+1)); printf 'FAIL %s\n     fix: %s\n' "$1" "$2"; }
warn() { warns=$((warns+1));  printf 'WARN %s\n     fix: %s\n' "$1" "$2"; }
g() { git -C "$FH" "$@"; }

# the counts in one "git status --porcelain" listing: "N files not committed (M modified or staged, U untracked)"
counts() {
  local all mod unt w=files
  all=$(printf '%s\n' "$1" | grep -c .); unt=$(printf '%s\n' "$1" | grep -c '^??')
  mod=$((all - unt)); [ "$all" -eq 1 ] && w=file
  printf '%d %s not committed (%d modified or staged, %d untracked)' "$all" "$w" "$mod" "$unt"
}

if ! g rev-parse --git-dir >/dev/null 2>&1; then
  bad "$FH is not a git repo, so records/ and profiles/ cannot be checked" "check FLEET_HOME, or run git init there"
else
  # --- a, b, warn: record folders ---------------------------------------------
  open_list="$FH/records/open.txt"
  for dir in "$FH"/records/*/*/; do
    [ -d "$dir" ] || continue
    dir="${dir%/}"; rel="${dir#"$FH"/}"; folder="${rel#records/}"
    st="$(g status --porcelain=v1 -uall -- "$rel" 2>/dev/null)"
    tracked="$(g ls-files -- "$rel" | head -1)"
    if [ -n "$st" ] && [ -f "$dir/close.md" ]; then
      bad "$rel: has close.md, $(counts "$st")" \
          "git -C $FH add $rel && git -C $FH commit -m \"$folder close\""
    elif [ -n "$st" ] && [ -n "$tracked" ]; then
      bad "$rel: committed record changed since, $(counts "$st")" \
          "a committed record is closed: commit the change (git -C $FH add $rel && git -C $FH commit -m \"$folder follow-up\") or undo it; new work goes in a new folder"
    elif [ -z "$tracked" ] && [ ! -f "$dir/close.md" ]; then
      [ -n "$(find "$dir" -type f -mmin -4320 2>/dev/null | head -1)" ] && continue
      [ -z "$(find "$dir" -type f 2>/dev/null | head -1)" ] && continue
      if [ -f "$open_list" ] && awk -F',' -v a="$folder" -v b="${folder#*/}" '
           { k = $1; gsub(/^[ \t]+|[ \t]+$/, "", k) } k == a || k == b { hit = 1 } END { exit !hit }' "$open_list"; then
        continue
      fi
      warn "$rel: untracked, no close.md, newest file over 3 days old" \
           "close and commit it, or add \"$folder, <reason>\" to $open_list"
    fi
  done

  # --- c: profiles --------------------------------------------------------------
  st="$(g status --porcelain=v1 -uall -- profiles 2>/dev/null)"
  [ -n "$st" ] && bad "profiles/: $(counts "$st")" \
      "git -C $FH add profiles && git -C $FH commit -m \"profiles: <what changed>\""
fi

# --- d: STATE.md shape and md-check --------------------------------------------
states=()
for f in "$FH"/checks/*/STATE.md; do [ -f "$f" ] && states+=("$f"); done
if [ "${#states[@]}" -gt 0 ]; then
  eval "$(sed -n '/^shape() {$/,/^}$/p' "$GATE" 2>/dev/null)"
  if ! declare -F shape >/dev/null; then
    bad "cannot read shape() from $GATE, so no STATE.md was shape-checked" \
        "state-gate.sh changed: make fleet-check.sh read its shape check again"
  else
    for f in "${states[@]}"; do
      s="$(shape "$f" ic)"
      [ -n "$s" ] && bad "${f#"$FH"/}: breaks the state shape: $(printf '%s' "$s" | head -3 | paste -sd ';' -)" \
          "one line per schema key above \"## log\"; awaiting opens with none, owner:, lead-1: or a roster name and a colon, owner: first; older text under \"## log\" as \"- \" bullets (shared/hooks/STATE-schema.md)"
    done
  fi
  md="$(bash "$MDC" "${states[@]}" 2>&1)"; rc=$?
  if [ "$rc" -ge 2 ] || ! printf '%s\n' "$md" | grep -q '^md-check '; then
    bad "md-check did not run on the STATE.md files (exit $rc): $(printf '%s' "$md" | tail -1)" \
        "run shared/records/md-check.sh on them by hand and fix what stops it"
  else
    file=""
    while IFS= read -r line; do
      case "$line" in
        "md-check "*) file="${line#md-check }"; file="${file%%: *}";;
        "  line "*": wide: "*) ;;
        "  line "*) bad "${file#"$FH"/}: md-check ${line#  }" "fix that line (shared/records/md_check.py says how for each fault)";;
      esac
    done <<< "$md"
  fi
fi

# --- e: the old checks path in live files --------------------------------------
hits="$(grep -rlE "(~|\\\$HOME|$HOME)/\\.claude/checks" "$SCAN" --exclude-dir=node_modules --exclude-dir=.git \
          --exclude-dir=TechLeads --exclude-dir=archive --exclude-dir=handoffs 2>/dev/null \
        | grep -v 'Leads/lead-1/LEDGER.md' | grep -vE "$SKIP")"
while IFS= read -r f; do
  [ -n "$f" ] && bad "${f#"$SCAN"/}: names ~/$OLD" "change it to ~/.fleet-agent-mgmt/checks"
done <<< "$hits"

echo "fleet-check: $faults faults, $warns warnings"
[ "$faults" -eq 0 ]
