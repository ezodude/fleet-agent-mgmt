#!/bin/bash
# The precedents check: a record's precedents.json (the haiku sweep's reply, saved by the lead) against the
# schema (shared/skills/sweeping-precedents/templates/sweep.schema.json) and the gatherer's output, for the
# brief-grilling step 0 sweep (shared/skills/sweeping-precedents).
#   shared/records/precedents-check.sh [--schema <schema>] <record dir>
# The project and the records root come from the path; the check runs the gatherer itself.
# Exit 0 with a pass line; exit 1 with one line per fault, naming the reference or the field; exit 2 usage.
# The logic is shared/records/precedents_check.py (documented there).
set -u
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/precedents_check.py" "$@"
