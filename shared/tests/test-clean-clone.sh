#!/bin/bash
# A fresh copy of the repo carries none of its owner's data.
#   test-clean-clone.sh scan [<dir>]  with <dir>, that tree and its git log; without, make-repo.sh of HEAD, cloned,
#                                 scanned: "owner tokens: N hits"; exit 1 on a hit
#   test-clean-clone.sh planted   three invented tokens planted in a temp clone: "planted: 3 of 3 caught"
#   test-clean-clone.sh launch    install.sh, shape-up.sh, agent-up.sh from a clone at a path with a space: "launch: ok"
#   test-clean-clone.sh           the cases below, planted, install, launch; "N pass, 0 fail"
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
MAKE="$REPO/shared/migrate/make-repo.sh"
export PYTHONDONTWRITEBYTECODE=1
TMPS=()
LAUNCH_SOCK=""
cleanup() {
  local t
  # only the test's own tmux socket, never the default server
  [ -z "$LAUNCH_SOCK" ] || tmux -L "$LAUNCH_SOCK" kill-server >/dev/null 2>&1
  for t in "${TMPS[@]}"; do rm -rf "$t"; done
}
trap cleanup EXIT
tmp() { local t; t="$(mktemp -d)"; TMPS+=("$t"); echo "$t"; }
RHOME="$(python3 -c 'import pwd,os;print(pwd.getpwuid(os.getuid()).pw_dir)')"

# scan_dir <clone>: needs FLEET_HOME exported. Prints the hits, the token list line and the total.
scan_dir() {
python3 - "$REPO/shared/hooks" "$1" "$RHOME" <<'PY'
import os, re, subprocess, sys
hooks, clone, home = sys.argv[1:4]
sys.path.insert(0, hooks)
import leak_check
pats = [(l, re.compile(rx)) for l, rx in leak_check.token_patterns()]
ntok = len(pats)
if len(home) > 1:
    pats.append(("home path", re.compile(re.escape(home) + r"(?![A-Za-z0-9_])")))
hits = []
def check(where, text):
    for i, line in enumerate(text.splitlines(), 1):
        for label, rx in pats:
            if rx.search(line):
                hits.append("%s:%d: %s" % (where, i, label))
for root, dirs, files in os.walk(clone):
    if ".git" in dirs:
        dirs.remove(".git")
    for f in files:
        p = os.path.join(root, f)
        if os.path.islink(p):
            continue
        with open(p, "rb") as fh:
            check(os.path.relpath(p, clone), fh.read().decode("latin-1"))
shas = subprocess.run(["git", "-C", clone, "rev-list", "--all"], capture_output=True, text=True).stdout.split()
for sha in shas:
    msg = subprocess.run(["git", "-C", clone, "show", "-s", "--format=%B%n%an%n%cn", sha],
                         capture_output=True, text=True).stdout
    check("commit " + sha[:8], msg)
for h in hits:
    print(h)
print("token list: %d tokens" % ntok if ntok else "token list: absent, home paths only")
print("owner tokens: %d hits" % len(hits))
sys.exit(1 if hits else 0)
PY
}

# fresh_clone: make-repo.sh of the source, cloned with --no-local; prints the clone path
fresh_clone() {
  local a b; a="$(tmp)"; b="$(tmp)"
  MAKE_REPO_NO_SCAN=1 bash "$MAKE" "$a/repo" >/dev/null 2>&1 || return 1
  git clone -q --no-local "$a/repo" "$b/clone" >/dev/null 2>&1 || return 1
  echo "$b/clone"
}

