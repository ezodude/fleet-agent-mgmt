#!/bin/bash
# Tests shared/migrate/copy.sh and check-copy.sh. Fixtures under a temp folder and a temp HOME only.
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
COPY="$REPO/shared/migrate/copy.sh"
CHECK="$REPO/shared/migrate/check-copy.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
export FLEET_HOME="$T/fleet-home"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1: $2"; }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want [$3] got [$2]"; fi; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# mkfix <dir>: a fixture AgentMgmt with tracked, untracked, ignored, dotfile, spaced files
mkfix() {
  local A="$1"
  mkdir -p "$A/shared" "$A/Leads/lead-1" "$A/Leads/atlas/sub" "$A/lead-ux/notes" "$A/Leads/x/.git"
  printf '**owner: Robin**\n\n```fleet\nlead-1\t%s/Leads/lead-1\natlas-ic-1\t%s/Leads/atlas\tflag-x\nux-1\t%s/lead-ux/notes\nelsewhere-1\t/opt/elsewhere\nsibling-1\t%s2/Leads/x\n```\n' "$A" "$A" "$A" "$A" > "$A/shared/roster.md"
  echo ledger-body > "$A/Leads/lead-1/LEDGER.md"
  echo board > "$A/Leads/lead-1/board.md"
  echo spaced > "$A/Leads/atlas/sub/file with space.md"
  echo hidden > "$A/Leads/atlas/.dotfile"
  echo ux > "$A/lead-ux/notes/n.md"
  echo gitjunk > "$A/Leads/x/.git/config"
  echo ignored > "$A/Leads/atlas/ignored.log"
  echo "Leads/atlas/ignored.log" > "$A/.gitignore"
  echo other > "$A/other.txt"
  git -C "$A" init -q 2>/dev/null
  git -C "$A" add .gitignore shared Leads/lead-1 lead-ux 2>/dev/null
  git -C "$A" -c user.email=a@b -c user.name=n commit -qm fix 2>/dev/null
  echo untracked > "$A/Leads/atlas/untracked.md"
}

A="$T/am"; S="$T/state"
mkfix "$A"
before="$(cd "$A" && find . -path ./.git -prune -o -type f -print0 | xargs -0 shasum -a 256 | sort | shasum -a 256)"

out="$(bash "$COPY" "$A" "$S" 2>&1)"; rc=$?
eq "copy exits 0" "$rc" 0
eq "tracked file copied" "$(cat "$S/Leads/lead-1/board.md")" board
eq "untracked file copied" "$(cat "$S/Leads/atlas/untracked.md")" untracked
eq "ignored file copied" "$(cat "$S/Leads/atlas/ignored.log")" ignored
eq "dotfile copied" "$(cat "$S/Leads/atlas/.dotfile")" hidden
eq "spaced name copied" "$(cat "$S/Leads/atlas/sub/file with space.md")" spaced
eq "lead-ux copied" "$(cat "$S/lead-ux/notes/n.md")" ux
[ ! -e "$S/Leads/lead-1/LEDGER.md" ] && ok "ledger not in main copy" || bad "ledger not in main copy" present
[ ! -e "$S/Leads/x/.git" ] && ok ".git folder skipped" || bad ".git folder skipped" present
[ ! -e "$S/other.txt" ] && ok "other top-level not copied" || bad "other top-level not copied" present
SP="$(cd -P "$S" && pwd)"
want_roster="$(printf '**owner: Robin**\n\n```fleet\nlead-1\t%s/Leads/lead-1\natlas-ic-1\t%s/Leads/atlas\tflag-x\nux-1\t%s/lead-ux/notes\nelsewhere-1\t/opt/elsewhere\nsibling-1\t%s2/Leads/x\n```\n' "$SP" "$SP" "$SP" "$A")"
eq "roster rows under Leads/ and lead-ux/ follow the copy, others untouched" "$(cat "$S/roster.md")" "$want_roster"
eq "head recorded" "$(cat "$S/migrate/agentmgmt-head")" "$(git -C "$A" rev-parse HEAD)"
eq "old path recorded" "$(cat "$S/migrate/agentmgmt-path")" "$(cd -P "$A" && pwd)"
M="$S/migrate/copy-manifest.tsv"
eq "manifest lines" "$(wc -l < "$M" | tr -d ' ')" 6
eq "manifest hash of spaced file" "$(grep -F 'file with space.md' "$M" | cut -f2)" "$(sha "$A/Leads/atlas/sub/file with space.md")"
eq "manifest path form" "$(grep -F 'board.md' "$M" | cut -f1)" "Leads/lead-1/board.md"
grep -q LEDGER "$M" && bad "manifest omits ledger" present || ok "manifest omits ledger"
after="$(cd "$A" && find . -path ./.git -prune -o -type f -print0 | xargs -0 shasum -a 256 | sort | shasum -a 256)"
eq "source untouched" "$after" "$before"

