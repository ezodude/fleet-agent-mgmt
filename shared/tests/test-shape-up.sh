#!/bin/bash
# Tests for shape-up.sh, with tmux and claude stubbed on PATH and a temporary
# fleet home. Prints "N pass, M fail"; exit 1 on any fail.
set -u
HERE="$(cd "$(dirname "$0")/../launch" && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"; export FLEET_HOME="$T/home" PATH="$T/bin:$PATH" LOG="$T/tmux.log"
cat > "$T/bin/tmux" <<'S'
#!/bin/bash
echo "$*" >> "$LOG"
[ "$1" = has-session ] && { [ -e "$LOG.running.${3#=}" ]; exit; }
[ "$1" = new-session ] && touch "$LOG.running.$4"
exit 0
S
printf '#!/bin/bash\nexit 0\n' > "$T/bin/claude"; chmod +x "$T/bin/tmux" "$T/bin/claude"
P=0; F=0; ok() { if eval "$2"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $1"; fi; }
SU="$HERE/shape-up.sh"; D="$FLEET_HOME/shaping"

out="$("$SU" 'Bad Idea' 2>&1)"; rc=$?
ok "bad idea name is usage" '[ $rc -eq 2 ] && [[ "$out" == usage:* ]]'
out="$("$SU" alpha)"; rc=$?
ok "launch exit 0" '[ $rc -eq 0 ]'
ok "folder and map copied" 'cmp -s "$HERE/shaping/session-map.md" "$D/alpha/CLAUDE.md"'
ok "detached session, first line boot" 'grep -q -- "new-session -d -s shape-alpha -c $D/alpha FLEET_REPO=.* FLEET_HOME=.* claude -n shape-alpha .*shape-settings.json boot" "$LOG"'
ok "prints the attach line" '[[ "$out" == *"tmux attach -t shape-alpha"* ]]'
ok "never attaches" '! grep -q -E "^(attach|switch-client)" "$LOG"'
out="$("$SU" alpha)"
ok "second launch is idempotent" '[[ "$out" == *"already running"* ]] && [ "$(grep -c new-session "$LOG")" -eq 1 ]'
out="$("$SU" beta)"
ok "lists existing shaping folders" '[[ "$out" == *"already there:"*alpha* ]]'
out="$("$SU" --done alpha)"; rc=$?
ok "done while running keeps folder" '[ $rc -eq 1 ] && [ -d "$D/alpha" ] && [[ "$out" == *"still running; kill it first"* ]]'
rm -f "$LOG.running.shape-alpha"
out="$("$SU" --done alpha)"; rc=$?
ok "done with no stamp deletes folder, prints it" '[ $rc -eq 0 ] && [ ! -e "$D/alpha" ] && [ -d "$D/beta" ] && [[ "$out" == *"deleted $D/alpha"* ]] && [[ "$out" == *"  CLAUDE.md"* ]]'
echo 'beta brief ok · 15:20Z' > "$D/beta/brief.md"; rm -f "$LOG.running.shape-beta"
out="$("$SU" --done beta)"; rc=$?
ok "done with stamp deletes folder" '[ $rc -eq 0 ] && [ ! -e "$D/beta" ] && [[ "$out" == *"  brief.md"* ]]'
out="$("$SU" --done gamma)"; rc=$?
ok "done on a missing folder fails" '[ $rc -eq 1 ]'
# agent-up.sh: roster from FLEET_HOME, launch line, settings hooks
REPO="$(cd "$HERE/../.." && pwd)"; AU="$HERE/agent-up.sh"; mkdir -p "$T/atlas"; : > "$LOG"
out="$("$AU" atlas-ic-1 2>&1)"; rc=$?
ok "no_roster_exit_1_names_example" '[ $rc -eq 1 ] && [[ "$out" == *roster.example.md* ]] && ! grep -q new-session "$LOG"'
printf '```fleet\natlas-ic-1\t%s\n```\n' "$T/atlas" > "$FLEET_HOME/roster.md"
out="$("$AU" atlas-ic-1 2>&1)"; rc=$?
ok "roster_from_home" '[ $rc -eq 0 ] && [[ "$out" == "atlas-ic-1: launched"* ]] && grep -q "new-session -d -s atlas-ic-1 -c $T/atlas" "$LOG"'
ok "launch_receipt_written" '[ "$(sed -n 1p "$FLEET_HOME/checks/atlas-ic-1/launch")" ] && sed -n 1p "$FLEET_HOME/checks/atlas-ic-1/launch" | grep -Eq "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$" && [ "$(sed -n 2p "$FLEET_HOME/checks/atlas-ic-1/launch")" = "$(grep "new-session -d -s atlas-ic-1" "$LOG" | sed "s/^new-session -d -s atlas-ic-1 -c [^ ]* //")" ]'
ok "launch_line_exports_both" 'grep "new-session -d -s atlas-ic-1" "$LOG" | grep -q "FLEET_REPO=$REPO FLEET_HOME=$FLEET_HOME claude .*--settings $REPO/shared/launch/ic-settings.json"'
: > "$LOG"; rm -f "$LOG".running.atlas-ic-1
out="$("$AU" atlas-ic-1 --resume-id 0a1b2c3d-4e5f 2>&1)"; rc=$?
ok "resume_id_on_launch_line" '[ $rc -eq 0 ] && [[ "$out" == "atlas-ic-1: resumed 0a1b2c3d-4e5f"* ]] && grep "new-session -d -s atlas-ic-1" "$LOG" | grep -q "claude -r 0a1b2c3d-4e5f -n atlas-ic-1 "'
ok "resume_id_in_receipt_line_2" 'sed -n 2p "$FLEET_HOME/checks/atlas-ic-1/launch" | grep -q "claude -r 0a1b2c3d-4e5f -n atlas-ic-1 "'
out="$("$AU" atlas-ic-1 --resume-id 'x;y' 2>&1)"; rc=$?
ok "resume_id_rejects_odd_chars" '[ $rc -eq 1 ] && [[ "$out" == "bad session id"* ]]'
out="$("$AU" --all --resume-id abc 2>&1)"; rc=$?
ok "resume_id_not_with_all" '[ $rc -eq 1 ] && [[ "$out" == *"names one agent"* ]]'
bad=0; for f in ic lead; do
  n="$(jq -r '.. | .command? // empty' "$HERE/$f-settings.json" | grep -c -v '^"\$FLEET_REPO/shared/hooks/[a-z-]*\.sh"$')"; bad=$((bad+n))
  jq -e '[.. | .command? // empty] | length > 0' "$HERE/$f-settings.json" >/dev/null || bad=$((bad+1))
done
ok "settings_hooks_use_fleet_repo" '[ $bad -eq 0 ] && ! grep -rq "/Use""rs/" "$HERE"/*-settings.json'
echo "$P pass, $F fail"; [ $F -eq 0 ]
