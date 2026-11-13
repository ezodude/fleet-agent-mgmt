#!/bin/bash
# The precedents gatherer: the CHANGED, LEARNED and OWED rows of a project's earlier close reports, each
# with its reference "<record> · <section> · row <n>", for the brief-grilling step 0 sweep
# (shared/skills/sweeping-precedents). Reads close.md only, screen one only; never a sources/ folder.
#   shared/records/precedents-gather.sh [--root <records root>] <project>
# The root defaults to $FLEET_RECORDS, else ~/.fleet-agent-mgmt/records. Exit 0 with the rows, or with
# "none: no close report for <project>"; exit 2 with a plain reason for a missing root or project.
# The logic is shared/records/precedents_gather.py (documented there).
set -u
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/precedents_gather.py" "$@"