# refuses a second main copy
bash "$COPY" "$A" "$S" >/dev/null 2>&1; rc=$?
eq "refuses when Leads/ present" "$rc" 1
S2="$T/state2"; mkdir -p "$S2/lead-ux"
bash "$COPY" "$A" "$S2" >/dev/null 2>&1; rc=$?
eq "refuses when lead-ux/ present" "$rc" 1

# check-copy
out="$(bash "$CHECK" "$S" 2>&1)"; rc=$?
eq "check clean text" "$out" "6 files, 0 missing, 0 differing"
eq "check clean exit" "$rc" 0
out="$(FLEET_HOME="$S" bash "$CHECK" 2>&1)"
eq "check defaults to FLEET_HOME" "$out" "6 files, 0 missing, 0 differing"

# source edited after copy: still clean
echo changed >> "$A/Leads/lead-1/board.md"
out="$(bash "$CHECK" "$S" 2>&1)"; rc=$?
eq "source edit after copy ignored" "$out" "6 files, 0 missing, 0 differing"
eq "source edit exit" "$rc" 0

# copy edited
echo edit >> "$S/Leads/atlas/sub/file with space.md"
out="$(bash "$CHECK" "$S" 2>&1)"; rc=$?
echo "$out" | tail -1 | grep -qx "6 files, 0 missing, 1 differing" && ok "copy edit is 1 differing" || bad "copy edit is 1 differing" "$out"
eq "copy edit exit" "$rc" 1
echo spaced > "$S/Leads/atlas/sub/file with space.md"

# copy file deleted
rm "$S/lead-ux/notes/n.md"
out="$(bash "$CHECK" "$S" 2>&1)"; rc=$?
echo "$out" | tail -1 | grep -qx "6 files, 1 missing, 0 differing" && ok "deleted copy file is 1 missing" || bad "deleted copy file is 1 missing" "$out"
eq "missing exit" "$rc" 1
echo ux > "$S/lead-ux/notes/n.md"

# no manifest
out="$(bash "$CHECK" "$T/nowhere" 2>&1)"; rc=$?
eq "check without manifest exits 1" "$rc" 1

# ledger
S3="$T/state3"
bash "$COPY" --ledger "$A" "$S3" >/dev/null 2>&1; rc=$?
eq "ledger refused before main copy" "$rc" 1
[ ! -e "$S3/Leads/lead-1/LEDGER.md" ] && ok "refused ledger copies nothing" || bad "refused ledger copies nothing" present
git -C "$A" -c user.email=a@b -c user.name=n commit -q --allow-empty -m between 2>/dev/null
eq "main copy recorded the first head" "$(cat "$S/migrate/agentmgmt-head")" "$(git -C "$A" rev-parse HEAD~1)"
bash "$COPY" --ledger "$A" "$S" >/dev/null 2>&1; rc=$?
eq "ledger copy exits 0" "$rc" 0
eq "ledger copy re-records head" "$(cat "$S/migrate/agentmgmt-head")" "$(git -C "$A" rev-parse HEAD)"
eq "ledger copied" "$(cat "$S/Leads/lead-1/LEDGER.md")" ledger-body
eq "ledger-sha256 file" "$(cat "$S/migrate/ledger-sha256")" "$(sha "$A/Leads/lead-1/LEDGER.md")"
eq "ledger manifest line" "$(grep -F LEDGER.md "$M")" "$(printf 'Leads/lead-1/LEDGER.md\t%s' "$(sha "$A/Leads/lead-1/LEDGER.md")")"
out="$(bash "$CHECK" "$S" 2>&1)"; rc=$?
eq "check after ledger" "$out" "7 files, 0 missing, 0 differing"
bash "$COPY" --ledger "$A" "$S" >/dev/null 2>&1; rc=$?
eq "second ledger refused" "$rc" 1
eq "manifest still 7 lines" "$(wc -l < "$M" | tr -d ' ')" 7

