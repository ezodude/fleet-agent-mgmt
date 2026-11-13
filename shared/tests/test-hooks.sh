#!/bin/bash
# End-to-end test for the compaction hooks. Throwaway fixture, no side effects
# outside $TMPDIR. Prints one line per case and a summary; exit 1 on any fail.
#   shared/tests/test-hooks.sh            expect: hooks e2e: N pass, 0 fail
set -u
TD="$(cd "$(dirname "$0")" && pwd -P)"; HERE="$TD/../hooks"; HERE="$(cd "$HERE" && pwd -P)"
GATE="$HERE/state-gate.sh"; BOOT="$HERE/postcompact-boot.sh"; PMARK="$HERE/prompt-mark.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# The user-level settings are a FIXTURE: the shipped template (settings-hooks.json)
# rendered for this clone, the way the installer writes it, never the real
# ~/.claude/settings.json. CLAUDE_SETTINGS may point at another file.
LIVE="${HOOKS_LIVE:-$HERE}"
SETTINGS="${CLAUDE_SETTINGS:-$T/settings.json}"
if [ -z "${CLAUDE_SETTINGS:-}" ]; then
  FLEET_CLONE="${LIVE%/shared/hooks}"
  sed "s|@FLEET_REPO@|$FLEET_CLONE|g" "$HERE/settings-hooks.json" > "$SETTINGS"
fi
pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL  %s  (%s)\n' "$1" "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got $2 want $3"; fi; }

# --- 0. preconditions --------------------------------------------------------
for t in git jq python3; do command -v "$t" >/dev/null && ok "tool $t" || bad "tool $t" "missing"; done
[ -x "$GATE" ] && ok "state-gate.sh executable" || bad "state-gate.sh executable" "chmod +x"
[ -x "$BOOT" ] && ok "postcompact-boot.sh executable" || bad "postcompact-boot.sh executable" "chmod +x"
[ -x "$PMARK" ] && ok "prompt-mark.sh executable" || bad "prompt-mark.sh executable" "chmod +x"
if [ -f "$SETTINGS" ]; then
  s="$(jq -r '[.hooks.SessionStart[]?|select(.matcher=="compact")|.hooks[]?.command]|.[0] // ""' "$SETTINGS")"
  check "settings: SessionStart compact -> postcompact-boot.sh" "$s" "$LIVE/postcompact-boot.sh"
  s="$(jq -r '[.hooks.Stop[]?.hooks[]?.command]|.[0] // ""' "$SETTINGS")"
  check "settings: Stop -> state-gate.sh" "$s" "$LIVE/state-gate.sh"
  check "settings: autoCompactEnabled" "$(jq -r '.autoCompactEnabled' "$SETTINGS")" "true"
  # prompt-mark.sh does work only for ICs, so it is installed per role
  # (shared/launch/ic-settings.json), never at user level.
  check "settings: no prompt-mark.sh at user level" "$(jq -r '[.. | .command? // empty | select(endswith("/prompt-mark.sh"))] | length' "$SETTINGS")" "0"
else
  bad "settings file" "$SETTINGS missing"
fi
# the installed record names every hook the live settings should carry
REC="$HERE/settings-hooks.json"
# the record is a template: @FLEET_REPO@ stands for the repo the live hook lines point at (read from the live Stop line)
LIVE_STOP="$LIVE/state-gate.sh"; [ -f "$SETTINGS" ] && LIVE_STOP="$(jq -r '[.hooks.Stop[]?.hooks[]?.command]|.[0] // ""' "$SETTINGS")"
LIVE_REPO="${LIVE_STOP%/shared/hooks/state-gate.sh}"
sub(){ sed "s|@FLEET_REPO@|$LIVE_REPO|"; }
check "record: names the placeholder, no home path" "$(grep -c '"@FLEET_REPO@/shared/hooks/' "$REC"):$(grep -c '/Use''rs/' "$REC")" "2:0"
check "record: Stop -> state-gate.sh" "$(jq -r '[.hooks.Stop[]?.hooks[]?.command]|.[0] // ""' "$REC" | sub)" "$LIVE/state-gate.sh"
check "record: SessionStart compact -> postcompact-boot.sh" "$(jq -r '[.hooks.SessionStart[]?|select(.matcher=="compact")|.hooks[]?.command]|.[0] // ""' "$REC" | sub)" "$LIVE/postcompact-boot.sh"
check "record: no prompt-mark.sh at user level" "$(jq -r '[.. | .command? // empty | select(endswith("/prompt-mark.sh"))] | length' "$REC")" "0"
ROLE="$(dirname "$HERE")/launch"
check "ic-settings: UserPromptSubmit -> prompt-mark.sh, no matcher" "$(jq -r '[.hooks.UserPromptSubmit[]?|select(has("matcher")|not)|.hooks[]?.command]|.[0] // ""' "$ROLE/ic-settings.json")" '"$FLEET_REPO/shared/hooks/prompt-mark.sh"'
check "lead-settings: no prompt-mark.sh" "$(jq -r '[.. | .command? // empty | select(endswith("/prompt-mark.sh"))] | length' "$ROLE/lead-settings.json")" "0"

