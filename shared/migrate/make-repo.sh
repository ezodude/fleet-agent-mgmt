#!/bin/bash
# make-repo.sh <dest>: a fresh one-commit repo of HEAD without the owner's folders.
# The tree is `git archive HEAD` minus Leads/ TechLeads/ lead-ux/ archive/.
# The commit identity is fixed, whatever git config says. Refuses an existing <dest>.
# MAKE_REPO_SRC overrides the source repo (tests only).
# Ends by running test-clean-clone.sh scan on <dest> (home paths, plus the token list in
# FLEET_HOME); a hit exits 1. MAKE_REPO_NO_SCAN=1 skips that scan (the scan's own fresh clone).
set -eu
HERE="$(cd -P "$(dirname "$0")" && pwd)"
SRC="${MAKE_REPO_SRC:-$(cd -P "$HERE/../.." && pwd)}"
[ "$#" -eq 1 ] || { echo "usage: make-repo.sh <dest>" >&2; exit 2; }
DEST="$1"
if [ -e "$DEST" ]; then echo "make-repo: $DEST exists" >&2; exit 1; fi
mkdir -p "$DEST"
git -C "$SRC" archive HEAD | tar -x -C "$DEST"
for d in Leads TechLeads lead-ux archive; do rm -rf "${DEST:?}/$d"; done
git -C "$DEST" init -q -b main
git -C "$DEST" add -A
GIT_AUTHOR_NAME="fleet-agent-mgmt" GIT_AUTHOR_EMAIL="fleet-agent-mgmt@users.noreply.github.com" \
GIT_COMMITTER_NAME="fleet-agent-mgmt" GIT_COMMITTER_EMAIL="fleet-agent-mgmt@users.noreply.github.com" \
  git -C "$DEST" commit -q -m "fleet-agent-mgmt"
if [ -z "${MAKE_REPO_NO_SCAN:-}" ]; then
  FLEET_HOME="${FLEET_HOME:-$HOME/.fleet-agent-mgmt}" bash "$HERE/../tests/test-clean-clone.sh" scan "$DEST" || exit 1
fi
