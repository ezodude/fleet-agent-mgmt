#!/bin/bash
# copy.sh [--ledger] <AgentMgmt> <state folder>
# Copies Leads/ and lead-ux/ (every file on disk, tracked or not) into the state
# folder, writes a source-side sha256 manifest. Never deletes or moves in the source.
# --ledger copies only Leads/lead-1/LEDGER.md, adds it to the manifest and re-records
# AgentMgmt's HEAD (the ledger copy is the last write to AgentMgmt).
# The roster is copied to <state folder>/roster.md; rows whose directory sits under
# <AgentMgmt>/Leads/ or <AgentMgmt>/lead-ux/ are rewritten to the same place in the state folder.
set -u
LEDGER_REL="Leads/lead-1/LEDGER.md"
die() { echo "copy.sh: $*" >&2; exit 1; }
hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

MODE=main
if [ "${1:-}" = "--ledger" ]; then MODE=ledger; shift; fi
[ $# -eq 2 ] || die "usage: copy.sh [--ledger] <AgentMgmt> <state folder>"
AM="$1"; ST="$2"
[ -d "$AM" ] || die "no such AgentMgmt folder: $AM"
AM_GIVEN="$AM"
AM="$(cd -P "$AM" && pwd)"
MAN="$ST/migrate/copy-manifest.tsv"

if [ "$MODE" = ledger ]; then
  [ -f "$MAN" ] || die "no manifest yet at $MAN: run the main copy first"
  grep -q "^$LEDGER_REL	" "$MAN" && die "ledger is already in the manifest"
  [ -f "$AM/$LEDGER_REL" ] || die "no ledger at $AM/$LEDGER_REL"
  head="$(git -C "$AM" rev-parse HEAD 2>/dev/null)" || die "cannot read HEAD of $AM"
  [ -n "$head" ] || die "cannot read HEAD of $AM"
  mkdir -p "$ST/Leads/lead-1" || die "cannot create $ST/Leads/lead-1"
  cp -p "$AM/$LEDGER_REL" "$ST/$LEDGER_REL" || die "copy failed"
  h="$(hash_of "$AM/$LEDGER_REL")"
  printf '%s\t%s\n' "$LEDGER_REL" "$h" >> "$MAN"
  printf '%s\n' "$h" > "$ST/migrate/ledger-sha256"
  printf '%s\n' "$head" > "$ST/migrate/agentmgmt-head"
  echo "ledger copied ($h)"
  exit 0
fi

[ -e "$ST/Leads" ] && die "$ST/Leads already exists"
[ -e "$ST/lead-ux" ] && die "$ST/lead-ux already exists"
[ -f "$AM/shared/roster.md" ] || die "no roster at $AM/shared/roster.md"
[ -d "$AM/Leads" ] || die "no Leads/ in $AM: wrong or empty source path"
[ -d "$AM/lead-ux" ] || die "no lead-ux/ in $AM: wrong or empty source path"

mkdir -p "$ST/migrate" || die "cannot create $ST/migrate"
head="$(git -C "$AM" rev-parse HEAD 2>/dev/null)" || head="unknown"
printf '%s\n' "$head" > "$ST/migrate/agentmgmt-head"
printf '%s\n' "$AM" > "$ST/migrate/agentmgmt-path"

for d in Leads lead-ux; do
  cp -Rp "$AM/$d" "$ST/$d" || die "copy of $d failed"
done
# no .git folders, and the ledger waits for --ledger (both removed from the COPY only)
find "$ST/Leads" "$ST/lead-ux" -name .git -prune -exec rm -rf {} + 2>/dev/null
rm -f "$ST/$LEDGER_REL"
# the roster rows that point into <AgentMgmt>/Leads/ or <AgentMgmt>/lead-ux/ follow the copy; every other row is kept as is
ST_ABS="$(cd -P "$ST" && pwd)" || die "cannot resolve $ST"
AM_ROOT="$AM" AM_GIVEN_ROOT="$AM_GIVEN" ST_ROOT="$ST_ABS" python3 - "$AM/shared/roster.md" "$ST/roster.md" <<'PY' || die "roster copy failed"
import os, sys
src, dst = sys.argv[1:3]
ams = [os.environ["AM_ROOT"].rstrip("/"), os.environ["AM_GIVEN_ROOT"].rstrip("/")]
st = os.environ["ST_ROOT"].rstrip("/")
out = []
with open(src, newline="") as f:
    for line in f:
        parts = line.split("\t")
        if len(parts) >= 2:
            for am in ams:
                for d in ("Leads", "lead-ux"):
                    if parts[1] == am + "/" + d or parts[1].startswith(am + "/" + d + "/"):
                        parts[1] = st + parts[1][len(am):]
                        break
                else:
                    continue
                break
        out.append("\t".join(parts))
with open(dst, "w", newline="") as f:
    f.write("".join(out))
PY

: > "$MAN.tmp"
(
  cd "$AM" || exit 1
  for d in Leads lead-ux; do
    find "$d" -name .git -prune -o -type f -print
  done | sort
) | while IFS= read -r rel; do
  [ "$rel" = "$LEDGER_REL" ] && continue
  h="$(hash_of "$AM/$rel")" || continue
  [ -n "$h" ] || continue
  printf '%s\t%s\n' "$rel" "$h" >> "$MAN.tmp"
done
want="$(find "$ST/Leads" "$ST/lead-ux" -type f | wc -l | tr -d ' ')"
got="$(wc -l < "$MAN.tmp" | tr -d ' ')"
if [ "$want" != "$got" ] || [ "$got" = 0 ]; then
  rm -f "$MAN.tmp"
  die "manifest has $got lines but the copy holds $want files: no manifest written"
fi
mv "$MAN.tmp" "$MAN" || die "cannot write manifest"
echo "copied $got files"