# --- fixture -----------------------------------------------------------------
mkdir -p "$T/lead" "$T/ic" "$T/solo" "$T/checks" "$T/briefs"
printf '**owner: Sam** (the owner)\n\n```fleet\nlead-1\t%s\ntest-ic\t%s\n```\n' "$T/lead" "$T/ic" > "$T/roster.md"
export FLEET_ROSTER="$T/roster.md" STATE_CHECKS="$T/checks" HANDOFF_ROOT="$T/briefs" LEAD_LEDGER="$T/lead/LEDGER.md"
export FLEET_RECORDS="$T/records"   # an IC hook stamps ic-sessions.log in its records; never the real ones
g(){ git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }
OLD=202001010000
gate(){ printf '{"cwd":"%s","stop_hook_active":%s}' "$1" "${2:-false}" | "$GATE" 2>/dev/null; echo $?; }

# --- 1. the gate: lead ---------------------------------------------------------
L="$T/lead"; g "$L" init -q
printf '```state\nsession: lead-1\nhandoff: %s/lead/handoff.md\n```\n' "$T" > "$L/LEDGER.md"
g "$L" add LEDGER.md; g "$L" commit -q -m "ledger"
check "lead: ledger-only HEAD passes" "$(gate "$L")" 0
touch -t $OLD "$L/LEDGER.md"; echo a > "$L/handoff.md"; g "$L" add handoff.md; g "$L" commit -q -m "handoff"
check "lead: non-ledger HEAD newer than ledger bounces" "$(gate "$L")" 2
check "lead: bounce turn (stop_hook_active) passes" "$(gate "$L" true)" 0
touch "$L/LEDGER.md"
check "lead: ledger touched after the commit passes" "$(gate "$L")" 0
echo b >> "$L/handoff.md"; echo b >> "$L/LEDGER.md"; g "$L" add handoff.md LEDGER.md; g "$L" commit -q -m "mixed"; touch -t $OLD "$L/LEDGER.md"
check "lead: MIXED commit (handoff + ledger) passes" "$(gate "$L")" 0
echo c >> "$L/handoff.md"; g "$L" add handoff.md; g "$L" commit -q -m "handoff again"
check "lead: non-ledger commit after the mixed one bounces" "$(gate "$L")" 2
printf 'no block\n' > "$L/LEDGER.md"
check "lead: missing state block bounces" "$(gate "$L")" 2
printf '```state\nsession: lead-1\nhandoff: %s/lead/handoff.md\n```\n' "$T" > "$L/LEDGER.md"
check "lead: fresh 15-key block passes" "$(gate "$L")" 0
printf '```state\nsession: lead-1\nmood: fine\n```\nmood: log text below the fence\n' > "$L/LEDGER.md"
check "lead: an extra key in the fence bounces" "$(gate "$L")" 2
printf '```state\nsession: lead-1\nhandoff: %s/lead/handoff.md\n```\n' "$T" > "$L/LEDGER.md"

