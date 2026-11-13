#!/bin/bash
# PostToolUse hook, matcher "Skill|Agent". Records that a skill body was
# loaded this session (marker <skill>), or that a haiku check was dispatched
# (marker agent-haiku). The gates read these. Solo: exit 0. Always exits 0.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "solo" ] && exit 0
tool="$(j '.tool_name')"
mkdir -p "$MARKS"
case "$tool" in
  Skill) s="$(j '.tool_input.skill')"; s="${s##*:}"; [ -n "$s" ] && : > "$MARKS/$s" ;;
  Agent) m="$(j '.tool_input.model')"; [ "$m" = "haiku" ] && : > "$MARKS/agent-haiku" ;;
esac
exit 0
