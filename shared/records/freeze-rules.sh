#!/bin/bash
# Freeze the rung's rules and gate: write <record>/rules.md and <record>/gate.md from the approved design spec.
#   shared/records/freeze-rules.sh <spec path> <record folder> --approved <sha> [--dump]   run from the IC's worktree, on "spec ok";
#                                                    <sha> is the STOP 1 report's spec line, the commit the owner reviewed;
#                                                    refused unless the owner's "<lane> r<n> spec ok" (or "<lane> spec ok")
#                                                    typed in this pane or lead-1's after the newest STOP 1 is in Claude
#                                                    Code's session logs (~/.claude/projects/, a fixed path)
#   shared/records/freeze-rules.sh --check <spec|-> [--path <repo path>] [--record <folder>]   no git, no write
#   shared/records/freeze-rules.sh --chore <record folder>/handoff.md [--dump]   lead-1 only, from lead-1's folder, before a
#                                                    chore's launch: a chore has no spec and no STOP 1
# Copies, never composes: rules.md holds screen one's Terms block, the standing ONE-WAY block of
# foundations/one-way.md, then screen one's One-way, Decided and Rejected blocks, one line per row; gate.md holds
# screen one's Checks block without its `on main` lines, the shape shared/records/gate-run.sh runs. Each under a header
# naming the commit that holds the spec; and frozen.sha256, the spec path, the approved sha and the sha256 of
# rules.md and gate.md (shared/frozen.py). Refused when screen one at HEAD is not screen one at the approved sha.
# Reads the new shape (`## Terms`, `## One-way`, `## Decided`,
# `## Rejected`, `## Checks`, all five required, each with one table or one fence under it) and the old one (TERMS,
# ONE-WAY, DECIDED, REJECTED and GATE capital headings); an old-shape spec may name the record folder on a `record:`
# line instead of the second argument. The reading is strict: a line it would drop or misread is a reason to
# refuse, never dropped. An old-shape spec with no checks block gets rules.md and a warning, no gate.md.
# --check runs the same reading and, with --record, compares the spec with rules.md and gate.md; a folder listed in
# shared/records/legacy-records.txt is skipped.
# --chore writes rules.md (the standing block only), gate.md (the handoff's `## Checks` table, read and refused as a
# spec's Checks are) and frozen.sha256 (a chore line, no spec line). Refused on a record with a spec freeze, a
# stop1.log, a frozen file or an ic-sessions.log (an IC has worked on the record), on a handoff with a line anywhere
# that names a spec step or STOP 1, and from any folder but lead-1's.
# Checks and writing: shared/records/freeze_rules.py (documented there). Exit 0 written or ok, 2 refused with one reason
# per line and nothing written.
set -u
exec python3 "$(dirname "$0")/freeze_rules.py" "$@"