# --- 2. the gate: IC, solo, garbage --------------------------------------------
I="$T/ic"; g "$I" init -q; echo x > "$I/x"; g "$I" add x; g "$I" commit -q -m "c1"
check "ic: STATE.md missing bounces" "$(gate "$I")" 2
mkdir -p "$T/checks/test-ic"; printf '```state\nsession: test-ic\n```\n' > "$T/checks/test-ic/STATE.md"
check "ic: STATE.md newer than HEAD passes" "$(gate "$I")" 0
touch -t $OLD "$T/checks/test-ic/STATE.md"
check "ic: STATE.md older than HEAD bounces" "$(gate "$I")" 2
S="$T/checks/test-ic/STATE.md"
printf '```state\nsession: test-ic\nnext: a\nnext: b\n```\n' > "$S"
check "ic: a repeated key bounces" "$(gate "$I")" 2
printf 'session: test-ic\nmood: fine\n' > "$S"
check "ic: an unknown key bounces" "$(gate "$I")" 2
printf 'session: test-ic\nnext: %s\n' "$(printf 'x%.0s' $(seq 1 401))" > "$S"
check "ic: a line over 400 characters bounces" "$(gate "$I")" 2
printf '```state\nsession: test-ic\nnext: now\n```\n\n## log\nnext: older\nfree text, %s\n' "$(printf 'x%.0s' $(seq 1 401))" > "$S"
check "ic: text under ## log is not read" "$(gate "$I")" 0
printf '```state\nsession: test-ic\n```\n' > "$S"
check "solo: no roster row passes" "$(gate "$T/solo")" 0
check "gate: garbage stdin exits 0" "$(echo garbage | "$GATE" 2>/dev/null; echo $?)" 0

# --- 2b. the awaiting line: none | owner: | lead-1: | <roster name>: -------------
# IC mode: STATE.md above "## log"; each write is newer than HEAD, so only the shape decides.
aw(){ printf '```state\nsession: test-ic\nawaiting: %s\n```\n\n## log\n- awaiting: nothing. old text is not read\n' "$1" > "$S"; gate "$I"; }
check "awaiting ic: none passes" "$(aw 'none')" 0
check "awaiting ic: owner: passes" "$(aw 'owner: "ATL-42 spec ok" on STOP 1')" 0
check "awaiting ic: lead-1: passes" "$(aw 'lead-1: ATL-42 D3 ruling')" 0
check "awaiting ic: a roster name passes" "$(aw 'test-ic: the fixture data')" 0
check "awaiting ic: owner first, then lead-1, passes" "$(aw 'owner: PR ready and merge; lead-1: S5 ruling')" 0
check "awaiting ic: owner first by role, the name later, passes" "$(aw 'owner: merge; lead-1: relay to Sam: the S5 ruling')" 0
check "awaiting ic: the owner named in prose, no colon, passes" "$(aw "lead-1: relay Sam's S5 ruling to test-ic")" 0
for v in 'nothing. rung closed' 'Sam: the S5 word' 'lead-1/Sam: rulings on Q2-Q9' 'lead-1 and Sam: merge' \
         'next rung; idle' 'none; owner merge' 'none. rung closed' 'None' 'owner:' 'owner:merge' \
         'atlas-ic: an IC not on the roster' 'lead-1: S5 ruling; owner: merge' 'free text with no opening' \
         'lead-1: S5 ruling; Sam: merge' 'lead-1: S5 ruling; Owner: merge' 'lead-1: S5 ruling; OWNER : merge' \
         'lead-1: S5 ruling; sam: merge' 'test-ic: fixture; lead-1/Sam: rulings' 'lead-1: S5 ruling and Sam : merge' \
         'Owner: merge' 'OWNER: merge' 'Lead-1: S5' 'LEAD-1: S5' 'Test-ic: x' 'Test-IC: x'; do
  check "awaiting ic: \"$v\" bounces" "$(aw "$v")" 2
