#!/bin/bash
# Tests shared/lib/paths.sh and paths.py. Temp folders and a temp HOME only.
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1: $2"; }

# run_sh <lib dir> <body>: sources paths.sh from <lib dir>, then runs <body>
run_sh() { bash -c '. "$1/paths.sh"; shift; eval "$1"' _ "$1" "$2"; }
# run_py <lib dir> <body>: imports paths.py from <lib dir>, then runs <body>
run_py() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from paths import FLEET_REPO, FLEET_HOME, need_home; exec(sys.argv[2])' "$1" "$2"; }

LIB="$REPO/shared/lib"
HOME_T="$T/home"; mkdir -p "$HOME_T/h"

for impl in sh py; do
  if [ "$impl" = sh ]; then
    pr() { run_sh "$1" 'echo "$FLEET_REPO"'; }
    ph() { run_sh "$1" 'echo "$FLEET_HOME"'; }
    pn() { run_sh "$1" 'fleet_need_home'; }
  else
    pr() { run_py "$1" 'print(FLEET_REPO)'; }
    ph() { run_py "$1" 'print(FLEET_HOME)'; }
    pn() { run_py "$1" 'need_home()'; }
  fi

  # repo_from_any_cwd
  got="$(cd "$T" && HOME="$HOME_T" pr "$LIB" 2>&1)"
  [ "$got" = "$REPO" ] && ok "repo_from_any_cwd/$impl" || bad "repo_from_any_cwd/$impl" "got '$got' want '$REPO'"

  # home_from_env
  got="$(HOME="$HOME_T" FLEET_HOME="$HOME_T/h" ph "$LIB" 2>&1)"
  [ "$got" = "$HOME_T/h" ] && ok "home_from_env/$impl" || bad "home_from_env/$impl" "got '$got'"

  # unset_home_defaults (unset and empty both default)
  got="$(unset FLEET_HOME; HOME="$HOME_T" ph "$LIB" 2>&1)"
  got2="$(HOME="$HOME_T" FLEET_HOME= ph "$LIB" 2>&1)"
  if [ "$got" = "$HOME_T/.fleet-agent-mgmt" ] && [ "$got2" = "$got" ]; then ok "unset_home_defaults/$impl"
  else bad "unset_home_defaults/$impl" "got '$got' / '$got2'"; fi

  # missing_home_exit_2
  err="$(HOME="$HOME_T" FLEET_HOME="$HOME_T/nope" pn "$LIB" 2>&1 >/dev/null)"; rc=$?
  want="FLEET_HOME $HOME_T/nope missing: run shared/migrate/install.sh"
  if [ "$rc" = 2 ] && [ "$err" = "$want" ]; then ok "missing_home_exit_2/$impl"
  else bad "missing_home_exit_2/$impl" "rc=$rc err='$err'"; fi

  # space_in_repo
  SP="$T/with space/clone"; mkdir -p "$SP/shared"; cp -R "$LIB" "$SP/shared/lib"
  want="$(cd -P "$SP" && pwd)"
  got="$(cd "$T" && HOME="$HOME_T" pr "$SP/shared/lib" 2>&1)"
  [ "$got" = "$want" ] && ok "space_in_repo/$impl" || bad "space_in_repo/$impl" "got '$got' want '$want'"
  rm -rf "$T/with space"
done

echo "$pass pass, $fail fail"
[ "$fail" = 0 ]
