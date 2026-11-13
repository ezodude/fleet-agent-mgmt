"""Imported by every python script: sys.path.insert(0, <lib dir>), then
from paths import FLEET_REPO, FLEET_HOME, need_home.
Both names are str. FLEET_REPO comes from this file's own location."""
import os
import sys

FLEET_REPO = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FLEET_HOME = os.environ.get("FLEET_HOME") or os.path.join(os.path.expanduser("~"), ".fleet-agent-mgmt")


def need_home():
    """Exit 2 naming the folder and install.sh when FLEET_HOME is absent."""
    if not os.path.isdir(FLEET_HOME):
        print("FLEET_HOME %s missing: run shared/migrate/install.sh" % FLEET_HOME, file=sys.stderr)
        raise SystemExit(2)