# wrong or empty source
E1="$T/nolead"; mkdir -p "$E1/shared" "$E1/lead-ux"; echo r > "$E1/shared/roster.md"
bash "$COPY" "$E1" "$T/st-e1" >/dev/null 2>&1; rc=$?
eq "refuses source without Leads/" "$rc" 1
[ ! -e "$T/st-e1" ] && ok "no Leads/: state untouched" || bad "no Leads/: state untouched" present
E2="$T/noux"; mkdir -p "$E2/shared" "$E2/Leads"; echo r > "$E2/shared/roster.md"
bash "$COPY" "$E2" "$T/st-e2" >/dev/null 2>&1; rc=$?
eq "refuses source without lead-ux/" "$rc" 1
[ ! -e "$T/st-e2" ] && ok "no lead-ux/: state untouched" || bad "no lead-ux/: state untouched" present
mkdir -p "$T/st-empty/migrate"; : > "$T/st-empty/migrate/copy-manifest.tsv"
bash "$CHECK" "$T/st-empty" >/dev/null 2>&1; rc=$?
eq "check-copy fails on empty manifest" "$rc" 1

# short manifest: a shasum shim (PATH only, no production flag) fails on one file
A4="$T/am4"; mkfix "$A4"; echo p > "$A4/Leads/atlas/poison.md"
mkdir -p "$T/shim"
printf '#!/bin/bash\ncase "$*" in *poison*) exit 1;; esac\nexec /usr/bin/shasum "$@"\n' > "$T/shim/shasum"
chmod 755 "$T/shim/shasum"
PATH="$T/shim:$PATH" bash "$COPY" "$A4" "$T/st4" >/dev/null 2>&1; rc=$?
eq "short manifest exits 1" "$rc" 1
[ ! -e "$T/st4/migrate/copy-manifest.tsv" ] && ok "short manifest: none left" || bad "short manifest: none left" present
[ ! -e "$T/st4/migrate/copy-manifest.tsv.tmp" ] && ok "short manifest: no tmp left" || bad "short manifest: no tmp left" present