done
aw 'nothing. rung closed' >/dev/null
msg="$(printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null)"
check "awaiting ic: the fault names the line and its opening" "$(printf '%s\n' "$msg" | grep -c '^line 3 "awaiting" opens "nothing. rung closed": open it with none (the whole value), owner:, lead-1: or a roster name')" 1
check "awaiting ic: the bounce states the rule" "$(printf '%s\n' "$msg" | grep -c '^The awaiting line opens with exactly one of: none | owner: | lead-1: | <roster name>:')" 1
aw 'lead-1: S5 ruling; owner: merge' >/dev/null
check "awaiting ic: owner after another name says owner first" "$(printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null | grep -c '"awaiting" names the owner (owner:) after lead-1:, write owner: first')" 1
aw 'lead-1: S5 ruling; Sam: merge' >/dev/null
msg="$(printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null)"
check "awaiting ic: the owner by name after another says owner first" "$(printf '%s\n' "$msg" | grep -c '^line 3 "awaiting" names the owner (Sam:) after lead-1:, write owner: first')" 1
check "awaiting ic: that bounce states the rule" "$(printf '%s\n' "$msg" | grep -c 'the owner named with a colon (owner:, Owner: or their name:) is a fault')" 1
aw 'lead-1: S5 ruling; Owner: merge' >/dev/null
check "awaiting ic: Owner: after another says owner first" "$(printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null | grep -c '"awaiting" names the owner (Owner:) after lead-1:, write owner: first')" 1
aw 'none' >/dev/null
check "awaiting ic: a key fault alone does not print the awaiting rule" "$(printf 'session: test-ic\nmood: fine\n' > "$S"; printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null | grep -c 'The awaiting line')" 0
eval "$(sed -n '/^shape() {$/,/^}$/p' "$GATE")"
printf '```state\nawaiting: test-ic: x\n```\n' > "$T/s-noroster.md"
check "awaiting shape(): no roster, a name faults and names the roster" "$(FLEET_ROSTER="$T/none.md" shape "$T/s-noroster.md" ic | grep -c "(no roster names read from $T/none.md)$")" 1
# the owner's name comes from the roster's **owner: <name>** line, not from the gate
printf '**owner: Robin** (x)\n\n```fleet\nlead-1\t/x\n```\n' > "$T/roster-robin.md"
printf '```state\nawaiting: lead-1: S5; Robin: merge\n```\n' > "$T/s-robin.md"
check "awaiting shape(): the roster's owner name, with a colon after lead-1:, faults" "$(FLEET_ROSTER="$T/roster-robin.md" shape "$T/s-robin.md" ic | grep -c '^line 2 "awaiting" names the owner (Robin:) after lead-1:')" 1
printf '```state\nawaiting: lead-1: S5; Morgan: merge\n```\n' > "$T/s-robin.md"
check "awaiting shape(): a name that is not the roster's owner passes" "$(FLEET_ROSTER="$T/roster-robin.md" shape "$T/s-robin.md" ic)" ""
printf '```fleet\nlead-1\t/x\n```\n' > "$T/roster-noowner.md"
printf '```state\nawaiting: lead-1: S5\n```\n' > "$T/s-robin.md"
check "awaiting shape(): no owner line in the roster, lead-1: faults and names the roster" "$(FLEET_ROSTER="$T/roster-noowner.md" shape "$T/s-robin.md" ic | grep -c "no owner name was read from $T/roster-noowner.md")" 1
printf '```state\nawaiting: owner: merge\n```\n' > "$T/s-robin.md"
check "awaiting shape(): no owner line in the roster, owner: still passes" "$(FLEET_ROSTER="$T/roster-noowner.md" shape "$T/s-robin.md" ic)" ""
printf '```state\nsession: test-ic\n```\n' > "$S"
# lead mode: the ```state fence of LEDGER.md; a line below the fence is not read
lw(){ printf '```state\nsession: lead-1\nhandoff: %s/lead/handoff.md\nawaiting: %s\n```\nawaiting: nothing. below the fence\n' "$T" "$1" > "$L/LEDGER.md"; gate "$L"; }
check "awaiting lead: none passes" "$(lw 'none')" 0
check "awaiting lead: owner: passes" "$(lw 'owner: PR ready and merge; lead-1: S5')" 0
check "awaiting lead: lead-1: passes" "$(lw 'lead-1: the audit')" 0
check "awaiting lead: a roster name passes" "$(lw 'test-ic: STOP 2 report')" 0
for v in 'nothing. idle' 'Sam: word' 'lead-1/Sam: rulings' 'lead-1 and Sam rulings' 'next rung; idle' 'none; owner merge' 'nova-ic: not on the roster' \
         'lead-1: S5 ruling; owner: merge' 'lead-1: S5 ruling; Sam: merge' 'lead-1: S5 ruling; Owner: merge' 'test-ic: STOP 2; lead-1/Sam: rulings' \
         'Owner: merge' 'OWNER: merge' 'Lead-1: S5' 'Test-ic: STOP 2'; do
  check "awaiting lead: \"$v\" bounces" "$(lw "$v")" 2
