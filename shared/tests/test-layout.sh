#!/bin/bash
# Checks the shared/ layout: scripts sit in named groups, no stale paths remain.
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1: $2"; }

# left at the top this rung: a live guard matches their names
TOP_EXCEPT="amend-frozen.sh frozen.py"
is_except() { local e; for e in $TOP_EXCEPT; do [ "$1" = "$e" ] && return 0; done; return 1; }

# no_script_at_top: no *.sh or *.py directly in shared/
top=""
while IFS= read -r f; do
  is_except "$(basename "$f")" || top="$top $f"
done < <(find "$REPO/shared" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | sort)
if [ -z "$top" ]; then ok no_script_at_top; else bad no_script_at_top "$top"; fi

# every_script_in_group: tracked scripts under shared/ sit in an allowed group
stray=""
while IFS= read -r f; do
  case "$f" in
    shared/launch/*|shared/hooks/*|shared/records/*|shared/ledger/*|shared/fleet/*|shared/board/*|shared/migrate/*|shared/tests/*|shared/lib/*|shared/skills/*) ;;
    shared/*/*) stray="$stray $f" ;;
    *) is_except "$(basename "$f")" || stray="$stray $f" ;;
  esac
done < <(git -C "$REPO" ls-files 'shared/*.sh' 'shared/*.py')
if [ -z "$stray" ]; then ok every_script_in_group; else bad every_script_in_group "$stray"; fi

# every_sh_executable: every tracked shared/**/*.sh has git mode 100755
nonexec="$(git -C "$REPO" ls-files -s 'shared/*.sh' | grep -v '^100755' | cut -f2 | tr '\n' ' ')"
if [ -z "$nonexec" ]; then ok every_sh_executable; else bad every_sh_executable "$nonexec"; fi

# no_stale_ref: no `shared/<name>` path whose file now lives in a group
# (the files left at the top are not listed)
NAMES="agent-up.sh shape-up.sh ic-settings.json lead-settings.json shape-settings.json term-width.sh card-width.txt shaping/
record-add.sh record_add.py gate-run.sh gate_run.py freeze-rules.sh freeze_rules.py legacy-records.txt
precedents-check.sh precedents-gather.sh precedents_check.py precedents_gather.py md-check.sh md_check.py
ledger-add.sh ledger_add.py card-add.sh state-set.sh fleet-check.sh fleet-fix.sh fleet-audit.sh
test-card-add.sh test-ledger-add.sh test-precedents.sh test-record-add.sh test-shape-up.sh test-state-regression.sh test-state-set.sh
hooks/test-hooks.sh hooks/test-skill-hooks.sh hooks/test-settings.json hooks/testdata"
args=()
for n in $NAMES; do args+=(-e "shared/$n"); done
hits="$(git -C "$REPO" grep -nF "${args[@]}" -- . ':!Leads' ':!TechLeads' ':!lead-ux' ':!archive' ':!shared/docs/specs' ':!CHANGELOG.md' ':!shared/tests/test-layout.sh' 2>/dev/null)"
if [ -z "$hits" ]; then ok no_stale_ref; else bad no_stale_ref "$(echo "$hits" | head -5 | tr '\n' '|')"; fi

# board_list: fleet-board.sh list prints the fixture board's section names
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
mkdir -p "$d/checks/lead-1"; cp "$HERE/testdata/board.md" "$d/checks/lead-1/board.md"
out="$(FLEET_HOME="$d" bash "$REPO/shared/board/fleet-board.sh" list 2>&1)"
if echo "$out" | grep -q YOURS && echo "$out" | grep -q RUNNING && echo "$out" | grep -q 'orbit notes'; then ok board_list; else bad board_list "$out"; fi

# board_url_of: links come only from FLEET_HOME/board-links.tsv; empty when the file or key is absent
urlof() { FLEET_HOME="$d" bash -c 'eval "$(sed -n "/^url_of()/p" "$1")"; url_of "$2"' _ "$REPO/shared/board/fleet-board.sh" "$1"; }
cp "$HERE/testdata/board-links.tsv" "$d/board-links.tsv"
if [ "$(urlof ATL-12)" = "https://tracker.example.test/browse/ATL-12" ]; then ok board_url_of_hit; else bad board_url_of_hit "$(urlof ATL-12)"; fi
if [ -z "$(urlof NOPE-1)" ]; then ok board_url_of_key_absent; else bad board_url_of_key_absent "$(urlof NOPE-1)"; fi
rm -f "$d/board-links.tsv"
if [ -z "$(urlof ATL-12)" ]; then ok board_url_of_file_absent; else bad board_url_of_file_absent "$(urlof ATL-12)"; fi

# board_lanes: lane names from FLEET_HOME/lane-prefixes.txt make "<lane> #N" a ticket key
keyof() { FLEET_HOME="$d" bash -c 'eval "$(sed -n "/^key_re()/p;/^key_of()/p" "$1")"; key_of "$2"' _ "$REPO/shared/board/fleet-board.sh" "$1"; }
rm -f "$d/lane-prefixes.txt"
if [ "$(keyof 'orbit #12 waits')" = "#12" ]; then ok board_lane_absent; else bad board_lane_absent "$(keyof 'orbit #12 waits')"; fi
cp "$HERE/testdata/lane-prefixes.txt" "$d/lane-prefixes.txt"
if [ "$(keyof 'orbit #12 waits')" = "orbit #12" ]; then ok board_lane_present; else bad board_lane_present "$(keyof 'orbit #12 waits')"; fi

echo "$pass pass, $fail fail"
[ "$fail" -eq 0 ]