# ---- check-frozen ----
CF="$REPO/shared/migrate/check-frozen.sh"
FZ="$T/fz"; mkdir -p "$FZ"
FA="$FZ/am"; FS="$FZ/state"; mkfix "$FA"
bash "$COPY" "$FA" "$FS" >/dev/null 2>&1; bash "$COPY" --ledger "$FA" "$FS" >/dev/null 2>&1
chmod 444 "$FA/Leads/lead-1/LEDGER.md"
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; rc=$?
eq "frozen ok line" "$(echo "$out" | head -1)" "frozen: ok"
eq "frozen ok read-only" "$(echo "$out" | tail -1)" "old ledger: read-only"
eq "frozen ok exit" "$rc" 0
chmod 644 "$FA/Leads/lead-1/LEDGER.md"
out="$(FLEET_HOME="$FS" bash "$CF" "$FA" 2>&1)"; rc=$?
eq "frozen ok with path arg" "$(echo "$out" | head -1)" "frozen: ok"
eq "frozen writable" "$(echo "$out" | tail -1)" "old ledger: writable"
eq "frozen writable exit" "$rc" 0
echo more > "$FA/Leads/atlas/new-untracked.md"
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; rc=$?
eq "untracked file stays frozen" "$(echo "$out" | head -1)" "frozen: ok"
echo changed >> "$FA/shared/roster.md"
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; rc=$?
eq "tracked change" "$(echo "$out" | head -1)" "frozen: changed (tracked change)"
eq "tracked change exit" "$rc" 1
git -C "$FA" checkout -q -- shared/roster.md
git -C "$FA" -c user.email=a@b -c user.name=n commit -q --allow-empty -m later 2>/dev/null
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; rc=$?
eq "head mismatch" "$(echo "$out" | head -1)" "frozen: changed (HEAD differs)"
eq "head mismatch exit" "$rc" 1
git -C "$FA" reset -q --hard HEAD~1
echo extra >> "$FA/Leads/lead-1/LEDGER.md"; git -C "$FA" update-index --assume-unchanged Leads/lead-1/LEDGER.md
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; rc=$?
eq "ledger hash mismatch" "$(echo "$out" | head -1)" "frozen: changed (ledger hash differs)"
eq "ledger hash exit" "$rc" 1
git -C "$FA" update-index --no-assume-unchanged Leads/lead-1/LEDGER.md; git -C "$FA" checkout -q -- Leads/lead-1/LEDGER.md
out="$(FLEET_HOME="$FS" bash "$CF" 2>&1)"; eq "restored is ok again" "$(echo "$out" | head -1)" "frozen: ok"
for f in agentmgmt-head ledger-sha256 agentmgmt-path; do
  FS2="$FZ/state-$f"; cp -R "$FS" "$FS2"; rm -f "$FS2/migrate/$f"
  if [ "$f" = agentmgmt-path ]; then out="$(FLEET_HOME="$FS2" bash "$CF" 2>&1)"; rc=$?
  else out="$(FLEET_HOME="$FS2" bash "$CF" "$FA" 2>&1)"; rc=$?; fi
  eq "missing $f is unknown" "$(echo "$out" | head -1)" "frozen: unknown (no migrate/$f)"
  [ "$f" = agentmgmt-path ] || eq "missing $f still prints the ledger line" "$(echo "$out" | tail -1)" "old ledger: writable"
  eq "missing $f exit" "$rc" 1
done
FS3="$FZ/state-noled"; cp -R "$FS" "$FS3"; echo "$FZ/gone" > "$FS3/migrate/agentmgmt-path"
out="$(FLEET_HOME="$FS3" bash "$CF" 2>&1)"; rc=$?
eq "missing AgentMgmt folder is unknown" "$(echo "$out" | head -1)" "frozen: unknown (no such AgentMgmt folder)"
eq "missing folder exit" "$rc" 1
FA2="$FZ/am2"; cp -R "$FA" "$FA2"; rm -f "$FA2/Leads/lead-1/LEDGER.md"; echo "$FA2" > "$FS3/migrate/agentmgmt-path"
out="$(FLEET_HOME="$FS3" bash "$CF" 2>&1)"; rc=$?
eq "missing ledger is unknown" "$(echo "$out" | head -1)" "frozen: unknown (no old ledger)"
eq "missing ledger exit" "$rc" 1
echo "$out" | grep -q "^old ledger:" && bad "no ledger line without a ledger" "$out" || ok "no ledger line without a ledger"

