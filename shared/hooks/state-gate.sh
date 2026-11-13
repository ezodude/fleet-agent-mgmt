#!/bin/bash
# Stop hook, no matcher: runs at the end of EVERY turn of every session on
# this machine (installed at user level). The gate: a turn may not end while
# the session's durable STATE is older than its newest commit.
#   lead-1 (cwd = the lead-1 roster row): STATE = the ```state block at the
#           top of LEDGER.md; a newest commit in the lead's own folder that
#           itself touched LEDGER.md passes (the state was written in that
#           commit); otherwise stale when that commit is newer than the file.
#           A commit elsewhere in the same repo (a worker's) does not count.
#   an IC  (cwd = any other roster row): STATE = $FLEET_HOME/checks/<name>/STATE.md,
#           outside the repo; missing counts as stale.
#   solo   (no roster row): no gate, exit 0.
# The roster row is matched by the cwd itself first, then by the cwd's git
# top level, so a sub-folder of an IC's worktree is gated too (roster_name()).
# Shape, checked first: the block holds only the 15 schema keys, each once,
# each line at most 400 characters (lead: inside the ```state fence; IC: the
# file above a "## log" heading), and the awaiting line opens with none,
# owner:, lead-1: or a roster name (see shape()). Older text goes under
# "## log", word for word, one "- " bullet per line; the gate never reads it.
# Stale or misshapen -> exit 2 with the instruction on stderr, which Claude Code hands to
# the session as its next input. Bounces ONCE: when stop_hook_active is true
# the turn is already a bounce and the gate lets it end (the harness caps at
# 8 anyway). Pure bash + git + jq; a run costs tens of ms, most of it the
# start-up of those processes.
# IC only, after the commit check: when the owner or lead-1 wrote in the pane
# since STATE.md was last written (prompt-mark.sh, a UserPromptSubmit hook,
# touches <checks>/<name>/.last-prompt), the turn bounces once, so a ruling
# or a direction with no commit after it still reaches STATE.md.
# Every pass of a named session is logged: one line "<utc> pass <session>" in
# <checks>/<session>/state-gate.log, only when that folder exists (the gate
# never creates a session folder).
set -u
. "$(cd -P "$(dirname "$0")" && pwd)/../lib/paths.sh"
ROSTER="${FLEET_ROSTER:-$FLEET_HOME/roster.md}"
CHECKS="${STATE_CHECKS:-$FLEET_HOME/checks}"
SCHEMA="$FLEET_REPO/shared/hooks/STATE-schema.md"
IN="$(cat 2>/dev/null || true)"
active="$(printf '%s' "$IN" | jq -r '.stop_hook_active // false' 2>/dev/null)"
[ "$active" = "true" ] && exit 0
cwd="$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)"
cwd="$(cd "${cwd:-$PWD}" 2>/dev/null && pwd -P)" || exit 0

