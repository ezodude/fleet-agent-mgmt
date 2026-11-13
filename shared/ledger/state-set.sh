#!/bin/bash
# lead-1's one write path into an IC's STATE.md. The IC keeps writing its
# own; lead-1 never edits one by hand.
#   shared/ledger/state-set.sh <ic> key="value" [key="value" ...]
# For each key, the one line "key: ..." above "## log" becomes "key: value";
# the line it replaced goes, word for word, to the end of the file as
#   - superseded <YYYY-MM-DD>: <old line>
# under "## log" (the heading is added at the end of the file, below the
# closing fence, when missing). A tag-like <...> outside backticks in the old
# line is put in backticks, the schema's rule for log text, so a viewer does
# not drop it; an old line with an unpaired backtick or a run of two or more
# goes whole into one code span (`` <old line> ``). updated: changes only
# when it is one of the keys given.
# Refused, nothing written (exit 1): a key that is not one of the 15, a key
# given twice, a value with a line break, a key with no line or with two
# lines above "## log", a result that fails the state gate's shape(), a
# result with an md-check fault (other than "wide") the file did not have
# before, md-check not running, and a file that changed while this ran
# (sha256 of what was read vs what is there just before the write).
# The new file is written beside the old one and renamed over it, so no
# reader sees half a file. Its mtime is the old file's, so lead-1's write
# neither hides the IC's own staleness from state-gate.sh nor counts as the
# IC's update.
# Paths, overridable for tests:
#   STATE_CHECKS       ~/.fleet-agent-mgmt/checks (the file is <checks>/<ic>/STATE.md)
#   FLEET_STATE_GATE   where shape() is read from (shape() reads FLEET_ROSTER itself)
#   FLEET_MD_CHECK     the md-check script (default shared/records/md-check.sh)
set -u
. "$(cd -P "$(dirname "$0")" && pwd)/../lib/paths.sh"
CHECKS="${STATE_CHECKS:-$FLEET_HOME/checks}"
GATE="${FLEET_STATE_GATE:-$(dirname "$0")/../hooks/state-gate.sh}"
MDC="${FLEET_MD_CHECK:-$(dirname "$0")/../records/md-check.sh}"
KEYS=" session role rung handoff repo branch head pushed dirty stop awaiting notice next updated evidence "
die() { printf 'state-set: %s\nstate-set: refused, nothing was written.\n' "$1" >&2; exit 1; }
sha() { shasum -a 256 < "$1" 2>/dev/null || sha256sum < "$1"; }