# ---- install.sh: --home is the user's home, FLEET_HOME the state folder, the stamp moves only on a change ----
INS="$REPO/shared/migrate/install.sh"; IT="$T/inst"; mkdir -p "$IT/h1" "$IT/other-clone"
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
env -u FLEET_HOME bash "$INS" --repo "$REPO" --home "$IT/h1" --claude-home "$IT/c1" >/dev/null 2>&1
ST1="$IT/h1/.fleet-agent-mgmt/migrate/install-stamp"
[ -s "$ST1" ] && ok "install writes the stamp under <home>/.fleet-agent-mgmt by default" || bad "install writes the stamp under <home>/.fleet-agent-mgmt by default" "none"
eq "install default env.FLEET_HOME" "$(jq -r .env.FLEET_HOME "$IT/c1/settings.json")" "$IT/h1/.fleet-agent-mgmt"
s1="$(cat "$ST1")"; m1="$(mt "$ST1")"; sleep 1.1
env -u FLEET_HOME bash "$INS" --repo "$REPO" --home "$IT/h1" --claude-home "$IT/c1" >/dev/null 2>&1
eq "idempotent re-run leaves the stamp content" "$(cat "$ST1")" "$s1"
eq "idempotent re-run leaves the stamp mtime" "$(mt "$ST1")" "$m1"
env -u FLEET_HOME bash "$INS" --repo "$IT/other-clone" --home "$IT/h1" --claude-home "$IT/c1" >/dev/null 2>&1
[ "$(mt "$ST1")" -gt "$m1" ] && ok "a settings change moves the stamp" || bad "a settings change moves the stamp" "mtime $(mt "$ST1") vs $m1"
mkdir -p "$IT/h2"
FLEET_HOME="$IT/xstate" bash "$INS" --repo "$REPO" --home "$IT/h2" --claude-home "$IT/c2" >/dev/null 2>&1
[ -s "$IT/xstate/migrate/install-stamp" ] && ok "FLEET_HOME=/x install --home h writes the stamp under /x" || bad "FLEET_HOME=/x install --home h writes the stamp under /x" "none"
[ ! -e "$IT/h2/.fleet-agent-mgmt" ] && ok "no stamp under <home> when FLEET_HOME is set" || bad "no stamp under <home> when FLEET_HOME is set" "present"
eq "install honours exported FLEET_HOME in env.FLEET_HOME" "$(jq -r .env.FLEET_HOME "$IT/c2/settings.json")" "$IT/xstate"

# ---- check-live ----
CL="$REPO/shared/migrate/check-live.sh"; INST="$REPO/shared/migrate/install.sh"
CT="$T/cl dir"; mkdir -p "$CT"; OLDP="$CT/old AgentMgmt"; mkdir -p "$OLDP/shared/hooks" "$OLDP/shared/skills" "$CT/old AgentMgmt2"
CH="$CT/ch"; mkdir -p "$CH/skills"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\x27%s/shared/hooks/state-gate.sh\x27"}]}]}}\n' "$OLDP" > "$CH/settings.json"
ln -s "$OLDP/shared/skills/grilling" "$CH/skills/grilling"
tmux -L fam-test kill-server >/dev/null 2>&1
tmux -L fam-test new-session -d -s chk "sleep 300 # '$OLDP/x'"
out="$(CHECK_LIVE_TMUX_SOCKET=fam-test bash "$CL" --old "$OLDP" --claude-home "$CH" 2>&1)"; rc=$?
eq "check-live counts hook, link and pane" "$(echo "$out" | tail -1)" "old-repo paths: 3"
eq "check-live hit lines" "$(echo "$out" | grep -c '^hit: ')" 3
eq "check-live red exit" "$rc" 1
echo "$out" | grep -q "state-gate" && bad "hit lines hide content" "$out" || ok "hit lines hide content"
out="$(bash "$CL" --old "$CT/old AgentMgmt2" --claude-home "$CH" 2>&1)"; rc=$?
eq "prefix-sibling path: no match" "$(echo "$out" | tail -1)" "old-repo paths: 0"
eq "prefix-sibling exit" "$rc" 0
mkdir -p "$CT/h"; bash "$INST" --repo "$REPO" --home "$CT/h" --claude-home "$CH" >/dev/null 2>&1
tmux -L fam-test kill-server >/dev/null 2>&1
out="$(CHECK_LIVE_TMUX_SOCKET=fam-test bash "$CL" --old "$OLDP" --claude-home "$CH" 2>&1)"; rc=$?
eq "check-live after install" "$out" "old-repo paths: 0"
eq "after install exit" "$rc" 0
out="$(FLEET_HOME="$S" bash "$CL" --claude-home "$CH" 2>&1)"
eq "old path read from migrate/agentmgmt-path" "$out" "old-repo paths: 0"
out="$(FLEET_HOME="$T/nofleet" bash "$CL" --claude-home "$CH" 2>&1)"; rc=$?
eq "unknown old path" "$out" "old-repo paths: unknown (no migrate/agentmgmt-path)"
eq "unknown exit" "$rc" 1