done
printf '```state\nsession: lead-1\nhandoff: %s/lead/handoff.md\n```\n' "$T" > "$L/LEDGER.md"
# every "awaiting: ..." line the schema, the skills and the charter show passes shape()
R="$(cd "$HERE/../.." && pwd -P)"
printf '**owner: Robin**\n\n```fleet\nlead-1\t/x\natlas-ic\t/y\n```\n' > "$T/roster-docs.md"
n=0; badl=""
while IFS= read -r l; do
  [ -n "$l" ] || continue; n=$((n+1))
  printf '```state\n%s\n```\n' "${l#"${l%%[! ]*}"}" > "$T/ex.md"
  [ -z "$(FLEET_ROSTER="$T/roster-docs.md" shape "$T/ex.md" ic)" ] || badl="$badl[$l]"
done < <(grep -rhE '^ *awaiting: ' "$HERE/STATE-schema.md" "$R/shared/skills" "$R/Leads/shared/CHARTER-lead.md" 2>/dev/null)
check "awaiting docs: 5 example lines, each passes shape()" "$n|$badl" "5|"

# --- 2c. the roster row: the cwd, else its git top level -----------------------
# a sub-folder of an IC's worktree is gated as the IC; lead-1's row, itself a
# sub-folder of its repo, is matched exactly and its repo's top level is not lead-1
mkdir -p "$I/sub/deep"
printf '```state\nsession: test-ic\n```\n' > "$S"
check "sub-folder: fresh STATE.md passes" "$(gate "$I/sub/deep")" 0
touch -t $OLD "$S"
check "sub-folder: now gated (STATE.md older than HEAD bounces)" "$(gate "$I/sub/deep")" 2
printf '```state\nsession: test-ic\nnext: a\nnext: b\n```\n' > "$S"
check "sub-folder: gets the shape check" "$(gate "$I/sub/deep")" 2
printf '```state\nsession: test-ic\n```\n' > "$S"
A="$T/agm"; mkdir -p "$A/Leads/lead-1"; g "$A" init -q; echo x > "$A/x"; g "$A" add x; g "$A" commit -q -m a
printf '**owner: Robin**\n\n```fleet\nlead-1\t%s\ntest-ic\t%s\n```\n' "$A/Leads/lead-1" "$T/ic" > "$T/roster-agm.md"
check "roster_name: a lead-1 row inside a repo is matched exactly (no state block bounces)" "$(printf '{"cwd":"%s"}' "$A/Leads/lead-1" | FLEET_ROSTER="$T/roster-agm.md" "$GATE" 2>&1 >/dev/null | grep -c "$A/Leads/lead-1/LEDGER.md has no")" 1
check "roster_name: that repo's top level is not lead-1 (solo passes)" "$(printf '{"cwd":"%s"}' "$A" | FLEET_ROSTER="$T/roster-agm.md" "$GATE" 2>/dev/null; echo $?)" 0
eval "$(sed -n '/^roster_name() {$/,/^}$/p' "$GATE")"
check "roster_name: IC sub-folder resolves to the row" "$(roster_name "$(cd "$I/sub/deep" && pwd -P)" "$FLEET_ROSTER")" "$(printf 'test-ic\t%s' "$(cd "$I" && pwd -P)")"
check "roster_name: a non-repo, non-roster dir is nothing" "$(roster_name "$(cd "$T/solo" && pwd -P)" "$FLEET_ROSTER")" ""
check "roster_name: shape() still evals alone from the gate" "$(sed -n '/^shape() {$/,/^}$/p' "$GATE" | grep -c '^shape() {$')" 1

