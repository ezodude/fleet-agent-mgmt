#!/bin/bash
# Shaping session launcher, a sibling of agent-up.sh with no roster row and no
# fleet hooks. `shape-up.sh <idea>` makes ~/.fleet-agent-mgmt/shaping/<idea>/,
# copies the session map (shared/launch/shaping/session-map.md) into it as CLAUDE.md, and starts
# `claude` there in a detached tmux session `shape-<idea>` whose first line is
# "boot". It never attaches: it prints the attach line. Every launch lists the
# shaping folders already there, so a stale one is seen.
# `shape-up.sh --done <idea>` deletes the folder whenever no tmux session
# shape-<idea> is running, and prints what it deleted. --done is typed on
# purpose, so a throwaway run with no "brief ok" stamp goes too.
# User data stays out of this repo: the folders live under the fleet home
# (FLEET_HOME, default ~/.fleet-agent-mgmt).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/paths.sh"
ROOT="$FLEET_HOME/shaping"
usage() { echo "usage: shape-up.sh <idea> | --done <idea>   (idea: a-z 0-9 -)"; exit 2; }
DONE=""; [ "${1:-}" = "--done" ] && { DONE=1; shift; }
IDEA="${1:-}"; [ $# -eq 1 ] || usage
[[ "$IDEA" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage
DIR="$ROOT/$IDEA"; S="shape-$IDEA"

if [ -n "$DONE" ]; then
  [ -d "$DIR" ] || { echo "$IDEA: no shaping folder $DIR"; exit 1; }
  tmux has-session -t "=$S" 2>/dev/null && { echo "$IDEA: $S still running; kill it first (tmux kill-session -t $S); folder kept"; exit 1; }
  files="$(cd "$DIR" && find . -mindepth 1 | sed 's|^\./||' | sort)"
  rm -rf "$DIR" || exit 1
  echo "$IDEA: deleted $DIR"; [ -z "$files" ] || printf '%s\n' "$files" | sed 's/^/  /'; exit 0
fi

command -v tmux >/dev/null || { echo "tmux not found (brew install tmux)"; exit 1; }
command -v claude >/dev/null || { echo "claude not found on PATH"; exit 1; }
open="$(ls -1 "$ROOT" 2>/dev/null | grep -v -x -F "$IDEA")"
[ -z "$open" ] || { echo "shaping folders already there:"; printf '  %s\n' $open; }
if tmux has-session -t "=$S" 2>/dev/null; then echo "$S: already running (attach: tmux attach -t $S)"; exit 0; fi
mkdir -p "$DIR" && cp "$HERE/shaping/session-map.md" "$DIR/CLAUDE.md" || exit 1
tmux new-session -d -s "$S" -c "$DIR" "FLEET_REPO=$(printf '%q' "$FLEET_REPO") FLEET_HOME=$(printf '%q' "$FLEET_HOME") claude -n $S --permission-mode auto --settings $(printf '%q' "$HERE/shape-settings.json") boot"
echo "$S: launched in $DIR (attach: tmux attach -t $S)"