# unreadable sources are unknown, never a silent 0
BAD="$CT/bad"; mkdir -p "$BAD/skills"; printf '{ not json %s/shared' "$OLDP" > "$BAD/settings.json"
out="$(bash "$CL" --old "$OLDP" --claude-home "$BAD" 2>&1)"; rc=$?
eq "invalid settings.json is unknown" "$out" "old-repo paths: unknown (settings.json unreadable)"; eq "invalid settings exit" "$rc" 1
out="$(bash "$CL" --old "$OLDP" --claude-home "$CT/none" 2>&1)"; rc=$?
eq "missing claude home is unknown" "$out" "old-repo paths: unknown (claude home missing)"; eq "missing home exit" "$rc" 1
NOSK="$CT/nosk"; mkdir -p "$NOSK"; echo '{}' > "$NOSK/settings.json"
out="$(bash "$CL" --old "$OLDP" --claude-home "$NOSK" 2>&1)"; rc=$?
eq "missing skills folder is unknown" "$out" "old-repo paths: unknown (skills folder missing)"; eq "missing skills exit" "$rc" 1
mkdir -p "$CT/shimbin" "$CT/tbin"
for x in dirname head bash env sh; do ln -sf "$(command -v $x)" "$CT/tbin/$x"; done
ln -sf "$(python3 -c 'import sys;print(sys.executable)')" "$CT/tbin/python3"
out="$(PATH="$CT/tbin" "$BASH" "$CL" --old "$OLDP" --claude-home "$CH" 2>&1)"; rc=$?
eq "tmux missing is unknown" "$out" "old-repo paths: unknown (tmux not found)"; eq "tmux missing exit" "$rc" 1
printf '#!/bin/sh\necho boom >&2\nexit 1\n' > "$CT/shimbin/tmux"; chmod 755 "$CT/shimbin/tmux"
out="$(PATH="$CT/shimbin:$PATH" bash "$CL" --old "$OLDP" --claude-home "$CH" 2>&1)"; rc=$?
eq "tmux error is unknown" "$out" "old-repo paths: unknown (tmux list-panes failed)"; eq "tmux error exit" "$rc" 1
out="$(CHECK_LIVE_TMUX_SOCKET=fam-test-absent bash "$CL" --old "$OLDP" --claude-home "$CH" 2>&1)"; rc=$?
eq "no tmux server counts 0 panes" "$out" "old-repo paths: 0"; eq "no server exit" "$rc" 0

out="$(bash "$CL" --rehearsal 2>&1)"; rc=$?
echo "$out" | sed 's/^/     /'
eq "rehearsal exit" "$rc" 0
echo "$out" | grep -qx "old-repo paths: 0" && ok "rehearsal old-repo paths" || bad "rehearsal old-repo paths" "$out"
echo "$out" | grep -qx "rehearsal lead turn: ok" && ok "rehearsal lead turn" || bad "rehearsal lead turn" "$out"
echo "$out" | grep -qx "rehearsal launch: ok" && ok "rehearsal launch" || bad "rehearsal launch" "$out"
out="$(bash "$CL" --rolled-back 2>&1)"; rc=$?
eq "rolled-back exit" "$rc" 0
echo "$out" | grep -qx "new-repo paths: 0" && ok "rolled-back new-repo paths" || bad "rolled-back new-repo paths" "$out"
tmux -L fam-test kill-server >/dev/null 2>&1

