#!/bin/bash
# Shared by the skill hooks. Sourced, never run. Resolves the session's role
# from FLEET_HOME/roster.md (lead-1 row = lead, other row = ic, no row = solo) and
# the marker directory for this session. Markers: one empty file per skill
# invoked this session, under $CHECKS/<name>/skills/<session id>/.
. "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/paths.sh"
ROSTER="${FLEET_ROSTER:-$FLEET_HOME/roster.md}"
CHECKS="${STATE_CHECKS:-$FLEET_HOME/checks}"
IN="$(cat 2>/dev/null || true)"
j() { printf '%s' "$IN" | jq -r "$1 // empty" 2>/dev/null; }
SID="$(j '.session_id')"; SID="${SID:-nosession}"
cwd="$(j '.cwd')"; cwd="$(cd "${cwd:-$PWD}" 2>/dev/null && pwd -P)" || cwd=""
NAME=""; ROLE="solo"
while IFS=$'\t' read -r n d _; do
  [ -n "$d" ] || continue
  if [ "$(cd "$d" 2>/dev/null && pwd -P)" = "$cwd" ]; then NAME="$n"; break; fi
done < <(sed -n '/^```fleet$/,/^```$/p' "$ROSTER" 2>/dev/null | sed '1d;$d')
[ -n "$NAME" ] && ROLE="ic"
[ "$NAME" = "lead-1" ] && ROLE="lead"
MARKS="$CHECKS/$NAME/skills/$SID"
SKILLS_ROOT="${FLEET_SKILLS:-$FLEET_REPO/shared/skills}"
# A marker is stale when any file under the skill's dir or under foundations/
# is newer than it: the skill changed after this session read it (lead-1
# once sent a card in the old shape 15 minutes after the template commit,
# its marker from the day before). Markers with no skill dir
# (agent-haiku) cannot go stale.
stale_file() {  # prints the newest file that outdates the marker, or nothing
  [ -f "$MARKS/$1" ] && [ -d "$SKILLS_ROOT/$1" ] || return 0
  find "$SKILLS_ROOT/$1" "$SKILLS_ROOT/foundations" -type f -newer "$MARKS/$1" 2>/dev/null | head -1
}
has() { [ -f "$MARKS/$1" ] && [ -z "$(stale_file "$1")" ]; }
why() {  # the reason a gate names for a skill has() rejected
  if [ -f "$MARKS/$1" ]; then printf 'changed since this session read it (%s)' "$(stale_file "$1")"
  else printf 'not invoked this session'; fi
}
