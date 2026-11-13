#!/bin/bash
# check-copy.sh [<state folder>]: compares each manifest line (source-side sha256 at
# copy time) with the file in the copy. Prints "N files, M missing, K differing".
set -u
ST="${1:-${FLEET_HOME:-$HOME/.fleet-agent-mgmt}}"
MAN="$ST/migrate/copy-manifest.tsv"
[ -f "$MAN" ] || { echo "check-copy.sh: no manifest at $MAN" >&2; exit 1; }
n=0; miss=0; diff=0
while IFS="$(printf '\t')" read -r rel want; do
  [ -n "$rel" ] || continue
  n=$((n+1))
  if [ ! -f "$ST/$rel" ]; then
    miss=$((miss+1)); echo "missing: $rel"
  elif [ "$(shasum -a 256 "$ST/$rel" | cut -d' ' -f1)" != "$want" ]; then
    diff=$((diff+1)); echo "differing: $rel"
  fi
done < "$MAN"
echo "$n files, $miss missing, $diff differing"
[ "$n" -gt 0 ] || { echo "check-copy.sh: manifest lists 0 files" >&2; exit 1; }
[ "$miss" = 0 ] && [ "$diff" = 0 ]
