#!/bin/bash
# Render a markdown file the owner will read, as a viewer does, and fail on
# what the viewer breaks: a line swallowed into a table, lined-up text merged
# into one paragraph, a <word> that vanishes as an HTML tag, a line over 160
# characters.
#   shared/records/md-check.sh <file> [<file> ...]
# The checks are shared/records/md_check.py (documented there); this file pins the
# parser, markdown-it-py 3.0.0, through uv. Exit 0 clean, 1 a fault, 2 a file
# it cannot read. Fix every fault before the file goes to the owner.
set -u
[ $# -ge 1 ] || { echo "usage: md-check.sh <file> [<file> ...]"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
exec uv run --quiet --no-project --with 'markdown-it-py==3.0.0' python -I "$here/md_check.py" "$@"
