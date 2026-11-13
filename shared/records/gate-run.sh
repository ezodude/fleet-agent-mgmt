#!/bin/bash
# Run the rung's gate block exactly as written and write a receipt.
#   shared/records/gate-run.sh <record folder>        run from the IC's worktree (cwd = the repo)
# Reads <record folder>/gate.md: the GATE BLOCK frozen from the spec's Checks (a chore's: from
# its handoff's `## Checks`, frozen by lead-1 with freeze-rules.sh --chore)
# (labels at two spaces, then two or more spaces: proves done, pass, on failure,
# owner's word, record; deeper lines continue a label; # lines are comments).
# Each `proves done` line is one command, run with bash -c in the cwd; the
# `pass` line at the same position is its pass line. A command is green when
# its exit code is the one the pass line names (0 unless it says "exit N"),
# every "quoted string" on the pass line is in the output as a whole token,
# and a string written no "x" or "x" absent is nowhere in it. Anything else is
# red. A gate.md the reader cannot read for certain (a bad indent, an unknown
# label, curly quotes, an exit code not worded "exit N", unequal counts) is
# not run: exit 2, one reason per line, no receipt.
# Before any run, rules.md and gate.md must match <record>/frozen.sha256 (shared/frozen.py
# verify; a folder in shared/records/legacy-records.txt is not checked); the receipt names the
# sha256 of the gate.md it ran.
# The checks and the receipt are shared/records/gate_run.py (documented there); this
# file gathers the stamp, HEAD and dirty count and calls it. Exit 0 green,
# 1 red, 2 no gate.md, a gate.md it cannot read, or a frozen file that changed. Red is a result, not an error: report it red.
# shared/hooks/message-gate.sh refuses a STOP with no receipt at this HEAD or
# a ✔ row over a red command.
set -u
rec="${1:?usage: gate-run.sh <record folder>}"; rec="${rec%/}"
[ -f "$rec/gate.md" ] || { echo "gate-run: no $rec/gate.md: the freeze has not run. On \"spec ok\" run shared/records/freeze-rules.sh <spec> $rec --approved <sha> (writing-a-design-spec step 5); a chore is frozen by lead-1 before launch (shared/records/freeze-rules.sh --chore $rec/handoff.md), so stop and ask lead-1; a gate.md is never copied by hand"; exit 2; }
mkdir -p "$rec/receipts"
stamp="$(date '+%Y-%m-%d-%H%M')"; now="$(date '+%Y-%m-%d %H:%M')"
head="$(git rev-parse HEAD 2>/dev/null || echo nogit)"
dirty="$(git status --porcelain 2>/dev/null | grep -c . | tr -d ' ')"
out="$rec/receipts/$stamp-gate.md"; log="$rec/receipts/$stamp-gate.log"
exec python3 "$(dirname "$0")/gate_run.py" "$rec" "$out" "$log" "$now" "$head" "$dirty" "$PWD"