# One line per fault: a line that is not one of the 15 keys, a repeated key,
# a line over 400 characters, an "awaiting:" line that does not open with
# one of its four forms. $2 lead: the ```state fence only; ic: the file
# above "## log", fence lines skipped.
# awaiting: the value is "none" and nothing else, or "<who>: <text>" where
# <who> is owner, lead-1 or a name from the roster's ```fleet block and
# <text> is not empty; a line naming owner: with others opens with owner:.
# After any other opening, the owner named again with a colon, by "owner" or
# by the name on the roster's **owner: <name>** line, in any case, is a
# fault; so is any other opening when that name cannot be read.
# The roster is read here, not from the caller: fleet-check.sh evals this
# function alone.
shape() {
  local roster="${FLEET_ROSTER:-$FLEET_HOME/roster.md}" names oname
  names="$(sed -n '/^```fleet$/,/^```$/p' "$roster" 2>/dev/null | sed '1d;$d' | cut -f1 | tr '\n' ' ')"
  oname="$(sed -n 's/^\*\*owner: \([^*]*[^* ]\) *\*\*.*/\1/p' "$roster" 2>/dev/null | head -1)"
  awk -v mode="$2" -v names="$names" -v roster="$roster" -v oname="$oname" '
    BEGIN { n = split("session role rung handoff repo branch head pushed dirty stop awaiting notice next updated evidence", K, " ")
            for (i = 1; i <= n; i++) ok[K[i]] = 1
            split(names, N, " "); for (i in N) who_ok[N[i]] = 1; who_ok["owner"] = 1; who_ok["lead-1"] = 1
            lo = tolower(oname)
            rule = "open it with none (the whole value), owner:, lead-1: or a roster name and a colon, then the text; when the owner is one of several, owner: goes first" }
    mode == "lead" { if ($0 == "```state") { inb = 1; next }; if (!inb) next; if ($0 == "```") exit }
    mode == "ic"   { if ($0 ~ /^## log/) exit; if ($0 ~ /^```/) next }
    /^[[:space:]]*$/ || /^#/ { next }
    { k = $0; sub(/:.*/, "", k)
      if (index($0, ":") == 0 || !(k in ok)) { printf "line %d is not one of the 15 keys: %s\n", NR, substr($0, 1, 60); next }
      if (k in seen) printf "line %d repeats \"%s\" (first at line %d)\n", NR, k, seen[k]; else seen[k] = NR
      if (length($0) > 400) printf "line %d \"%s\" is %d characters, over 400\n", NR, k, length($0)
      if (k == "awaiting") await(substr($0, 10), NR) }
    function await(v, nr,   who, hit) {
      sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
      if (v == "none") return
      who = v; sub(/:.*/, "", who)
      if (!(index(v, ":") && (who in who_ok) && substr(v, length(who) + 2) ~ /^ +[^ \t]/)) {
        printf "line %d \"awaiting\" opens \"%s\": %s%s\n", nr, substr(v, 1, 40), rule, \
          (names == "" ? " (no roster names read from " roster ")" : ""); return }
      if (who == "owner") return
      hit = owner_named(substr(v, length(who) + 2))
      if (hit != "")
        printf "line %d \"awaiting\" names the owner (%s) after %s:, write owner: first, e.g. \"owner: merge the PR; lead-1: the S5 ruling\"\n", nr, hit, who
      else if (lo == "")
        printf "line %d \"awaiting\" opens %s: but no owner name was read from %s (its **owner: <name>** line), so the owner-first rule cannot be checked\n", nr, who, roster
    }
    # The first "owner" or owner name, any case, at a word start and followed
    # by optional blanks and a colon; "" when there is none.
    function owner_named(rest,   s, t, k, p, q, c) {
      s = tolower(rest)
      for (k = 1; k <= 2; k++) {
        t = (k == 1 ? "owner" : lo); if (t == "") continue
        q = 0
        while ((p = index(substr(s, q + 1), t)) > 0) {
          p += q; c = (p == 1 ? " " : substr(s, p - 1, 1))
          if (c !~ /[a-z0-9_-]/ && substr(s, p + length(t)) ~ /^[ \t]*:/) return substr(rest, p, length(t)) ":"
          q = p
        }
      }
      return ""
    }
  ' "$1" 2>/dev/null
}
bounce_shape() {
  local faults; faults="$(shape "$1" "$2")"
  [ -z "$faults" ] && return 0
  { echo "STATE GATE: $1 breaks the state shape:"; printf '%s\n' "$faults" | head -12
    echo "Keep one line per key, saying where things are now. Move older text, word for word, under a \"## log\" heading below the block, one \"- \" bullet per line, a <word> in backticks (schema: $SCHEMA). Then end the turn."
    printf '%s\n' "$faults" | grep -q '"awaiting"' && \
      echo "The awaiting line opens with exactly one of: none | owner: | lead-1: | <roster name>: (a name from the roster's \`\`\`fleet block), free text after; \"none\" is the whole value. Only owner: shows as waiting on the owner, so a line waiting on the owner and others opens owner: (e.g. \"owner: merge the PR; lead-1: the S5 ruling\"); after another opening, the owner named with a colon (owner:, Owner: or their name:) is a fault."; } >&2
  exit 2
}

# "<name><TAB><row dir>" for the roster row of $1 (a resolved path), or
# nothing. The row whose dir is $1 itself wins; else the row whose dir is
# $1's git top level (pwd -P), so a sub-folder of a worktree resolves to the
# worktree's row. lead-1's row is a sub-folder of its own repo, hence the
# exact match first. $2 is the roster. prompt-mark.sh evals this function
# alone, out of this file: keep it self-contained.
roster_name() {
  local top="" n d p hit=""
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" && top="$(cd "$top" 2>/dev/null && pwd -P)" || top=""
  while IFS=$'\t' read -r n d _; do
    [ -n "$d" ] || continue
    p="$(cd "$d" 2>/dev/null && pwd -P)" || continue
    if [ "$p" = "$1" ]; then printf '%s\t%s\n' "$n" "$p"; return 0; fi
    [ -z "$hit" ] && [ -n "$top" ] && [ "$p" = "$top" ] && hit="$(printf '%s\t%s' "$n" "$p")"
  done < <(sed -n '/^```fleet$/,/^```$/p' "$2" 2>/dev/null | sed '1d;$d')
  [ -n "$hit" ] && printf '%s\n' "$hit"
  return 0
}

# A passing named session: log it (only into an existing checks folder), exit 0.
pass_exit() {
  [ -d "$CHECKS/$name" ] && printf '%s pass %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" >> "$CHECKS/$name/state-gate.log" 2>/dev/null
  exit 0
}

name=""; row=""
IFS=$'\t' read -r name row < <(roster_name "$cwd" "$ROSTER")
[ -n "$name" ] || exit 0
cwd="$row"

if [ "$name" = "lead-1" ]; then
  state="$cwd/LEDGER.md"
  grep -q '^```state$' "$state" 2>/dev/null || {
    echo "STATE GATE: $state has no \`\`\`state block at its top. Add it (schema: $SCHEMA), then end the turn." >&2; exit 2; }
  bounce_shape "$state" lead
  # The newest commit touching the lead's own folder includes LEDGER.md -> the state rode in that commit.
  [ "$(git -C "$cwd" log -1 --format=%H -- LEDGER.md 2>/dev/null)" = "$(git -C "$cwd" log -1 --format=%H -- . 2>/dev/null)" ] && pass_exit
  last="$(git -C "$cwd" log -1 --format=%ct -- . 2>/dev/null)"
else
  state="$CHECKS/$name/STATE.md"
  [ -f "$state" ] || {
    echo "STATE GATE: $state is missing. Write it now, 15 lines in a \`\`\`state fence per $SCHEMA (session, rung, handoff, repo, branch, head, pushed, dirty, stop, awaiting, notice, next, updated, evidence), then end the turn." >&2; exit 2; }
  bounce_shape "$state" ic
  last="$(git -C "$cwd" log -1 --format=%ct 2>/dev/null)"
fi
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }
mtime="$(mt "$state")"
if [ -n "$last" ] && [ "${last:-0}" -gt "${mtime:-0}" ]; then
  if [ "$name" = "lead-1" ]; then head="$(git -C "$cwd" log -1 --format='%h %s' -- . 2>/dev/null)"
  else head="$(git -C "$cwd" log -1 --format='%h %s' 2>/dev/null)"; fi
  echo "STATE GATE: $state is older than the newest commit ($head). Update it now (head, pushed, dirty, stop, next, updated; schema: $SCHEMA), then end the turn." >&2
  exit 2
fi
[ "$name" = "lead-1" ] && pass_exit
# IC: the owner or lead-1 wrote in the pane after STATE.md's last write.
mark="$CHECKS/$name/.last-prompt"
if [ -f "$mark" ] && [ "$(mt "$mark")" -gt "${mtime:-0}" ] 2>/dev/null; then
  echo "STATE GATE: the owner (or lead-1) wrote in this pane since $state was last written. If this turn changed what you wait on, what you do next or where you stopped, update stop, awaiting, next and updated now (schema: $SCHEMA); otherwise just touch it (touch $state). Then end the turn." >&2
  exit 2
fi
pass_exit
