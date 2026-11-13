#!/bin/bash
# UserPromptSubmit hook, no matcher: runs when a prompt is submitted in any
# session on this machine (installed at user level, like state-gate.sh). For
# an IC, it touches ~/.fleet-agent-mgmt/checks/<name>/.last-prompt: the owner
# or lead-1 wrote in the pane. state-gate.sh bounces the turn once when that
# marker is newer than STATE.md, so a ruling or a direction that no commit
# follows still reaches STATE.md.
#   an IC   (cwd, or its git top level, is an IC's roster row): the marker,
#           only when the folder <checks>/<name>/ already exists
#   lead-1, solo: nothing
# The roster row is found by state-gate.sh's own roster_name(), read from
# that file at run time, so the gate and this hook resolve the same name.
# Always exits 0 and prints nothing: stdout of this hook is added to the
# model's context, and a prompt is never blocked. Pure bash + git + jq; a run
# costs tens of ms, most of it the start-up of those processes.
# Overrides, for tests: FLEET_ROSTER, STATE_CHECKS (as the gate),
# FLEET_STATE_GATE (where roster_name() is read from).
mark() {
  local roster checks gate in cwd name row
  local here; here="$(cd -P "$(dirname "$0")" && pwd)"; . "$here/../lib/paths.sh"
  roster="${FLEET_ROSTER:-$FLEET_HOME/roster.md}"
  checks="${STATE_CHECKS:-$FLEET_HOME/checks}"
  gate="${FLEET_STATE_GATE:-$(dirname "$0")/state-gate.sh}"
  in="$(cat 2>/dev/null || true)"
  cwd="$(printf '%s' "$in" | jq -r '.cwd // empty' 2>/dev/null)"
  cwd="$(cd "${cwd:-$PWD}" 2>/dev/null && pwd -P)" || return 0
  eval "$(sed -n '/^roster_name() {$/,/^}$/p' "$gate" 2>/dev/null)"
  declare -F roster_name >/dev/null || return 0
  IFS=$'\t' read -r name row < <(roster_name "$cwd" "$roster")
  [ -n "$name" ] && [ "$name" != "lead-1" ] || return 0
  [ -d "$checks/$name" ] || return 0
  touch "$checks/$name/.last-prompt"
}
( mark "$@" ) >/dev/null 2>&1
exit 0