# --- 2d. the owner-prompt marker: prompt-mark.sh and the gate's marker check ---
# prompt-mark.sh touches checks/<ic>/.last-prompt; the gate bounces an IC once
# when that marker is newer than STATE.md. Times are set with touch -t: FUT is
# next year, so "newer" never depends on the clock's second.
FUT="$(( $(date +%Y) + 1 ))01010000"
M="$T/checks/test-ic/.last-prompt"
printf '```state\nsession: test-ic\n```\n' > "$S"   # newer than HEAD: the commit check passes
mkdir -p "$T/checks/lead-1"
pm_out=""; pm_rc=""
pm(){ local o; o="$(printf '{"cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"x"}' "$1" | "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"; }
rm -f "$M"; pm "$I"
check "prompt-mark: IC cwd touches the marker" "$([ -f "$M" ] && echo yes)" "yes"
rm -f "$M"; pm "$I/sub/deep"
check "prompt-mark: IC sub-folder cwd touches the marker" "$([ -f "$M" ] && echo yes)" "yes"
touch -t $OLD "$M"; pm "$I"
check "prompt-mark: an existing marker is touched to now" "$([ "$(stat -f %m "$M")" -ge "$(stat -f %m "$S")" ] && echo yes)" "yes"
rm -f "$M"; pm "$L"
check "prompt-mark: lead-1 cwd, no marker" "$(find "$T/checks" -name .last-prompt | wc -l | tr -d ' ')" "0"
pm "$T/solo"
check "prompt-mark: non-roster cwd, no marker" "$(find "$T/checks" -name .last-prompt | wc -l | tr -d ' ')" "0"
mkdir -p "$T/ic2"; printf '**owner: Robin**\n\n```fleet\nlead-1\t%s\ntest-ic\t%s\nnew-ic\t%s\n```\n' "$T/lead" "$T/ic" "$T/ic2" > "$T/roster-new.md"
o="$(printf '{"cwd":"%s"}' "$T/ic2" | FLEET_ROSTER="$T/roster-new.md" "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"
check "prompt-mark: IC with no checks folder, nothing created" "$([ -e "$T/checks/new-ic" ] && echo created || echo none)" "none"
o="$(printf '{"cwd":"%s"}' "$I" | FLEET_STATE_GATE="$T/no-gate.sh" "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"
check "prompt-mark: roster_name() unreadable, no marker" "$([ -f "$M" ] && echo yes || echo no)" "no"
o="$(echo garbage | "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"
o="$(printf '' | "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"
o="$(printf '{"cwd":"%s/missing"}' "$T" | "$PMARK" 2>&1)"; pm_rc="$pm_rc$?"; pm_out="$pm_out$o"
check "prompt-mark: garbage, empty and missing-cwd stdin exit 0" "${pm_rc: -3}" "000"
check "prompt-mark: exit 0 on every run" "$(printf '%s' "$pm_rc" | tr -d 0)" ""
check "prompt-mark: stdout and stderr empty on every run" "$pm_out" ""
# the gate's marker check, IC only
touch -t $OLD "$M"
check "marker gate: marker older than STATE.md passes" "$(gate "$I")" 0
rm -f "$M"
check "marker gate: no marker passes, as before" "$(gate "$I")" 0
touch -t $FUT "$M"
check "marker gate: marker newer than STATE.md bounces" "$(gate "$I")" 2
msg="$(printf '{"cwd":"%s"}' "$I" | "$GATE" 2>&1 >/dev/null)"
check "marker gate: the bounce says the pane was written in" "$(printf '%s\n' "$msg" | grep -c '^STATE GATE: the owner (or lead-1) wrote in this pane since .*STATE.md was last written')" 1
check "marker gate: the bounce names the four keys and the touch" "$(printf '%s\n' "$msg" | grep -c "update stop, awaiting, next and updated now.*otherwise just touch it (touch $S). Then end the turn.")" 1
check "marker gate: bounce turn (stop_hook_active) passes" "$(gate "$I" true)" 0
check "marker gate: sub-folder cwd bounces on the marker" "$(gate "$I/sub/deep")" 2
touch -t $FUT "$S"
check "marker gate: STATE.md written in the marker's second passes" "$(gate "$I")" 0
touch -t $FUT "$T/checks/lead-1/.last-prompt"
check "marker gate: lead-1 ignores any marker" "$(gate "$L")" 0
rm -f "$T/checks/lead-1/.last-prompt" "$M"
printf '```state\nsession: test-ic\n```\n' > "$S"