cmd_scan() {
  local c
  if [ $# -ge 1 ]; then
    [ -d "$1" ] || { echo "scan: no such folder: $1"; return 1; }
    scan_dir "$(cd -P "$1" && pwd)"; return
  fi
  c="$(fresh_clone)" || { echo "scan: make-repo or clone failed"; return 1; }
  scan_dir "$c"
}

mk_tokens() { # <home>: invented list; strings built in parts so this file never holds them
  printf '# invented\n%s\n%s\n' "acme""corp" "ZED-<digits>" > "$1/leak-tokens.txt"
}

cmd_planted() {
  local fh c out n=0
  fh="$(tmp)"; mk_tokens "$fh"; export FLEET_HOME="$fh"
  c="$(fresh_clone)" || { echo "planted: clone failed"; return 1; }
  echo "see acme""corp today" > "$c/plant-file.txt"
  mkdir -p "$c/mods/demo/tests"; echo "{\"k\": \"ZED-""77\"}" > "$c/mods/demo/tests/fixture.json"
  git -C "$c" add -A
  git -C "$c" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.test \
    commit -q -m "ref ZED-""12 in body" >/dev/null 2>&1
  out="$(scan_dir "$c")"
  echo "$out" | grep -q '^plant-file.txt:1: ' && n=$((n+1))
  echo "$out" | grep -q '^commit [0-9a-f]*:[0-9]*: ZED-<digits>' && n=$((n+1))
  echo "$out" | grep -q '^mods/demo/tests/fixture.json:1: ' && n=$((n+1))
  echo "planted: $n of 3 caught"
  [ "$n" -eq 3 ]
}

cmd_launch() {
  local sp="$PATH" sh="$HOME" rc
  _launch; rc=$?
  PATH="$sp"; HOME="$sh"; unset FLEET_HOME FLEET_REPO
  [ -z "$LAUNCH_SOCK" ] || tmux -L "$LAUNCH_SOCK" kill-server >/dev/null 2>&1
  return "$rc"
}

_launch() {
  local base clone home ch fh bin logs rt n i why=""
  unset TMUX
  rt="$(command -v tmux)" || { echo "launch: tmux not found"; return 1; }
  base="$(tmp)/with space"; mkdir -p "$base"
  bash "$MAKE" "$base/src" >/dev/null 2>&1 || { echo "launch: make-repo failed"; return 1; }
  git clone -q --no-local "$base/src" "$base/my clone" >/dev/null 2>&1 || { echo "launch: clone failed"; return 1; }
  clone="$(cd -P "$base/my clone" && pwd)"
  home="$(tmp)"; ch="$home/.claude"; bin="$(tmp)"; logs="$(tmp)"
  # tmux wrapper pins the test socket; stub claude records argv and env
  printf '#!/bin/bash\nexec "%s" -L fam-test "$@"\n' "$rt" > "$bin/tmux"
  cat > "$bin/claude" <<STUB
#!/bin/bash
name=x; prev=""
for a in "\$@"; do [ "\$prev" = "-n" ] && name="\$a"; prev="\$a"; done
{ for a in "\$@"; do echo "arg: \$a"; done
  echo "FLEET_REPO=\${FLEET_REPO-unset}"; echo "FLEET_HOME=\${FLEET_HOME-unset}"; echo "PWD=\$PWD"; } > "$logs/\$name.log"
STUB
  chmod +x "$bin/tmux" "$bin/claude"
  LAUNCH_SOCK=fam-test; tmux -L fam-test kill-server >/dev/null 2>&1
  export PATH="$bin:$PATH" HOME="$home"; unset FLEET_HOME FLEET_REPO
  bash "$clone/shared/migrate/install.sh" --repo "$clone" --home "$home" --claude-home "$ch" >/dev/null 2>&1 \
    || { echo "launch: install.sh failed"; return 1; }
  fh="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["env"]["FLEET_HOME"])' "$ch/settings.json")"
  [ "$fh" = "$home/.fleet-agent-mgmt" ] || { echo "launch: settings FLEET_HOME is $fh"; return 1; }
  export FLEET_HOME="$fh"; mkdir -p "$fh" "$home/atlas"
  sed "s|/path/to/atlas|$home/atlas|" "$clone/shared/launch/roster.example.md" > "$fh/roster.md"
  bash "$clone/shared/launch/shape-up.sh" idea-one >/dev/null 2>&1 || why="shape-up failed"
  bash "$clone/shared/launch/agent-up.sh" atlas-ic-1 >/dev/null 2>&1 || why="$why agent-up failed"
  i=0; while [ "$i" -lt 50 ]; do
    [ -f "$logs/shape-idea-one.log" ] && [ -f "$logs/atlas-ic-1.log" ] && break
    sleep 0.2; i=$((i+1))
  done
  for n in shape-idea-one atlas-ic-1; do
    [ -f "$logs/$n.log" ] || { why="$why no stub run for $n"; continue; }
    grep -q -x "FLEET_REPO=$clone" "$logs/$n.log" || why="$why $n FLEET_REPO"
    grep -q -x "FLEET_HOME=$fh" "$logs/$n.log" || why="$why $n FLEET_HOME"
  done
  grep -q -x "arg: $clone/shared/launch/ic-settings.json" "$logs/atlas-ic-1.log" 2>/dev/null || why="$why ic settings path"
  grep -q -x "arg: $clone/shared/launch/shape-settings.json" "$logs/shape-idea-one.log" 2>/dev/null || why="$why shape settings path"
  grep -q -x "PWD=$home/atlas" "$logs/atlas-ic-1.log" 2>/dev/null || why="$why agent cwd"
  [ -f "$fh/shaping/idea-one/CLAUDE.md" ] || why="$why shaping map"
  rm -rf "${base%/with space}" "$home" "$bin" "$logs"
  if [ -n "$why" ]; then echo "launch: FAIL$why"; return 1; fi
  echo "launch: ok"
}

# install_cases: install.sh against temp homes only; every call names --claude-home and --home
install_cases() {
  local I="$REPO/shared/migrate/install.sh" h ch out rc a b n
  h="$(tmp)"; ch="$h/.claude"
  out="$(bash "$I" --repo "$REPO" --home "$h" --claude-home "$ch" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok install_empty_home_runs || bad install_empty_home_runs "rc=$rc $out"
  python3 - "$ch/settings.json" "$REPO" "$h" <<'PY' && ok install_empty_home_settings || bad install_empty_home_settings "settings wrong"
import json, sys
s = json.load(open(sys.argv[1])); repo = sys.argv[2]; home = sys.argv[3]
assert s["env"]["FLEET_REPO"] == repo and s["env"]["FLEET_HOME"] == home + "/.fleet-agent-mgmt"
cmds = [(ev, h["command"]) for ev, es in s["hooks"].items() for e in es for h in e["hooks"]]
assert sorted(cmds) == [("SessionStart", repo + "/shared/hooks/postcompact-boot.sh"), ("Stop", repo + "/shared/hooks/state-gate.sh")], cmds
assert "_comment" not in s
PY
  n="$(find "$ch/skills" -type l | wc -l | tr -d ' ')"
  [ "$n" = "14" ] && [ "$(readlink "$ch/skills/grilling")" = "$REPO/shared/skills/grilling" ] && [ ! -e "$ch/skills/foundations" ] \
    && ok install_14_skill_links || bad install_14_skill_links "n=$n"
  [ "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$ch/settings.json")" = "0o600" ] \
    && ok install_fresh_file_mode_600 || bad install_fresh_file_mode_600 "not 600"
  ls "$ch"/settings.json.pre-install-* >/dev/null 2>&1 && bad install_no_backup_when_no_file "backup made" || ok install_no_backup_when_no_file

  # over a settings file with user keys and an old fleet hook from another clone
  h="$(tmp)"; ch="$h/.claude"; mkdir -p "$ch/skills"
  cat > "$ch/settings.json" <<'JS'
{"model": "x", "env": {"KEEP": "1"},
 "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "/old/clone/shared/hooks/state-gate.sh"}]},
                    {"hooks": [{"type": "command", "command": "/usr/local/bin/mine.sh"}]}],
           "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/u/pre.sh"}]}]}}
