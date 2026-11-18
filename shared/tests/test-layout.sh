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

# board_list: fleet-board.sh list prints YOURS by default; the log view (l, board-state/logview) lists the template's sections and their rows
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
mkdir -p "$d/checks/lead-1"; cp "$HERE/testdata/board.md" "$d/checks/lead-1/board.md"
out="$(FLEET_HOME="$d" bash "$REPO/shared/board/fleet-board.sh" list 2>&1)"
if echo "$out" | grep -q YOURS && ! echo "$out" | grep -q 'No such file'; then ok board_list_default; else bad board_list_default "$out"; fi
mkdir -p "$d/board-state"; touch "$d/board-state/logview"
out="$(FLEET_HOME="$d" bash "$REPO/shared/board/fleet-board.sh" list 2>&1)"
if echo "$out" | grep -q YOURS && echo "$out" | grep -q RUNNING && echo "$out" | grep -q OWED && echo "$out" | grep -q ORB-7; then ok board_list; else bad board_list "$out"; fi
rm -f "$d/board-state/logview"

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

# board_who_first: a YOURS row leads with who asks (lead-1 when no IC's pane is named), then the ticket and decision
plain() { sed $'s/\x1b\\[[0-9;]*m//g'; }
brd() { FLEET_HOME="$d" bash "$REPO/shared/board/fleet-board.sh" "$@" 2>&1; }
out="$(brd list | plain)"
if echo "$out" | grep -qE '^ +lead-1 +ATL-12 +Robin decides'; then ok board_who_first; else bad board_who_first "$out"; fi
# board_ic_ticket: an ask only in an IC's STATE.md is named by that IC's rung; with a decision id at its start, by that id
mkdir -p "$d/checks/orbit-ic-1"; printf 'rung: ORB-7 r1 (the orbit loader)\nstop: STOP 2 sent\nawaiting: owner: the word to release\nupdated: 2026-01-01 08:00\n' > "$d/checks/orbit-ic-1/STATE.md"
out="$(brd list | plain)"
if echo "$out" | grep -qE '^ +orbit-ic-1 +ORB-7 r1 +the word to release'; then ok board_ic_ticket; else bad board_ic_ticket "$out"; fi
sed -i.bak 's/^awaiting: owner: .*/awaiting: owner: ORB-7 D3 (keep the old loader, or drop it)/' "$d/checks/orbit-ic-1/STATE.md"
out="$(brd list | plain)"
if echo "$out" | grep -qE '^ +orbit-ic-1 +ORB-7 D3 +ORB-7 D3 \(keep'; then ok board_ic_decision; else bad board_ic_decision "$out"; fi
# board_hide: d (done <bullet>) hides any YOURS row, whatever wrote it; u (undone) brings the last one back
bul="$(brd list | awk -F'\t' '$2=="yours" && $3=="orbit-ic-1"{print $5}')"
brd done "$bul" >/dev/null
if ! brd list | plain | grep -qE 'orbit-ic-1 +ORB-7 D3'; then ok board_hide; else bad board_hide "still listed"; fi
brd undone >/dev/null
if brd list | plain | grep -qE 'orbit-ic-1 +ORB-7 D3'; then ok board_unhide; else bad board_unhide "not back"; fi
# board_nocard: a row with no card file is drawn in the card shape from its own text
out="$(FB_PEEK=1 FZF_PREVIEW_COLUMNS=70 brd preview yours ATL-12 'lead-1 chat' "$(brd list | awk -F'\t' '$3=="ATL-12"{print $5}')" | plain)"
if echo "$out" | grep -q 'no card file' && echo "$out" | grep -qE '^problem +Robin decides' && echo "$out" | grep -qE '^reply +go with option b'; then ok board_nocard; else bad board_nocard "$out"; fi
# board_nocard_split: a red row's status is cut up: why it is red first, the clause needing the owner's word next, the rest one clause per line, 80 columns at most
out="$(FB_PEEK=1 FZF_PREVIEW_COLUMNS=170 brd preview red orbit-ic-1 'orbit-ic-1 pane' 'orbit-ic-1 · ORB-7 r1 · https://tracker.example.test/browse/ORB-7: PR #12 ready at 40a16058; the loader fix broke case two (E7); holding for your word on the fix, no deploy; merge held · red: TESTS row 2 · since: 08:40Z' | plain)"
if echo "$out" | grep -qE '^orbit-ic-1 · ORB-7 r1 +no card file' && echo "$out" | grep -qE '^red +TESTS row 2$' && echo "$out" | grep -qE '^yours +holding for your word on the fix, no deploy$' \
  && echo "$out" | grep -qE '^status +· PR #12 ready at 40a16058$' && echo "$out" | grep -qE '^ +· merge held$' && ! echo "$out" | grep -qE '.{81,}'; then ok board_nocard_split; else bad board_nocard_split "$out"; fi
# board_nocard_options: options written inline as a) b) c) each get a line
out="$(FB_PEEK=1 FZF_PREVIEW_COLUMNS=90 brd preview yours 'ATL-12 D5' 'lead-1 chat' 'ATL-12 D5 · the index is stale. a) rebuild it now b) leave it for the next rung · say: ATL-12 D5 a · where: lead-1 chat' | plain)"
if echo "$out" | grep -qE '^problem +the index is stale$' && echo "$out" | grep -qE '^options +a\) rebuild it now$' && echo "$out" | grep -qE '^ +b\) leave it for the next rung$'; then ok board_nocard_options; else bad board_nocard_options "$out"; fi
# board_card_done: an open card not on the page is a YOURS row until the page's done today names its ticket and decision
mkdir -p "$d/checks/lead-1/cards"; printf 'id: ATL-12 D4\nrow: lead-1\nstatus: open\nsince: 2026-01-01 08:00 GMT\nwhere: lead-1\nreply: ATL-12 D4 a\nanswer: -\n---\nATL-12 D4\nKeep the index?\n' > "$d/checks/lead-1/cards/ATL-12-D4.md"
if brd list | plain | grep -q 'ATL-12 D4'; then ok board_card_open; else bad board_card_open "card row missing"; fi
printf '\n## done today\n\n- ATL-12 · D4 a, index kept · 08:50Z\n' >> "$d/checks/lead-1/board.md"
if ! brd list | plain | grep -q 'ATL-12 D4 '; then ok board_card_done; else bad board_card_done "still listed"; fi

# skill_frontmatter_yaml: a plain (unquoted) frontmatter value holding ": " is not valid YAML; GitHub fails to render it
hits=""
for f in "$REPO"/shared/skills/*/SKILL.md; do
  h="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1 && /^[A-Za-z_-]+: / { v=$0; sub(/^[A-Za-z_-]+: /,"",v); if (v !~ /^["'"'"'|>]/ && index(v,": ")) print FILENAME":"NR }' "$f")"
  [ -n "$h" ] && hits="$hits ${h#$REPO/}"
done
if [ -z "$hits" ]; then ok skill_frontmatter_yaml; else bad skill_frontmatter_yaml "$hits"; fi

echo "$pass pass, $fail fail"
[ "$fail" -eq 0 ]