# --- 3. the brief --------------------------------------------------------------
row(){ printf '{"type":"user","timestamp":"2026-01-01T00:00:%02dZ","message":{"role":"user","content":%s}}\n' "$1" "$2"; }
{
  row 1 '"first real prompt"'
  printf '{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"This session is being continued"}}\n'
  row 2 '"<command-name>/compact</command-name>"'
  row 3 '"Base directory for this skill: /x\n# Skill body"'
  row 4 '"Another Claude session sent a message:\n<cross-session-message from=\"abc\" from-name=\"test-lead\" from-mode=\"x\">lead-1: continue with step C</cross-session-message>\n\nThis came from another Claude session."'
  row 5 '"[Request interrupted by user]"'
  row 6 '"[Cross-session idle notice] test-ic is idle"'
  row 7 '"/compact"'
  row 8 '"Stop hook feedback:\n[state-gate.sh]: STATE GATE: stale"'
  row 9 '[{"type":"tool_result","content":"ignored"}]'
} > "$T/transcript.jsonl"
brief(){ printf '{"cwd":"%s","transcript_path":"%s","source":"compact","session_id":"e2e00000"}' "$1" "$T/transcript.jsonl" | "$BOOT" 2>/dev/null; }
B="$(brief "$L")"
c(){ printf '%s' "$B" | grep -qF -- "$1" && ok "brief: $2" || bad "brief: $2" "missing: $1"; }
c "role: lead lead-1" "lead role from the roster"
c "session: lead-1" "STATE block carried"
c "In-flight prompt (cross-session message from test-lead" "cross-session sender as the tag"
c "lead-1: continue with step C" "cross-session body kept"
c "handoff named in the state ($T/lead/handoff.md)" "FIRST ACTION names the handoff"
for bad_s in "Another Claude session sent" "This came from another" "Base directory" "/compact" "Stop hook feedback" "idle notice" "[Request interrupted"; do
  printf '%s' "$B" | grep -qF -- "$bad_s" && bad "brief: skips '$bad_s'" "present" || ok "brief: skips '$bad_s'"
done
[ -f "$T/briefs/"*/LATEST.md ] && ok "brief: copy written under HANDOFF_ROOT" || bad "brief: copy written under HANDOFF_ROOT" "no LATEST.md"
B="$(brief "$I")"
c "role: ic test-ic" "ic role from the roster"
c "session: test-ic" "ic STATE.md carried"
printf '```state\nsession: test-ic\n```\n## log\nmerged: OLD-LOG-LINE\n' > "$T/checks/test-ic/STATE.md"
printf '%s' "$(brief "$I")" | grep -qF OLD-LOG-LINE && bad "brief: ## log not carried" "present" || ok "brief: ## log not carried"
printf '```state\nsession: test-ic\n```\n' > "$T/checks/test-ic/STATE.md"
B="$(brief "$T/solo")"
c "role: solo" "solo role"
c "not a git repository" "solo non-repo git line"
check "brief: garbage stdin exits 0" "$(echo garbage | "$BOOT" >/dev/null 2>&1; echo $?)" 0