[ $# -ge 2 ] || { echo 'usage: shared/ledger/state-set.sh <ic> key="value" [key="value" ...]' >&2; exit 2; }
ic="$1"; shift
case "$ic" in ""|.*|*/*) die "\"$ic\" is not a roster name";; esac
f="$CHECKS/$ic/STATE.md"
[ -f "$f" ] || die "$f is missing"

n=0; given=" "
for a in "$@"; do
  case "$a" in *=*) ;; *) die "\"$a\" is not key=\"value\"";; esac
  k="${a%%=*}"; v="${a#*=}"
  case "$KEYS" in *" $k "*) ;; *) die "\"$k\" is not one of the 15 keys:$KEYS";; esac
  case "$given" in *" $k "*) die "\"$k\" is given twice";; esac
  case "$v" in *$'\n'*|*$'\r'*) die "the value of \"$k\" has a line break: one line per key";; esac
  given="$given$k "; n=$((n+1))
  export "SS_K$n=$k" "SS_V$n=$v"
done
export SS_N="$n" SS_DATE="$(date +%Y-%m-%d)"

eval "$(sed -n '/^shape() {$/,/^}$/p' "$GATE" 2>/dev/null)"
declare -F shape >/dev/null || die "cannot read shape() from $GATE"

T="$(mktemp -d)"; tmp="$(dirname "$f")/.STATE.md.state-set.$$"
trap 'rm -rf "$T"; rm -f "$tmp"' EXIT
cp -p "$f" "$T/orig" || die "cannot read $f"
sum="$(sha "$T/orig")"

awk '
  BEGIN { n = ENVIRON["SS_N"]
          for (i = 1; i <= n; i++) { K[i] = ENVIRON["SS_K" i]; V[i] = ENVIRON["SS_V" i]; at[K[i]] = i }
          above = 1 }
  above && /^## log/ { above = 0; haslog = 1 }
  above && !/^```/ && index($0, ":") {
    k = $0; sub(/:.*/, "", k)
    if (k in at) { i = at[k]; hits[i]++; old[i] = $0; print k ": " V[i]; next } }
  { print }
  END {
    for (i = 1; i <= n; i++)
      if (hits[i] != 1) { printf "\"%s\" has %d lines above ## log, not 1\n", K[i], hits[i] > "/dev/stderr"; bad = 1 }
    if (bad) exit 1
    if (!haslog) { print ""; print "## log" }
    for (i = 1; i <= n; i++) print "- superseded " ENVIRON["SS_DATE"] ": " ticks(old[i]) }
  # a tag-like <...> outside backtick spans goes in backticks; the rest is kept
  # as is. An odd number of backticks, or a run of two or more, cannot be
  # paired by this split: the whole line goes in one span, its fence one
  # backtick longer than the longest run in it.
  function ticks(s,   p, m, i, out, seg, r, t, f) {
    r = 0; t = s
    while (match(t, /`+/)) { if (RLENGTH > r) r = RLENGTH; t = substr(t, RSTART + RLENGTH) }
    m = split(s, p, "`")
    if (r > 1 || m % 2 == 0) { f = ""; for (i = 0; i <= r; i++) f = f "`"; return f " " s " " f }
    out = ""
    for (i = 1; i <= m; i++) {
      seg = p[i]
      if (i % 2 == 1) seg = wrap(seg)
      out = out (i > 1 ? "`" : "") seg }
    return out }
  function wrap(seg,   out) {
    out = ""
    while (match(seg, /<[\/!?A-Za-z][^<>]*>/)) {
      out = out substr(seg, 1, RSTART - 1) "`" substr(seg, RSTART, RLENGTH) "`"
      seg = substr(seg, RSTART + RLENGTH) }
    return out seg }
' "$T/orig" > "$T/new" 2> "$T/err" || die "$f: $(paste -sd ';' - < "$T/err")"

faults="$(shape "$T/new" ic)"
[ -z "$faults" ] || die "$f would break the state shape: $(printf '%s' "$faults" | head -3 | paste -sd ';' -)"

# md-check's faults, "wide" left out, without line numbers, sorted; exit 1
# when md-check did not run
md() { local o rc; o="$(bash "$MDC" "$1" 2>&1)"; rc=$?
  { [ "$rc" -lt 2 ] && printf '%s\n' "$o" | grep -q '^md-check '; } || return 1
  printf '%s\n' "$o" | sed -n 's/^  line [0-9]*: //p' | grep -v '^wide: ' | sort; return 0; }
was="$(md "$T/orig")" && now="$(md "$T/new")" || die "md-check did not run ($MDC)"
added="$(comm -13 <(printf '%s\n' "$was") <(printf '%s\n' "$now") | sed '/^$/d')"
[ -z "$added" ] || die "$f would get a fault a viewer shows: $(printf '%s' "$added" | head -3 | paste -sd ';' -) (shared/records/md_check.py says what each fault is)"

cp -p "$T/orig" "$tmp" && cat "$T/new" > "$tmp" && touch -r "$T/orig" "$tmp" || die "cannot write $tmp"
[ "$(sha "$f")" = "$sum" ] || die "$f changed while this ran (sha256 differs from what was read): read it again and re-run"
mv -f "$tmp" "$f" || die "cannot write $f"
printf 'state-set: %s: set%s; %d line(s) under ## log; mtime kept\n' "$f" "${given% }" "$n"
