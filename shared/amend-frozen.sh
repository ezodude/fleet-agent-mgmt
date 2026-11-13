#!/bin/bash
# Re-hash a frozen file after lead-1's amendment: the only way frozen.sha256 changes after the freeze.
#   shared/amend-frozen.sh <record folder> <rules|gate> "<reason>"      lead-1 only, after the edit
# Before the edit, lead-1 copies the frozen file beside it:
#   cp <record>/gate.md <record>/gate-pre-<stamp>.md      (rules: rules-pre-<stamp>.md)
# then edits it, then runs this. The edit is checked against that copy, the one whose sha256 is the
# frozen hash:
#   rules.md  every earlier line kept; an earlier row may only gain `[retired <date> by <line>]`, where
#             <line> is an appended row; appended lines are a `<KIND>  amended <date>:` heading and
#             rows under it.
#   gate.md   the freeze header and every earlier `# Amended` line kept; one new line
#             `# Amended <date> <time> by lead-1 (C3): <line n>, <kind a|b>, <source>` above GATE BLOCK;
#             no proves done line removed; gate_run reads it with no problem.
# The owner's word: a rules.md amendment, and a gate.md amendment that ADDS a proves done line, are refused
# unless the owner typed "<LANE> r<n> amend ok <card id>" (ATL-42 r1 amend ok ATL-42 D4) in lead-1's pane
# or the IC's, after the record's newest history line (else its freeze time), and the same card id is in
# the <reason>. A relayed message does not count; no log folder or no typed entry: refused. A gate.md
# amendment that changes existing lines only stays lead-1's with no word: a pass line set to what origin/main
# prints (a `kind a` # Amended line), a command set to CI's exact form (`kind b`). Read from Claude Code's
# session logs by shared/records/freeze_rules.py amend_ok; the checks are in shared/frozen.py amend.
# Then frozen.sha256 gets the new hash and a history line with the old one and the copy's name;
# the chain back to the approved spec replays each history step (shared/frozen.py chain_reasons).
# Run from lead-1's folder only, as named in FLEET_HOME/roster.md (FLEET_ROSTER is not read): refused
# from an IC's worktree or any other directory. A folder in shared/records/legacy-records.txt has no frozen.sha256: a note, exit 0.
# The checks: shared/frozen.py amend (documented there). Exit 0 re-hashed or nothing to do, 2 refused
# with one reason per line and nothing written. Give the card id in the reason:
#   shared/amend-frozen.sh <record> rules "card ATL-42 D4: weekly imports only"
set -u
[ $# -eq 3 ] || { echo 'usage: amend-frozen.sh <record folder> <rules|gate> "<reason>"'; exit 2; }
exec python3 "$(dirname "$0")/frozen.py" amend "$@"
