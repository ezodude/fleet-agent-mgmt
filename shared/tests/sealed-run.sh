#!/bin/bash
# sealed-run.sh: clone this checkout, then run every test-*.sh from the clone under a
# macOS sandbox that denies reads AND writes of the source repo root, the default state
# folder and the Claude home (the three are computed from the real HOME before it is swapped).
# The suite runs with HOME and FLEET_HOME pointing into a temp folder. Ends with one planted
# read and one planted write per denied root, which must be refused.
# Not named test-*: the suite loop must not run it recursively.
set -u
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
common="$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" || { echo "sealed-run: no git repo" >&2; exit 2; }
MAIN="$(cd -P "$common/.." && pwd)"
STATE="$HOME/.fleet-agent-mgmt"; CLAUDE_HOME="$HOME/.claude"
real() { if [ -e "$1" ]; then (cd -P "$1" && pwd); else echo "$1"; fi; }
STATE="$(real "$STATE")"; CLAUDE_HOME="$(real "$CLAUDE_HOME")"

W="$(mktemp -d)" || exit 2
W="$(cd -P "$W" && pwd)" || exit 2   # physical path: /var is a symlink to /private/var on macOS
trap 'rm -rf "$W"' EXIT
git clone -q --no-local "$REPO" "$W/clone" || { echo "sealed-run: clone failed" >&2; exit 2; }
# a clone checks out one branch; the tests that archive main need a local main
if ! git -C "$W/clone" rev-parse --verify -q main >/dev/null; then
  git -C "$W/clone" branch -q main origin/main 2>/dev/null
fi
PROFILE="$W/profile.sb"
{
  echo '(version 1)'
  echo '(allow default)'
  for p in "$MAIN" "$STATE" "$CLAUDE_HOME"; do
    printf '(deny file-read* (subpath "%s"))\n' "$p"
    printf '(deny file-write* (subpath "%s"))\n' "$p"
  done
} > "$PROFILE"

# the suite sees a temp HOME and FLEET_HOME, never the real ones
mkdir -p "$W/home" "$W/fleet-home"
export HOME="$W/home" FLEET_HOME="$W/fleet-home"
total=0; failed=0
for t in "$W"/clone/shared/tests/test-*.sh; do
  last="$(cd "$W/clone" && sandbox-exec -f "$PROFILE" bash "$t" 2>&1 | tail -1)"
  echo "$(basename "$t"): $last"
  n="$(echo "$last" | sed -n 's/.*[^0-9]\([0-9][0-9]*\) pass, \([0-9][0-9]*\) fail.*/\1/p;s/^\([0-9][0-9]*\) pass, \([0-9][0-9]*\) fail.*/\1/p')"
  f="$(echo "$last" | sed -n 's/.*[^0-9]\([0-9][0-9]*\) pass, \([0-9][0-9]*\) fail.*/\2/p;s/^\([0-9][0-9]*\) pass, \([0-9][0-9]*\) fail.*/\2/p')"
  if [ -z "$n" ]; then failed=$((failed+1)); else total=$((total+n)); failed=$((failed+f)); fi
done
echo "$total pass, $failed fail"
rc=0; [ "$failed" = 0 ] || rc=1
if ! ls "$MAIN" >/dev/null 2>&1; then
  echo "planted read: cannot test (source repo root $MAIN is not readable without the sandbox)"; exit 1
fi
if sandbox-exec -f "$PROFILE" ls "$MAIN" >/dev/null 2>&1; then
  echo "planted read: NOT caught"; rc=1
else
  echo "planted read: caught"
fi
# planted write: a sandboxed touch of a name that does not exist in each real denied root must fail
# and leave nothing behind. Roots that are absent or not writable outside the sandbox are skipped.
tested=0; leaked=0
for root in "$MAIN" "$STATE" "$CLAUDE_HOME"; do
  [ -d "$root" ] && [ -w "$root" ] || continue
  plant="$root/.sealed-run-planted-write-$$"
  [ -e "$plant" ] && continue
  tested=$((tested+1))
  sandbox-exec -f "$PROFILE" touch "$plant" >/dev/null 2>&1
  if [ -e "$plant" ]; then rm -f "$plant"; leaked=$((leaked+1)); fi
done
if [ "$tested" = 0 ]; then
  echo "planted write: cannot test (no denied root is writable outside the sandbox)"; rc=1
elif [ "$leaked" != 0 ]; then
  echo "planted write: NOT caught"; rc=1
else
  echo "planted write: caught"
fi
exit $rc