# ---- check-cutover ----
CC="$REPO/shared/migrate/check-cutover.sh"
CU="$T/cutover"; mkdir -p "$CU"
# cufix <name>: a fixture FLEET_HOME (git repo) with stamp, old AgentMgmt, copied ledger, roster, a worker STATE
cufix() {
  local F="$CU/$1" O="$CU/$1-old"
  mkdir -p "$F/migrate" "$F/Leads/lead-1" "$F/checks/lead-1" "$F/checks/atlas-ic-1" "$O/Leads/lead-1" "$CU/work dir"
  printf 'one\ntwo\n' > "$O/Leads/lead-1/LEDGER.md"; cp "$O/Leads/lead-1/LEDGER.md" "$F/Leads/lead-1/LEDGER.md"
  sha "$O/Leads/lead-1/LEDGER.md" > "$F/migrate/ledger-sha256"
  echo "$O" > "$F/migrate/agentmgmt-path"
  echo 2026-01-01T00:00:00Z > "$F/migrate/install-stamp"
  printf '2026-01-01T00:45:00Z\nFLEET_REPO=%q FLEET_HOME=%q claude -n atlas-ic-1 --permission-mode auto\n' "$REPO" "$F" > "$F/checks/atlas-ic-1/launch"
  printf '```fleet\nlead-1\t%s/Leads/lead-1\natlas-ic-1\t%s\n```\n' "$F" "$CU/work dir" > "$F/roster.md"
  echo state > "$F/checks/atlas-ic-1/STATE.md"; touch -t 202601010100 "$F/checks/atlas-ic-1/STATE.md"
  git -C "$F" init -q 2>/dev/null; git -C "$F" add -A 2>/dev/null
  GIT_COMMITTER_DATE=2026-01-01T01:00:00Z GIT_AUTHOR_DATE=2026-01-01T01:00:00Z git -C "$F" -c user.email=a@b -c user.name=n commit -qm c 2>/dev/null
  printf '2026-01-01T00:30:00Z pass lead-1\n2026-01-01T01:30:00Z pass lead-1\n2026-01-01T02:00:00Z pass lead-1\n' > "$F/checks/lead-1/state-gate.log"
}
runcc() { FLEET_HOME="$CU/$1" bash "$CC" "${@:2}" 2>&1; }
cufix a; out="$(runcc a lead)"; rc=$?
eq "cutover lead ok" "$(echo "$out" | tail -1)" "lead: ok"; eq "cutover lead ok exit" "$rc" 0
cufix a2; printf '```fleet\nlead-1\t%s/Leads/lead-1\n```\n' "$CU/a2-old" > "$CU/a2/roster.md"; out="$(runcc a2 lead)"; rc=$?
eq "cutover lead roster still on the old repo is red" "$out" "lead: red: roster lead-1 cwd $CU/a2-old/Leads/lead-1"; eq "cutover roster red exit" "$rc" 1
cufix a3; rm "$CU/a3/roster.md"; out="$(runcc a3 lead)"; rc=$?
eq "cutover lead without a roster is unknown" "$out" "lead: unknown (no roster at $CU/a3/roster.md)"; eq "cutover no roster exit" "$rc" 1
cufix b; sed -i.bak 2d "$CU/b/checks/lead-1/state-gate.log"; out="$(runcc b lead)"; rc=$?
echo "$out" | grep -q '^lead: red.*2 of 3 passes' && ok "cutover lead 2 passes red" || bad "cutover lead 2 passes red" "$out"; eq "cutover 2 passes exit" "$rc" 1
cufix c; printf '2026-01-01T00:10:00Z pass lead-1\n2026-01-01T00:20:00Z pass lead-1\n2026-01-01T00:30:00Z pass lead-1\n' > "$CU/c/checks/lead-1/state-gate.log"
out="$(runcc c lead)"; rc=$?
echo "$out" | grep -q '^lead: red.*no pass after a commit' && ok "cutover lead passes before commit red" || bad "cutover lead passes before commit red" "$out"; eq "cutover before-commit exit" "$rc" 1
cufix d; printf 'three\n' >> "$CU/d-old/Leads/lead-1/LEDGER.md"; out="$(runcc d lead)"; rc=$?
echo "$out" | grep -q '^lead: red.*old ledger changed' && echo "$out" | grep -qx 'new old-ledger line: three' && ok "cutover lead old ledger changed names new line" || bad "cutover lead old ledger changed names new line" "$out"; eq "cutover ledger exit" "$rc" 1
cufix e; rm "$CU/e/migrate/install-stamp"; out="$(runcc e lead)"; rc=$?
eq "cutover lead no stamp" "$out" "lead: unknown (no install stamp)"; eq "cutover no stamp exit" "$rc" 1
out="$(runcc e worker)"; eq "cutover worker no stamp" "$out" "worker: unknown (no install stamp)"
cufix f; rm -rf "$CU/f/.git"; out="$(runcc f lead)"; rc=$?
eq "cutover lead FLEET_HOME not git" "$out" "lead: unknown (FLEET_HOME is not a git repo)"; eq "cutover not git exit" "$rc" 1
cufix g; out="$(runcc g worker)"; rc=$?
eq "cutover worker ok" "$(echo "$out" | tail -1)" "worker: ok"; eq "cutover worker ok exit" "$rc" 0
echo "$out" | grep -qx 'worker qualifies: atlas-ic-1' && ok "cutover worker names who" || bad "cutover worker names who" "$out"
cufix h; touch -t 202512310100 "$CU/h/checks/atlas-ic-1/STATE.md"; out="$(runcc h worker)"; rc=$?
echo "$out" | grep -q '^worker: not yet (atlas-ic-1: STATE.md not newer' && ok "cutover worker STATE older than stamp" || bad "cutover worker STATE older than stamp" "$out"; eq "cutover worker old STATE exit" "$rc" 1
cufix i; printf '2026-01-01T00:45:00Z\nFLEET_REPO=%q FLEET_HOME=%q claude -n atlas-ic-1\n' "$CU/i-old" "$CU/i" > "$CU/i/checks/atlas-ic-1/launch"; out="$(runcc i worker)"; rc=$?
echo "$out" | grep -q '^worker: not yet (atlas-ic-1: launch receipt names the old AgentMgmt' && ok "cutover worker receipt names old repo" || bad "cutover worker receipt names old repo" "$out"; eq "cutover worker old repo exit" "$rc" 1
cufix k; rm "$CU/k/checks/atlas-ic-1/launch"; out="$(runcc k worker)"; rc=$?
echo "$out" | grep -q '^worker: not yet (atlas-ic-1: no launch receipt)' && ok "cutover worker fresh STATE but no receipt" || bad "cutover worker fresh STATE but no receipt" "$out"; eq "cutover no receipt exit" "$rc" 1
cufix l; sed -i.bak 1s/.*/2025-12-31T00:00:00Z/ "$CU/l/checks/atlas-ic-1/launch"; out="$(runcc l worker)"; rc=$?
echo "$out" | grep -q '^worker: not yet (atlas-ic-1: launch receipt not newer' && ok "cutover worker receipt older than stamp" || bad "cutover worker receipt older than stamp" "$out"; eq "cutover old receipt exit" "$rc" 1
cufix j; mkdir -p "$CU/j/checks/orbit-ic-1"; echo s > "$CU/j/checks/orbit-ic-1/STATE.md"; touch -t 202512310100 "$CU/j/checks/orbit-ic-1/STATE.md"
out="$(runcc j worker atlas-ic-1)"; eq "cutover worker by name" "$(echo "$out" | tail -1)" "worker: ok"
out="$(runcc j worker orbit-ic-1)"; rc=$?; echo "$out" | grep -q '^worker: not yet (orbit-ic-1:' && ok "cutover worker by name, not qualifying" || bad "cutover worker by name, not qualifying" "$out"; eq "cutover by-name red exit" "$rc" 1

echo "$pass pass, $fail fail"
[ "$fail" = 0 ]
