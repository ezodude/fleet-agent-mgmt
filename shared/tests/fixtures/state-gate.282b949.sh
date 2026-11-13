#!/bin/bash
# Stop hook, no matcher: runs at the end of EVERY turn of every session on
# this machine (installed at user level). The gate: a turn may not end while
# the session's durable STATE is older than its newest commit.
#   lead-1 (cwd = the lead-1 roster row): STATE = the ```state block at the
#           top of LEDGER.md; a HEAD that itself touched LEDGER.md passes
#           (the state was written in that commit); otherwise stale when
#           HEAD is newer than the file.
#   an IC  (cwd = any other roster row): STATE = ~/.fleet-agent-mgmt/checks/<name>/STATE.md,
#           outside the repo; missing counts as stale.
#   solo   (no roster row): no gate, exit 0.
# Shape, checked first: the block holds only the 15 schema keys, each once,
# each line at most 400 characters (lead: inside the ```state fence; IC: the
# file above a "## log" heading), and the awaiting line opens with none,
# owner:, lead-1: or a roster name (see shape()). Older text goes under
# "## log", word for word, one "- " bullet per line; the gate never reads it.
# Stale or misshapen -> exit 2 with the instruction on stderr, which Claude Code hands to
# the session as its next input. Bounces ONCE: when stop_hook_active is true
# the turn is already a bounce and the gate lets it end (the harness caps at
# 8 anyway). Pure bash + git + jq; runs in a few ms.
set -u
ROSTER="${FLEET_ROSTER:-/fixture/shared/roster.md}"
CHECKS="${STATE_CHECKS:-$HOME/.fleet-agent-mgmt/checks}"
SCHEMA="/fixture/shared/hooks/STATE-schema.md"
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
  local roster="${FLEET_ROSTER:-/fixture/shared/roster.md}" names oname
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

name=""
while IFS=$'\t' read -r n d _; do
  [ -n "$d" ] || continue
  if [ "$(cd "$d" 2>/dev/null && pwd -P)" = "$cwd" ]; then name="$n"; break; fi
done < <(sed -n '/^```fleet$/,/^```$/p' "$ROSTER" 2>/dev/null | sed '1d;$d')
[ -n "$name" ] || exit 0

if [ "$name" = "lead-1" ]; then
  state="$cwd/LEDGER.md"
  grep -q '^```state$' "$state" 2>/dev/null || {
    echo "STATE GATE: $state has no \`\`\`state block at its top. Add it (schema: $SCHEMA), then end the turn." >&2; exit 2; }
  bounce_shape "$state" lead
  # HEAD includes LEDGER.md -> the state rode in that commit, nothing newer exists.
  [ "$(git -C "$cwd" log -1 --format=%H -- LEDGER.md 2>/dev/null)" = "$(git -C "$cwd" rev-parse HEAD 2>/dev/null)" ] && exit 0
  last="$(git -C "$cwd" log -1 --format=%ct 2>/dev/null)"
else
  state="$CHECKS/$name/STATE.md"
  [ -f "$state" ] || {
    echo "STATE GATE: $state is missing. Write it now, 15 lines in a \`\`\`state fence per $SCHEMA (session, rung, handoff, repo, branch, head, pushed, dirty, stop, awaiting, notice, next, updated, evidence), then end the turn." >&2; exit 2; }
  bounce_shape "$state" ic
  last="$(git -C "$cwd" log -1 --format=%ct 2>/dev/null)"
fi
[ -n "$last" ] || exit 0
mtime="$(stat -f %m "$state" 2>/dev/null || stat -c %Y "$state" 2>/dev/null)"
if [ "${last:-0}" -gt "${mtime:-0}" ]; then
  head="$(git -C "$cwd" log -1 --format='%h %s' 2>/dev/null)"
  echo "STATE GATE: $state is older than the newest commit ($head). Update it now (head, pushed, dirty, stop, next, updated; schema: $SCHEMA), then end the turn." >&2
  exit 2
fi
exit 0