# --- 7. paths from FLEET_HOME; the pass log; the lead's folder ---------------------
# foreign_session_passes: a cwd on no roster row passes silently, no STATE file needed
FH="$T/fh"; mkdir -p "$FH/checks/test-ic" "$T/foreign"
out="$(printf '{"cwd":"%s"}' "$T/foreign" | FLEET_HOME="$FH" "$GATE" 2>&1)"; rc=$?
check "foreign_session_passes: exit 0" "$rc" 0
check "foreign_session_passes: no output" "$out" ""
check "foreign_session_passes: no log written" "$(ls "$FH/checks/test-ic" | wc -l | tr -d ' ')" 0
# pass_logged: each pass of a named session appends "<utc> pass <session>" to checks/<session>/state-gate.log
(
  unset STATE_CHECKS
  export FLEET_HOME="$FH"
  printf '```state\nsession: test-ic\n```\n' > "$FH/checks/test-ic/STATE.md"
  printf '{"cwd":"%s"}' "$I" | "$GATE" >/dev/null 2>&1; printf '{"cwd":"%s"}' "$I" | "$GATE" >/dev/null 2>&1
  printf '%s' "$(wc -l < "$FH/checks/test-ic/state-gate.log" | tr -d ' ')" > "$T/pl.n"
  head -1 "$FH/checks/test-ic/state-gate.log" > "$T/pl.line"
  # a session whose checks folder is missing: pass, and no folder is created
  printf '{"cwd":"%s"}' "$L" | "$GATE" >/dev/null 2>&1; echo $? > "$T/pl.rc"
  [ -e "$FH/checks/lead-1" ] && echo made > "$T/pl.made" || echo none > "$T/pl.made"
)
check "pass_logged: two passes, two lines" "$(cat "$T/pl.n")" 2
check "pass_logged: line is <utc> pass <session>" "$(grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z pass test-ic$' "$T/pl.line")" 1
check "pass_logged: no checks folder, still passes" "$(cat "$T/pl.rc")" 0
check "pass_logged: never creates a session folder" "$(cat "$T/pl.made")" none
# a bounce is not logged
touch -t $OLD "$FH/checks/test-ic/STATE.md"; before="$(wc -l < "$FH/checks/test-ic/state-gate.log" | tr -d ' ')"
printf '{"cwd":"%s"}' "$I" | FLEET_HOME="$FH" STATE_CHECKS="$FH/checks" "$GATE" >/dev/null 2>&1
check "pass_logged: a bounce adds no line" "$(wc -l < "$FH/checks/test-ic/state-gate.log" | tr -d ' ')" "$before"
# worker_commit_does_not_trip_lead: the lead's folder and a worker's record folder share one repo
W="$T/shared-repo"; mkdir -p "$W/Leads/lead-1" "$W/records/p/r1"; g "$W" init -q
printf '```state\nsession: lead-1\n```\n' > "$W/Leads/lead-1/LEDGER.md"; echo a > "$W/Leads/lead-1/note.md"
g "$W" add -A; g "$W" commit -q -m "lead"
touch -t $OLD "$W/Leads/lead-1/LEDGER.md"; touch -t 202001010001 "$W/Leads/lead-1/note.md"
printf '**owner: Robin** (the owner)\n\n```fleet\nlead-1\t%s\n```\n' "$W/Leads/lead-1" > "$T/roster-w.md"
wgate(){ printf '{"cwd":"%s"}' "$W/Leads/lead-1" | FLEET_ROSTER="$T/roster-w.md" STATE_CHECKS="$T/checks" "$GATE" >/dev/null 2>&1; echo $?; }
echo w > "$W/records/p/r1/worker-file.md"; g "$W" add -A; g "$W" commit -q -m "worker commit"
check "worker_commit_does_not_trip_lead: a worker commit elsewhere in the repo passes" "$(wgate)" 0
echo b >> "$W/Leads/lead-1/note.md"; g "$W" add -A; g "$W" commit -q -m "lead note, no ledger"
check "worker_commit_does_not_trip_lead: a lead-folder commit without the ledger still bounces" "$(wgate)" 2
# a lead row whose folder is missing: not the team's session, passes silently
printf '```fleet\nlead-1\t%s\n```\n' "$T/no-such-lead" > "$T/roster-m.md"
check "lead folder missing: the lead's cwd passes silently" "$(printf '{"cwd":"%s"}' "$T/no-such-lead" | FLEET_ROSTER="$T/roster-m.md" "$GATE" 2>&1; echo "rc=$?")" "rc=0"
# ledger_add_signs_by_config: no forced -S; a repo with commit.gpgsign=false commits
LR="$T/ledger-repo"; LFH="$T/ledger-fh"; mkdir -p "$LR/Leads/lead-1" "$T/ledger-scan" "$LFH/records" "$LFH/profiles"; git -C "$LR" init -q; git -C "$LFH" init -q   # fleet-check wants a git FLEET_HOME
printf '```state\nsession: lead-1\nhead: 0000000 (ledger commit follows)\nupdated: 2026-10-13 09:00 BST\nawaiting: none\n```\n\n## Log (newest first)\n\n### +1 (2026-10-13 09:00 BST, 08:00Z) first\n\nbody\n' > "$LR/Leads/lead-1/LEDGER.md"
git -C "$LR" config user.name t; git -C "$LR" config user.email t@t; git -C "$LR" config commit.gpgsign false
git -C "$LR" add -A; git -C "$LR" commit -q -m init
out="$(echo body | env -u LEDGER_SIGN LEDGER_REPO="$LR" FLEET_HOME="$LFH" FLEET_CHECK_SCAN="$T/ledger-scan" "$HERE/../ledger/ledger-add.sh" "signed by config" 2>&1)"; rc=$?
check "ledger_add_signs_by_config: exit 0" "$rc" 0
check "ledger_add_signs_by_config: the entry was committed" "$(git -C "$LR" log -1 --format=%s)" "chore: ledger +2 signed by config"
check "ledger_add_signs_by_config: the commit is unsigned (%G? = N)" "$(git -C "$LR" log -1 --format=%G?)" N
check "ledger_add_signs_by_config: no -S in the script" "$(grep -c 'git commit -S\|SIGN-S\|SIGN--S' "$HERE/../ledger/ledger-add.sh")" 0

printf 'hooks e2e: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
