#!/bin/bash
# PostToolUse hook, matcher "Write|Edit|MultiEdit", IC only. After a write to
# the rung's decision-record.md (~/.fleet-agent-mgmt/records/<project>/<lane>-r<n>/)
# every entry with no jev line yet is checked against rules.md in the same folder by
# shared/hooks/dr_check.py, which holds all the logic and documents the
# verdicts, keys and env (JEV_ENV, JEV_STUB, DR_STANDING), and then the jev
# audit (dr_check.py --audit) runs on the file, its result one more line of
# the hook message. shared/records/record-add.sh runs the same two steps. This file
# only decides whether to run it: the role from the roster, the path from the
# hook JSON. The logic lives in dr_check.py, out of the shell, so it can be
# read and debugged.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "ic" ] || exit 0
p="$(j '.tool_input.file_path')"; [ -n "$p" ] || exit 0
RECORDS="${FLEET_RECORDS:-$FLEET_HOME/records}"
# Any spelling of the file is the file: the name in any case (macOS ignores it), and the path resolved
# (/./, //, a link to the folder or the file), as artefact-gate.sh resolves it before the guard.
real(){ python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s\n' "$1"; }
shopt -s nocasematch
case "${p##*/}" in decision-record.md) ;; *) [ -L "$p" ] || exit 0 ;; esac
p="$(real "$p")"
case "$p" in "$RECORDS"/*/*/decision-record.md|"$(real "$RECORDS")"/*/*/decision-record.md|"$FLEET_HOME"/records/*/*/decision-record.md|*/.fleet-agent-mgmt/records/*/*/decision-record.md) ;; *) exit 0 ;; esac
shopt -u nocasematch
[ -f "$p" ] || exit 0
# --worktree: the spec in the IC's worktree must still read as frozen; Jev reads the entry only.
# --audit-after: then dr_check.py --audit on the file as it now reads, one more line of the message,
# after every write (an entry written above another's jev line shows here, not first at the push).
exec python3 "$(dirname "$0")/dr_check.py" "$p" ${cwd:+--worktree "$cwd"} --audit-after