JS
  chmod 600 "$ch/settings.json"
  ln -s /old/clone/shared/skills/grilling "$ch/skills/grilling"
  mkdir -p "$ch/skills/closing-a-rung"; echo mine > "$ch/skills/closing-a-rung/keep.txt"
  out="$(bash "$I" --repo "$REPO" --home "$h" --claude-home "$ch" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok install_over_existing_runs || bad install_over_existing_runs "rc=$rc $out"
  python3 - "$ch/settings.json" "$REPO" <<'PY' && ok install_replaces_old_hook_keeps_user_keys || bad install_replaces_old_hook_keeps_user_keys "settings wrong"
import json, sys
s = json.load(open(sys.argv[1])); repo = sys.argv[2]
assert s["model"] == "x" and s["env"]["KEEP"] == "1" and s["env"]["FLEET_REPO"] == repo
stop = [h["command"] for e in s["hooks"]["Stop"] for h in e["hooks"]]
assert sorted(stop) == sorted(["/usr/local/bin/mine.sh", repo + "/shared/hooks/state-gate.sh"]), stop
assert s["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "/u/pre.sh"
assert len(s["hooks"]["SessionStart"]) == 1
PY
  [ "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$ch/settings.json")" = "0o600" ] \
    && ok install_keeps_mode_600 || bad install_keeps_mode_600 "mode changed"
  ls "$ch"/settings.json.pre-install-* >/dev/null 2>&1 && grep -q '/old/clone' "$ch"/settings.json.pre-install-* \
    && ok install_backup_exists || bad install_backup_exists "no backup holding the old file"
  [ "$(readlink "$ch/skills/grilling")" = "$REPO/shared/skills/grilling" ] && ok install_repoints_link || bad install_repoints_link "$(readlink "$ch/skills/grilling")"
  [ -d "$ch/skills/closing-a-rung" ] && [ ! -L "$ch/skills/closing-a-rung" ] && [ -f "$ch/skills/closing-a-rung/keep.txt" ] \
    && echo "$out" | grep -q 'skipped.*closing-a-rung' && ok install_real_folder_skipped || bad install_real_folder_skipped "$out"

  # the install stamp: one UTC line, written by a successful run
  [ "$(wc -l < "$h/.fleet-agent-mgmt/migrate/install-stamp" | tr -d ' ')" = 1 ] \
    && grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$h/.fleet-agent-mgmt/migrate/install-stamp" \
    && ok install_writes_stamp || bad install_writes_stamp "$(cat "$h/.fleet-agent-mgmt/migrate/install-stamp" 2>&1)"

  # second run changes nothing
  a="$(cat "$ch/settings.json")"; n="$(ls "$ch" | wc -l | tr -d ' ')"
  out="$(bash "$I" --repo "$REPO" --home "$h" --claude-home "$ch" 2>&1)"; rc=$?
  b="$(cat "$ch/settings.json")"
  [ "$rc" -eq 0 ] && [ "$a" = "$b" ] && [ "$n" = "$(ls "$ch" | wc -l | tr -d ' ')" ] && ok install_idempotent || bad install_idempotent "rc=$rc"
  echo "$out" | grep -v 'skipped' | grep -q '^changed' && bad install_second_run_silent "$out" || ok install_second_run_silent

  # a clone path with a space: each written hook command must run under sh -c
  local t cl cmd got k=0
  t="$(tmp)"; cl="$t/a b/clone"; h="$t/home"; ch="$h/.claude"
  mkdir -p "$cl/shared/hooks" "$cl/shared/skills" "$ch"
  cp "$REPO/shared/hooks/settings-hooks.json" "$cl/shared/hooks/"
  for n in postcompact-boot state-gate; do
    printf '#!/bin/sh\necho stub-ran\n' > "$cl/shared/hooks/$n.sh"; chmod +x "$cl/shared/hooks/$n.sh"
  done
  cl="$(cd -P "$cl" && pwd)"
  # old bare-path entry for the same script
  printf '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "%s/shared/hooks/state-gate.sh"}]}]}}\n' "$cl" > "$ch/settings.json"
  out="$(bash "$I" --repo "$cl" --home "$h" --claude-home "$ch" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok install_space_path_runs || bad install_space_path_runs "rc=$rc $out"
  while IFS= read -r cmd; do
    got="$(sh -c "$cmd" 2>&1)"; [ "$got" = "stub-ran" ] && k=$((k+1))
  done < <(python3 -c 'import json,sys
for es in json.load(open(sys.argv[1]))["hooks"].values():
    for e in es:
        for h in e["hooks"]: print(h["command"])' "$ch/settings.json")
  [ "$k" = "2" ] && ok install_space_path_commands_execute || bad install_space_path_commands_execute "ran $k of 2"
  [ "$(grep -c 'state-gate' "$ch/settings.json")" = "1" ] && ok install_bare_entry_replaced_not_duplicated || bad install_bare_entry_replaced_not_duplicated "$(grep -c state-gate "$ch/settings.json")"
  a="$(cat "$ch/settings.json")"
  bash "$I" --repo "$cl" --home "$h" --claude-home "$ch" >/dev/null 2>&1
  [ "$a" = "$(cat "$ch/settings.json")" ] && ok install_space_path_idempotent || bad install_space_path_idempotent "changed on rerun"

  # --repo B only names the path: the template is the running clone's, never B's
  local rb rb2
  t="$(tmp)"; rb="$(cd -P "$t" && pwd)/repo-b"; rb2="$(cd -P "$t" && pwd)/repo-b2"
  mkdir -p "$rb/shared/skills/grilling" "$rb2/shared/hooks" "$rb2/shared/skills/grilling"
  touch "$rb/shared/skills/grilling/SKILL.md" "$rb2/shared/skills/grilling/SKILL.md"
  printf '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "@FLEET_REPO@/shared/hooks/other-b.sh"}]}]}}\n' > "$rb2/shared/hooks/settings-hooks.json"
  for r in "$rb" "$rb2"; do
    h="$t/home-$(basename "$r")"; ch="$h/.claude"
    out="$(bash "$I" --repo "$r" --home "$h" --claude-home "$ch" 2>&1)"; rc=$?
    n="$(basename "$r")"
    [ "$rc" -eq 0 ] && ok "install_repo_flag_${n}_runs" || bad "install_repo_flag_${n}_runs" "rc=$rc $out"
    python3 - "$ch/settings.json" "$r" <<'PY' && ok "install_repo_flag_${n}_own_template" || bad "install_repo_flag_${n}_own_template" "settings wrong"
import json, sys
s = json.load(open(sys.argv[1])); repo = sys.argv[2]
cmds = sorted(h["command"] for es in s["hooks"].values() for e in es for h in e["hooks"])
assert cmds == [repo + "/shared/hooks/postcompact-boot.sh", repo + "/shared/hooks/state-gate.sh"], cmds
assert s["env"]["FLEET_REPO"] == repo
PY
    [ "$(readlink "$ch/skills/grilling")" = "$r/shared/skills/grilling" ] && ok "install_repo_flag_${n}_link" || bad "install_repo_flag_${n}_link" "$(readlink "$ch/skills/grilling")"
  done
}


# ---- the cases ----
pass=0; fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1: $2"; }

synth_src() { # a tiny source repo with owner folders and a fixture holding /Users/owner
  local s; s="$(tmp)"
  git -C "$s" init -q
  mkdir -p "$s/Leads/lead-1" "$s/TechLeads/x" "$s/lead-ux" "$s/archive" "$s/shared" "$s/mods/fleet-console/tests"
  echo a > "$s/Leads/lead-1/a"; echo a > "$s/TechLeads/x/a"; echo a > "$s/lead-ux/a"; echo a > "$s/archive/a"
  echo keep > "$s/shared/keep.txt"
  echo '{"cwd": "/Users/owner/proj"}' > "$s/mods/fleet-console/tests/f.json"
  git -C "$s" add -A
  git -C "$s" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.test commit -q -m init
  echo "$s"
}

run_cases() {
  local src d out rc fh c
  src="$(synth_src)"; export MAKE_REPO_SRC="$src"
  d="$(tmp)"; fh="$(tmp)"; export FLEET_HOME="$fh"
  # make-repo
  if bash "$MAKE" "$d/r" >/dev/null 2>&1; then ok make_repo_runs; else bad make_repo_runs "failed"; fi
  [ "$(git -C "$d/r" rev-list --all | wc -l | tr -d ' ')" = "1" ] && ok make_repo_one_commit || bad make_repo_one_commit "not 1"
  out="$(git -C "$d/r" log -1 --format='%an|%ae|%cn|%ce')"
  [ "$out" = "fleet-agent-mgmt|fleet-agent-mgmt@users.noreply.github.com|fleet-agent-mgmt|fleet-agent-mgmt@users.noreply.github.com" ] \
    && ok make_repo_identity || bad make_repo_identity "$out"
  if [ ! -e "$d/r/Leads" ] && [ ! -e "$d/r/TechLeads" ] && [ ! -e "$d/r/lead-ux" ] && [ ! -e "$d/r/archive" ] \
     && [ -f "$d/r/shared/keep.txt" ]; then ok make_repo_excludes; else bad make_repo_excludes "$(ls "$d/r")"; fi
  out="$(bash "$MAKE" "$d/r" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok make_repo_refuses_existing || bad make_repo_refuses_existing "rc=$rc"
  [ -z "$(git -C "$d/r" status --porcelain)" ] && ok make_repo_clean_tree || bad make_repo_clean_tree "dirty"

  [ "$(git -C "$d/r" symbolic-ref --short HEAD)" = main ] && ok make_repo_branch_main || bad make_repo_branch_main "$(git -C "$d/r" symbolic-ref --short HEAD)"
  # make-repo runs the scan itself: the output says so, a hit exits 1
  out="$(bash "$MAKE" "$d/r2" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && echo "$out" | grep -q 'owner tokens: 0 hits' && ok make_repo_runs_scan || bad make_repo_runs_scan "rc=$rc $out"
  out="$(MAKE_REPO_NO_SCAN=1 bash "$MAKE" "$d/r3" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ! echo "$out" | grep -q 'owner tokens' && ok make_repo_scan_guard || bad make_repo_scan_guard "rc=$rc $out"
  mk_tokens "$fh"; echo "see acme""corp" > "$src/leak.txt"
  git -C "$src" add -A; git -C "$src" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.test commit -q -m leak
  out="$(bash "$MAKE" "$d/r4" 2>&1)"; rc=$?
  [ "$rc" -eq 1 ] && echo "$out" | grep -q '^leak.txt:1: ' && ok make_repo_hit_exits_1 || bad make_repo_hit_exits_1 "rc=$rc $out"
  git -C "$src" rm -q leak.txt; git -C "$src" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.test commit -q -m unleak
  # scan <dir>: that tree, no make-repo
  out="$(bash "$HERE/test-clean-clone.sh" scan "$d/r4" 2>&1)"; rc=$?
  [ "$rc" -eq 1 ] && echo "$out" | grep -q '^leak.txt:1: ' && ok scan_dir_arg_hit || bad scan_dir_arg_hit "rc=$rc $out"
  rm -f "$fh/leak-tokens.txt"
  out="$(bash "$HERE/test-clean-clone.sh" scan "$d/r" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok scan_dir_arg_clean || bad scan_dir_arg_clean "rc=$rc $out"
  # scan: no list
  c="$(fresh_clone)"
  out="$(scan_dir "$c")"; rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'token list: absent, home paths only' && echo "$out" | grep -q 'owner tokens: 0 hits'; then
    ok scan_absent_list_clean; else bad scan_absent_list_clean "rc=$rc $out"; fi
  # /Users/owner in a fixture is not a hit
  echo "$out" | grep -q 'fixture\|f.json' && bad scan_ignores_other_users "$out" || ok scan_ignores_other_users
  # home path caught with no list
  echo "path $RHOME/x" > "$c/h.txt"
  out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 1 ] && echo "$out" | grep -q '^h.txt:1: home path' && ok scan_home_path_hit || bad scan_home_path_hit "rc=$rc $out"
  echo "path $RHOME""ward/x" > "$c/h.txt"
  out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 0 ] && ok scan_home_path_bounded || bad scan_home_path_bounded "rc=$rc $out"
  rm -f "$c/h.txt"
  # scan: with list
  mk_tokens "$fh"
  out="$(scan_dir "$c")"; rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'token list: 2 tokens' && echo "$out" | grep -q 'owner tokens: 0 hits'; then
    ok scan_list_clean; else bad scan_list_clean "rc=$rc $out"; fi
  echo "ACME""CORP and ZED-""9" > "$c/t.txt"
  out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 1 ] && [ "$(echo "$out" | grep -c '^t.txt:1: ')" = "2" ] && echo "$out" | grep -q 'owner tokens: 2 hits' \
    && ok scan_token_case_and_regex || bad scan_token_case_and_regex "rc=$rc $out"
  echo "acme""corporation ZED-x xZED-""9 ZED-""9y" > "$c/t.txt"
  out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 0 ] && ok scan_word_bounded || bad scan_word_bounded "rc=$rc $out"
  rm -f "$c/t.txt"
  # commit author name caught
  git -C "$c" -c commit.gpgsign=false -c user.name="Mr acme""corp" -c user.email=t@example.test commit -q --allow-empty -m x
  out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 1 ] && echo "$out" | grep -q '^commit ' && ok scan_author_name_hit || bad scan_author_name_hit "rc=$rc $out"
  # dirs gone from the scan: owner folder content never reaches the clone
  echo "acme""corp" > "$src/Leads/lead-1/a"
  git -C "$src" add -A; git -C "$src" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.test commit -q -m owner
  c="$(fresh_clone)"; out="$(scan_dir "$c")"; rc=$?
  [ "$rc" -eq 0 ] && ok scan_source_owner_folders_skipped || bad scan_source_owner_folders_skipped "rc=$rc $out"
  unset MAKE_REPO_SRC FLEET_HOME

  # planted, against the real HEAD
  out="$(cmd_planted)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$out" = "planted: 3 of 3 caught" ] && ok planted_3_of_3 || bad planted_3_of_3 "rc=$rc $out"
  install_cases
  out="$(cmd_launch)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$out" = "launch: ok" ] && ok launch_ok || bad launch_ok "rc=$rc $out"
}

case "${1:-}" in
  scan) export FLEET_HOME="${FLEET_HOME:-$HOME/.fleet-agent-mgmt}"; shift; cmd_scan "$@"; exit $? ;;
  planted) cmd_planted; exit $? ;;
  launch) cmd_launch; exit $? ;;
  "") run_cases; echo "$pass pass, $fail fail"; [ "$fail" -eq 0 ] ;;
  *) echo "usage: test-clean-clone.sh [scan [<dir>]|planted|launch]" >&2; exit 2 ;;
esac
