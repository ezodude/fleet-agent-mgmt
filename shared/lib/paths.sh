# Sourced by every shell script. Sets FLEET_REPO (the clone root, found from
# this file's own location, never from the caller's cwd) and FLEET_HOME
# (the user's data folder). bash 3.2 compatible.
FLEET_REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -z "${FLEET_HOME:-}" ]; then
  FLEET_HOME="$HOME/.fleet-agent-mgmt"
fi
export FLEET_REPO FLEET_HOME

# Call from a script that needs the user's data: exits 2 when FLEET_HOME is absent.
fleet_need_home() {
  if [ ! -d "$FLEET_HOME" ]; then
    echo "FLEET_HOME $FLEET_HOME missing: run shared/migrate/install.sh" >&2
    exit 2
  fi
}
