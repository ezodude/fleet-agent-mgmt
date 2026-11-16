#!/usr/bin/env bash
# fleet-board v3: YOURS, RED and one green line by default; l shows the log. A viewer of lead-1's living page, $FLEET_HOME/checks/lead-1/board.md,
# written by lead-1 from $FLEET_REPO/shared/skills/keeping-the-board/board-template.md: ## yours, ## next, ## running, ## owed, ## done today, ## to read. One bullet per item,
# fields split by " · ": id · sentences · say: <line> · where: <lead-1 chat | <ic> pane> · since: <HH:MMZ>.
# Reads only. Never attaches, switches or types into a pane. Scrap: delete this file, kill tmux session fleet-board.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/../lib/paths.sh"
FLEET="$FLEET_HOME"; PAGE="$FLEET/checks/lead-1/board.md"; CARDS="$FLEET/checks/lead-1/cards"; REPORTS="$FLEET/checks/lead-1/reports"
D="$FLEET_HOME/board-state"; mkdir -p "$D"; touch "$D/read"
ORANGE=${ORANGE_AFTER:-30}; RED=${RED_AFTER:-60}; BUDGET=${BUDGET:-5}
C0=$'\e[0m'; CB=$'\e[1;38;5;26m'; CG=$'\e[38;5;28m'; CD=$'\e[38;5;244m'; CO=$'\e[38;5;166m'; CR=$'\e[1;38;5;160m'; CW=$'\e[1m'
TAB=$'\t'; SEP=' · '; read -r NOW TY TM TD < <(date -u '+%s %Y %m %d'); shopt -s extglob
# fast path (push-on-change): every helper below runs on bash builtins only, no grep/sed/date fork per bullet

tokv() { local s=" · $2" k=" · $1:"; TOK=""; case "$s" in *"$k"*) ;; *) return 0;; esac; s=${s#*"$k"}; s=${s%%·*}; s=${s##+( )}; TOK=${s%%+( )}; }
tok() { tokv "$@"; [ -n "$TOK" ] && printf '%s\n' "$TOK"; return 0; }
# epoch of Y M D H M (UTC), days-from-civil arithmetic, no date fork
ep() { local y=$((10#$1)) m=$((10#$2)) d=$((10#$3)) era yoe doy doe; [ $m -le 2 ] && y=$((y-1)); era=$((y/400)); yoe=$((y-era*400))
  doy=$(( (153*((m+9)%12)+2)/5 + d-1 )); doe=$(( yoe*365 + yoe/4 - yoe/100 + doy )); EP=$(( (era*146097+doe-719468)*86400 + 10#$4*3600 + 10#$5*60 )); }
# since: accepts HH:MMZ (today), MM-DD, YYYY-MM-DD, or YYYY-MM-DD HH:MMZ; prints minutes ago, or nothing
minsv() { local t=$1; EP=""; MINS=""; [ -z "$t" ] && return 0
  case "$t" in
    [0-9][0-9]:[0-9][0-9]Z|[0-9][0-9]:[0-9][0-9]) ep "$TY" "$TM" "$TD" "${t:0:2}" "${t:3:2}";;
    [0-9][0-9]-[0-9][0-9]) ep "$TY" "${t:0:2}" "${t:3:2}" 0 0;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ep "${t:0:4}" "${t:5:2}" "${t:8:2}" 0 0;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]*) ep "${t:0:4}" "${t:5:2}" "${t:8:2}" "${t:11:2}" "${t:14:2}";;
  esac
  [ -z "$EP" ] && return 0; [ "$EP" -gt "$NOW" ] && EP=$((EP-86400)); MINS=$(( (NOW-EP)/60 )); }
mins_since() { minsv "$1"; echo "$MINS"; }
age() { local m=$1 t c; [ -z "$m" ] && { printf -v AGE '%7s' ''; return; }
  if [ "$m" -ge 1440 ]; then t="$((m/1440))d"; elif [ "$m" -ge 60 ]; then printf -v t '%dh%02d' $((m/60)) $((m%60)); else t="${m}m"; fi
  if [ "$m" -ge "$RED" ]; then c=$CR; t="$t ▲"; elif [ "$m" -ge "$ORANGE" ]; then c=$CO; else c=$CD; fi; printf -v AGE '%s%7s%s' "$c" "$t" "$C0"; }
# key_re: ticket-key regex; lowercase lane names (one per line in $FLEET_HOME/lane-prefixes.txt) add "<lane>-N" and "<lane> #N"
key_re() { local l; l=$(grep -E '^[a-z][a-z0-9]*$' "$FLEET_HOME/lane-prefixes.txt" 2>/dev/null | paste -sd'|' -); echo "[A-Za-z]+-[0-9]+${l:+|($l)-[0-9]+|($l) #[0-9]+}"; }
# key_of runs on bash builtins (no fork per bullet); KRE1 is built once here, and inside key_of when it is called alone
KRE1="($(key_re))"
key_of() { local r2='(PR #[0-9]+|PR [0-9]{3,}|#[0-9]+)'; [ -n "${KRE1:-}" ] || KRE1="($(key_re))"; if [[ $1 =~ $KRE1 ]]; then echo "${BASH_REMATCH[1]}"; elif [[ $1 =~ $r2 ]]; then echo "${BASH_REMATCH[1]}"; fi; }
url_of() { local k=$1; [ -n "$k" ] && [ -f "$FLEET_HOME/board-links.tsv" ] && awk -F'\t' -v k="$k" '$1==k{print $2; exit}' "$FLEET_HOME/board-links.tsv"; return 0; }
# id: the first field when the bullet has fields; else the ticket key in it. text: every other field that is not a token.
id_of() { case "$1" in *"$SEP"*) printf '%s' "${1%%$SEP*}";; *) key_of "$1";; esac; }
textv() { local s=$1 k out="" f first=1
  case "$s" in *"$SEP"*) s=${s#*·};; *) k=$(key_of "$s"); [ -n "$k" ] && case "$s" in "$k"*) s=${s#"$k"}; s=${s##+([ :,.])};; esac;; esac
  while :; do f=${s%%·*}; f=${f##+( )}; f=${f%%+( )}; case "$f" in say:*|where:*|since:*) ;; *) [ $first = 1 ] && out=$f || out="$out · $f"; first=0;; esac
    case "$s" in *·*) s=${s#*·};; *) break;; esac; done; TEXT=$out; }
text_of() { textv "$1"; printf '%s\n' "$TEXT"; }
pane_of() { grep -oE '^[a-z0-9-]+ pane' <<<"$1" | sed 's/ pane$//'; }
# a blank list line becomes a gap row and an empty last field gets "-": fzf 0.74.5 with --track stops taking actions
# after a reload while the cursor sits on an item with no fields (the watcher's gaps() does the same)
gaps() { awk -v T="$TAB" '/^$/ { n++; print " " T "gap" T "-" T "-" T "gap" n; next } /\t$/ { print $0 "-"; next } 1'; }
# live pane states (lead-ux F1, v3). fleet-board-live.py writes two files, both absent on a hand run:
# $D/live, one line per Claude session: session \t state (busy idle waits dialog ?) \t detail \t since (epoch);
# $D/sessions, every tmux session name, one per line.
live_of() { local s st dt sn; LST=""; LDT=""; LSN=""; [ -f "$D/live" ] || return 1
  while IFS="$TAB" read -r s st dt sn; do [ "$s" = "$1" ] && { LST=$st; LDT=$dt; LSN=$sn; return 0; }; done < "$D/live"; return 1; }
# the details pane's live line: busy shows since HH:MMZ, not the minute count, so the text (and the reader's scroll) holds
live_txt() { case "$LST" in busy) printf 'busy since %02d:%02dZ' $(( (LSN%86400)/3600 )) $(( (LSN%3600)/60 ));; *) printf '%s %s' "$LST" "$LDT";; esac; }
# the header's second line: every Claude session and its state; waits, dialog and ? red, busy green, idle grey
live_strip() { local s st dt sn c a l p out="" gap="  "
  # the launch loop writes the watcher's pid to $D/live.pid; a pid that is gone means nothing updates this board by itself
  [ -f "$D/live.pid" ] && read -r p < "$D/live.pid" && [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null && {
    printf '%slive  the watcher stopped: this board no longer updates by itself · ctrl-r, d and l still render · ~/.fleet-board/live.err%s\n' "$CR" "$C0"; return 0; }
  [ -f "$D/live" ] || { printf '%slive  no pane watcher%s\n' "$CD" "$C0"; return 0; }
  while IFS="$TAB" read -r s st dt sn; do [ -z "$s" ] && continue; a=""
    case "$st" in waits|dialog|'?') c=$CR;; busy) c=$CG;;
      *) c=$CD; [ -f "$FLEET/checks/$s/STATE.md" ] && while IFS= read -r l; do
             case "$l" in awaiting:*) l=${l#awaiting:}; l=${l#"${l%%[! ]*}"}
               case "$l" in lead-1:*) a=" · awaits lead-1";; owner:*) c=$CR;; esac; break;; esac
           done < "$FLEET/checks/$s/STATE.md";; esac
    out="$out$gap$c$s $st${dt:+ $dt}$a$C0"; gap="   "; done < "$D/live"
  printf 'live%s\n' "${out:-  ${CD}no Claude panes$C0}"; }
# an ask that exists only in a pane: a session idle on "Reply: <words>", or a dialog; skipped when the words are
# already a YOURS row ($1, the rows so far) or on the page's yours section (asked_already)
# asked_already <words> <session> < bullets: a bullet that holds the words as whole words, and is about this session
# ("<s> pane", or <s> as its id), or the words carry an id (a digit: ATL-12 J1 yes). A bare "ok" or "yes" elsewhere
# on the page, even a "say: ok" for another item, is not the same ask.
asked_already() { awk -v w="$1" -v s="$2" '
  function whole(h, n,   p, i, b, a) { p = 0
    while ((i = index(substr(h, p + 1), n)) > 0) { p += i; b = p > 1 ? substr(h, p - 1, 1) : " "; a = substr(h, p + length(n), 1)
      if (b !~ /[a-z0-9_-]/ && a !~ /[a-z0-9_-]/) return 1 }
    return 0 }
  BEGIN { w = tolower(w); s = tolower(s); hasid = (w ~ /[0-9]/) }
  { l = tolower($0); gsub(/`/, "", l)
    mine = index(l, s " pane") || index(l, s " · ") == 1
    if ((mine || hasid) && whole(l, w)) { f = 1; exit } }
  END { exit !f }'; }
live_asks() { local s st dt sn ys="" got=""; [ -f "$D/live" ] || return 0
  while IFS="$TAB" read -r s st dt sn; do
    case "$st" in
      waits) [ -z "$dt" ] && continue
        [ -z "$got" ] && { ys=$(sed -n '/^## yours/,/^## [^y]/s/^- //p' "$PAGE" 2>/dev/null; awk -F"$TAB" '{print $5}' "$1" 2>/dev/null); got=1; }
        asked_already "$dt" "$s" <<<"$ys" && continue
        row yours "$s" "asks in its pane: Reply: $dt · not on lead-1's page" "$s pane" "$(( (NOW-sn)/60 ))" "$s · asks in its pane: Reply: $dt · say: $dt · where: $s pane";;
      dialog) row yours "$s" "a dialog waits in its pane" "$s pane" "$(( (NOW-sn)/60 ))" "$s · a dialog waits in its pane · where: $s pane";;
    esac; done < "$D/live"; }
# $D/sessions loaded once per list; a running row whose IC has a checks folder and no tmux session is down
HAVE_SESS=""; SESS=""
load_sess() { local l; HAVE_SESS=""; SESS=$'\n'; [ -f "$D/sessions" ] || return 0; HAVE_SESS=1; while IFS= read -r l; do SESS="$SESS$l"$'\n'; done < "$D/sessions"; }

# done today is a log in lead-1's hand; the board shows one row per ticket (count, latest line), the rest behind the preview
flush_done() { [ -s "$D/done.tmp" ] || return 0
  awk -F"$TAB" '{ id=$1; if(id=="") id="fleet"; if(!(id in n)) order[++k]=id; n[id]++; last[id]=$2; all[id]=all[id] (all[id]==""?"":"¶") $2
      t=""; if (match($2, /[0-9][0-9]:[0-9][0-9]Z/)) t=substr($2, RSTART, 5); if (t!="") { if (first[id]=="" || t<first[id]) first[id]=t; if (t>latest[id]) latest[id]=t } }
    END { for(i=1;i<=k;i++){ id=order[i]; span=(first[id]==""?"":first[id] (latest[id]==first[id]?"":"-" latest[id])); printf "%s\t%d\t%s\t%s\t%s\n", id, n[id], span, last[id], all[id] } }' "$D/done.tmp" | while IFS="$TAB" read -r id n span last all; do
    printf '  %s%-22.22s%s %s%2d acts %-11s%s %-58.58s\tdone today\t%s\t-\t%s\n' "$CW" "$id" "$C0" "$CD" "$n" "$span" "$C0" "$last" "$id" "$all"; done; : > "$D/done.tmp"; }
# one row, every source: row <sec> <id shown> <text> <where> <mins> <bullet>
# ROWDIM set: the id and text print dim (a running row that is idle or down)
# a YOURS row leads with who asks (lead-ux F4 d): the IC whose pane it is, else lead-1; then the ticket and decision when
# the board has them. A row named only by its IC takes the ticket from that IC's own rung line. Fields 2 to 5 do not change.
row() { local c=$CW t who lab r a b
  if [ "$1" = yours ]; then who=lead-1; [[ $4 =~ ^([a-z0-9-]+)\ pane$ ]] && who=${BASH_REMATCH[1]}; lab=$2
    if [ "$lab" = "$who" ] && [[ $3 =~ ^([A-Za-z]+-[0-9]+\ [A-Z][0-9]+)[^0-9] ]]; then lab=${BASH_REMATCH[1]}
    elif [ "$lab" = "$who" ]; then lab=""; r=$(sed -n 's/^rung: *//p' "$FLEET/checks/$who/STATE.md" 2>/dev/null | head -1); read -r a b _ <<<"$r"; b=${b%%[,:(]*}; [ -n "$a" ] && lab="${a%%[,:(]*}${b:+ $b}"; fi
    printf -v t '%-57.57s' "$3"; age "$5"; printf '  %s%-10.10s%s %s%-20.20s%s %s %s%-16.16s%s %s\t%s\t%s\t%s\t%s\n' "$CB" "$who" "$C0" "$c" "$lab" "$C0" "$t" "$CD" "$4" "$C0" "$AGE" "$1" "$2" "$4" "$6"; return; fi
  printf -v t '%-66.66s' "$3"; [ -n "${ROWDIM:-}" ] && { c=$CD; t="$CD$t$C0"; }; age "$5"; printf '  %s%-22.22s%s %s %s%-16.16s%s %s\t%s\t%s\t%s\t%s\n' "$c" "$2" "$C0" "$t" "$CD" "$4" "$C0" "$AGE" "$1" "$2" "$4" "$6"; }
# a running row whose second field starts with idle or down (an IC whose session ended) is never building
# v3: also down when $D/sessions exists, the first field names a folder checks/<id>/, and no tmux session <id> runs
down_row() { local t w id; t=${1#*·}; t=${t##+( )}; t=${t%%$SEP*}; w=${t//[,.:]/}; w=${w%% *}; case "$w" in [Ii][Dd][Ll][Ee]|[Dd][Oo][Ww][Nn]) return 0;; esac
  [ -n "$HAVE_SESS" ] || return 1; id=${1%%$SEP*}; id=${id##+( )}; id=${id%%+( )}
  case "$id" in ''|*/*|.|..) return 1;; esac; [ -d "$FLEET/checks/$id" ] || return 1
  case "$SESS" in *$'\n'"$id"$'\n'*) return 1;; esac; return 0; }
running_up() { awk -F"$TAB" '$1=="running"{print $2}' "$D/rows.tmp" | while IFS= read -r line; do down_row "$line" || printf '%s\n' "$line"; done; }
# a pane ask lead-1 cannot see: an IC whose STATE.md awaits the owner and whom the page's yours section does not name
# one awk reads every STATE.md (was ~97 sed/grep/head launches); the rules are the same as V2's
pane_asks() { local fs=() f ic a up ys; for f in "$FLEET"/checks/*/STATE.md; do [ -f "$f" ] && fs+=("$f"); done; [ ${#fs[@]} -eq 0 ] && return 0
  ys=$(sed -n '/^## yours/,/^## [^y]/p' "$PAGE" 2>/dev/null | tr 'A-Z' 'a-z')
  awk 'function out() { if (f == "") return; n = split(f, p, "/"); ic = p[n-1]; if (ic == "lead-1") return
        if (a == "" && tolower(st) !~ /^closed/ && tolower(nx) ~ /owner/ && tolower(nx) !~ /^none/) a = nx " (from next:, awaiting says none)"
        if (a != "") printf "%s\037%s\037%s\n", ic, a, substr(up, 1, 16) }
    FNR == 1 { out(); f = FILENAME; a = st = nx = up = ""; ha = hs = hn = hu = 0 }
    !ha && /^awaiting: *owner: */ { ha = 1; a = $0; sub(/^awaiting: *owner: */, "", a) }
    !hs && /^stop: */ { hs = 1; st = $0; sub(/^stop: */, "", st) }
    !hn && /^next: */ { hn = 1; nx = $0; sub(/^next: */, "", nx) }
    !hu && /^updated: */ { hu = 1; up = $0; sub(/^updated: */, "", up) }
    END { out() }' "${fs[@]}" | while IFS=$'\037' read -r ic a up; do
    case "$ys" in *"$ic"*) continue;; esac
    row yours "$ic" "$a · not on lead-1's page" "$ic pane" "$(mins_since "$up")" "$ic · $a · where: $ic pane"; done; }
# a shaping folder: no brief yet, a brief in progress, or stamped "<idea> brief ok" (then r copies the word for lead-1).
# mode all: a SHAPING section, one row each; mode words: only stamped briefs, as YOURS rows; mode count: folders with a session up
shaping() { local mode=$1 d idea f st say="" m up first=1 n=0; for d in "$FLEET"/shaping/*/; do [ -d "$d" ] || continue; idea=$(basename "$d"); f="$d/brief.md"
    tmux has-session -t "=shape-$idea" 2>/dev/null && up="session up" || up="no session"; [ "$up" = "session up" ] && n=$((n+1))
    if [ ! -f "$f" ]; then st="no brief yet · $up"; say=""; m=$(mins_since "$(TZ=UTC date -r "$(stat -f %m "$d")" '+%Y-%m-%d %H:%M')")
    elif ls "$FLEET"/records/*/"$idea"/brief.md >/dev/null 2>&1; then st="taken by lead-1 · $up · close the session, the folder clears"; say=""; m=""
    elif grep -qF "$idea brief ok" "$f"; then st="brief ok · r copies the word for the lead-1 pane · $up"; say="shape $idea done"; m=$(mins_since "$(grep -F "$idea brief ok" "$f" | grep -oE '[0-9]{2}:[0-9]{2}Z' | head -1)")
    else st="brief in progress, $(wc -l <"$f" | tr -d ' ') lines · $up"; say=""; m=$(mins_since "$(TZ=UTC date -r "$(stat -f %m "$f")" '+%Y-%m-%d %H:%M')"); fi
    case "$mode" in count) continue;; words) [ -z "$say" ] && continue; row yours "$idea" "$st" "lead-1 chat" "$m" "$idea · $st · say: $say · where: lead-1 chat"; continue;; esac
    [ $first = 1 ] && { printf '\n%sSHAPING%s\thead\t-\t-\t-\n' "$CB" "$C0"; first=0; }
    row shaping "$idea" "$st" "shape-$idea pane" "$m" "$idea · $st${say:+ · say: $say} · where: shape-$idea pane"; done; [ "$mode" = count ] && echo $n; return 0; }
# cards: lead-1's decision-card files (shared/ledger/card-add.sh). card_files <bullet> prints the open card files the
# row names ("atl-87 D1"), or every open card on the row's key; open cards the page's yours section does not
# name get a YOURS row of their own, so no card is ever out of view.
card_files() { local id ids k f; id=$(id_of "$1"); f="$CARDS/${id// /-}.md"
  if [ -f "$f" ]; then echo "$f"; return; fi   # the row's own card, open or answered
  { ids=$(grep -oE "($(key_re)) [A-Z]+[0-9]+[a-z]*" <<<"$1" | sort -u)
    if [ -n "$ids" ]; then while read -r i; do f="$CARDS/${i// /-}.md"; [ -f "$f" ] && echo "$f"; done <<<"$ids"
    else k=$(key_of "$1"); [ -n "$k" ] && [ "$id" = "$k" ] && grep -l "^id: $k " "$CARDS"/*.md 2>/dev/null; fi
  } | while read -r f; do grep -q '^status: open' "$f" && echo "$f"; done; }
card_body() { local w=$(( ${FZF_PREVIEW_COLUMNS:-72} - 2 )) st; st=$(sed -n 's/^status: //p' "$1"); [ "$st" = open ] || st="$st: $(sed -n 's/^answer: //p' "$1")"
  printf '%scard %s%s  since %s  %s\n\n' "$CB" "$(sed -n 's/^id: //p' "$1")" "$C0" "$(sed -n 's/^since: //p' "$1" | cut -c1-16)" "$st"
  sed '1,/^---$/d' "$1" | python3 -c '
import sys, textwrap, re
w = int(sys.argv[1]); B, C, L = "\033[1m", "\033[34m", "\033[0m"; pad = " " * 10
fields = "problem|stakes|happened|options|rec|unverified|trace|reply"
paras = []; seen = False          # (label, text); label None = blank line
for raw in sys.stdin.read().split("\n"):
    line = raw.strip()
    m = re.match(r"^(%s):\s*(.*)$" % fields, line)
    if m: paras.append((m.group(1), m.group(2))); seen = True; continue
    if not line: paras.append((None, "")); continue
    if not seen or re.match(r"^([a-z]\)|-) ", line) or paras[-1][0] is None: paras.append(("", line)); continue
    lab, txt = paras[-1]; paras[-1] = (lab, (txt + " " + line).strip())
head = True
for lab, txt in paras:
    if lab is None: continue
    if lab == "" and not seen: print(B + txt + L); continue
    if head and lab == "": print(B + txt + L); continue
    head = False
    if lab: print()
    body = textwrap.fill(txt, width=w, initial_indent=pad, subsequent_indent=pad) if txt else pad
    if lab: body = C + B + lab.ljust(10) + L + body[10:]
    print(body)
' "$w"; echo; }
# d hides any YOURS row (lead-ux F3 a): a row whose bullet is in $D/read is dropped, whatever its source; u unhides the last
unhidden() { awk -F"$TAB" -v rf="$D/read" 'BEGIN { while ((getline l < rf) > 0) hid[l] = 1 } !($NF in hid)'; }
# a card row leaves on its own when the page's done today names it: the ticket key and the decision word on one line
done_named() { local id=$1 k t; k=${id%% *}; t=${id##* }; [ "$k" = "$id" ] && { grep -qF -- "$id" <<<"$DT"; return; }
  grep -F -- "$k" <<<"$DT" | grep -qwF -- "$t"; }
card_rows() { local f id q where since ic ys DT; ys=$(sed -n '/^## yours/,/^## [^y]/p' "$PAGE" 2>/dev/null); DT=$(awk -F"$TAB" '$1=="done today"{print $2}' "$D/rows.tmp" 2>/dev/null)
  grep -l '^status: open' "$CARDS"/*.md 2>/dev/null | while IFS= read -r f; do
    id=$(sed -n 's/^id: //p' "$f"); case "$ys" in *"$id"*) continue;; esac; done_named "$id" && continue
    ic=$(sed -n 's/^row: //p' "$f"); sed -n 's/^stop: *//p' "$FLEET/checks/$ic/STATE.md" 2>/dev/null | grep -qi '^closed' && continue
    where=$(sed -n 's/^where: //p' "$f"); since=$(sed -n 's/^since: //p' "$f" | cut -c1-16); q=$(sed '1,/^---$/d' "$f" | sed -n '2p')
    row yours "$id" "${q:-card} · not on lead-1's page" "$where pane" "$(mins_since "$since")" "$id · ${q:-card} · where: $where pane"; done; }
# a row: <visible>\t<kind>\t<id>\t<where>\t<bullet>
sec_head() { printf '\n%s%s%s%s\thead\t-\t-\t-\n' "$CB" "$1" "$C0" "${2:+  $CD$2$C0}"; }
# the page, parsed once per list: <section>\t<bullet>, hidden rows dropped
parse_page() { : > "$D/rows.tmp"; [ -f "$PAGE" ] || return 0
  awk -v rf="$D/read" 'BEGIN { while ((getline l < rf) > 0) hid[l] = 1 }
    /^## / { sec = tolower(substr($0, 4)); next } /^- / { b = substr($0, 3); if (b in hid) next; print sec "\t" b }' "$PAGE" > "$D/rows.tmp"; }
# page_rows <section> [kind] [say]: the rows of one page section; kind overrides the row kind; "say" keeps only rows with a say line
page_rows() { local sec=$1 kind=${2:-$1} only=${3:-} line id text where since m last="" shown
  awk -F"$TAB" -v s="$sec" '$1==s{print $2}' "$D/rows.tmp" | while IFS= read -r line; do
    [ "$only" = say ] && { tokv say "$line"; [ -z "$TOK" ] && continue; }
    case "$line" in *"$SEP"*) id=${line%%$SEP*};; *) id=$(key_of "$line");; esac; textv "$line"; text=$TEXT; tokv where "$line"; where=$TOK; tokv since "$line"; minsv "$TOK"; m=$MINS
    if [ -n "$id" ] && [ "$id" = "$last" ]; then shown=""; else shown=$id; fi; last=$id
    ROWDIM=""; [ "$sec" = running ] && down_row "$line" && ROWDIM=1; row "$kind" "$shown" "$text" "${where:-}" "$m" "$line"; ROWDIM=""; done; }
done_rows() { awk -F"$TAB" '$1=="done today"{print $2}' "$D/rows.tmp" | while IFS= read -r line; do printf '%s\t%s\n' "$(id_of "$line")" "$(text_of "$line")" >> "$D/done.tmp"; done; flush_done; }
# RED (lead-ux B1): an IC that cannot move without someone acting, or that lead-1 flagged. Until lead-1 writes "red: <why>"
# on the running row, the test is these words in the row or in the IC's stop line; the first sentence that holds one is the why.
RED_RE='red:|contradict|gate red|red line|failed|blocked|stuck|held on'
red_why() { local ic=$1 b=$2 s; s=$(sed -n 's/^stop: *//p' "$FLEET/checks/$ic/STATE.md" 2>/dev/null | head -1)
  grep -oiE "[^.;·]*($RED_RE)[^.;·]*" <<<"$b"$'\n'"$s" | head -1 | sed 's/^ *//'; }
red_rows() { local line id why; running_up | while IFS= read -r line; do id=$(id_of "$line"); why=$(red_why "$id" "$line"); [ -z "$why" ] && continue
    row red "$id" "$why" "$id pane" "$(mins_since "$(tok since "$line")")" "$line"; done; }
reports_unread() { local f; for f in "$REPORTS"/*.md; do [ -f "$f" ] || continue; grep -qxF "$f" "$D/read" && continue; printf '%s\t%s\n' "$(stat -f %m "$f")" "$f"; done | sort -rn; }
report_rows() { reports_unread | head -8 | { local first=1 mt f; while IFS="$TAB" read -r mt f; do [ -z "$f" ] && continue; [ $first = 1 ] && { sec_head REPORTS "from lead-1, newest first; d when read"; first=0; }
      printf '  %s%s%s %-78.78s\treport\t-\t-\t%s\n' "$CD" "$(TZ=UTC date -r "$mt" +%H:%MZ)" "$C0" "$(head -1 "$f" | sed 's/^# *//')" "$f"; done; }; }
# the board (lead-ux B1): YOURS, RED, one green line; l shows the log: every section lead-1 wrote, shaping, reports
list() { : > "$D/done.tmp"; parse_page; load_sess; local wrote n_you=0 n_red=0 n_run=0 n_next=0 n_shape=0 n_rep=0 view ids
  [ -f "$D/logview" ] && view=log || view=board
  [ -f "$PAGE" ] || { printf '%slead-1 has not written the page yet%s\t-\t-\t-\t-\n' "$CO" "$C0"; printf '%s  %s%s\t-\t-\t-\t-\n' "$CD" "$PAGE" "$C0"; }
  wrote=$(head -1 "$PAGE" 2>/dev/null | grep -oE '[0-9]{2}:[0-9]{2}Z' | head -1)
  n_run=$(running_up | grep -c .); n_down=$(( $(awk -F"$TAB" '$1=="running"' "$D/rows.tmp" | grep -c .) - n_run )); n_shape=$(shaping count); n_rep=$(reports_unread | grep -c .)
  if [ "$view" = board ]; then
    sec_head YOURS "waits on your word · r copies it · enter opens the card"
    { page_rows yours; pane_asks; card_rows; page_rows owed yours say; shaping words; live_asks "$D/yours.tmp"; } | unhidden > "$D/yours.tmp"; cat "$D/yours.tmp"; n_you=$(grep -c . "$D/yours.tmp")
    red_rows > "$D/red.tmp"; n_red=$(grep -c . "$D/red.tmp")
    [ "$n_red" -gt 0 ] && { sec_head RED "an IC that cannot move, or that lead-1 flagged · enter opens its state"; cat "$D/red.tmp"; }
    page_rows next > "$D/next.tmp"; n_next=$(grep -c . "$D/next.tmp")
    [ "$n_next" -gt 0 ] && { sec_head NEXT "filed, ok'd or owed, no IC yet · r copies the launch or shape line"; cat "$D/next.tmp"; }
    ids=$(running_up | while IFS= read -r line; do echo "$(id_of "$line")"; done | paste -sd'|' -)
    printf '\n  %sgreen%s  %s building · %s shaping · %s reports to read%s   %sl shows the log%s\tgreen\t-\t-\t%s\n' "$CG" "$C0" "$((n_run-n_red))" "$n_shape" "$n_rep" "$([ "$n_down" -gt 0 ] && printf ' · %s down' "$n_down")" "$CD" "$C0" "$ids"
  else
    sec_head YOURS "in lead-1's words, oldest first"; { page_rows yours; pane_asks; card_rows; live_asks "$D/yours.tmp"; } | unhidden > "$D/yours.tmp"; cat "$D/yours.tmp"
    sec_head NEXT "no IC yet"; page_rows next
    sec_head RUNNING; page_rows running
    sec_head OWED; page_rows owed
    sec_head "TODAY, PER TICKET" "every act lead-1 logged, grouped; the preview lists them in order"; done_rows
    awk -F"$TAB" '$1=="to read"' "$D/rows.tmp" | grep -q . && { sec_head "TO READ"; page_rows "to read"; }
    shaping all; report_rows
  fi
  echo "$n_you $n_red $n_run $view ${wrote:-never}" > "$D/counts"
}
header() { local y r n v w c; read -r y r n v w < "$D/counts" 2>/dev/null || { y=0; r=0; n=0; v=board; w=never; }; [ "${y:-0}" -gt "$BUDGET" ] && c=$CR || c=$CG
  if [ "$v" = log ]; then printf 'fleet-board · the log   everything lead-1 wrote: next, running, owed, today per ticket, to read; shaping; reports   page written %s   now %s   %sl back to the board%s\n' "$w" "$(date -u +%H:%MZ)" "$CB" "$C0"
  else printf 'fleet-board   yours %s%s%s   red %s   building %s   page written %s   now %s   the lead-1 chat stays for conversation\n' "$c" "$y" "$C0" "$r" "$((n-r))" "$w" "$(date -u +%H:%MZ)"; fi
  live_strip
  printf 'l the log   p resize the details   J K or the wheel scroll them   hold Option to select text   enter the card, the IC\x27s state or the report   r copy the say line   y copy the id   a copy the attach line   o open the ticket   d hide   u unhide the last   q quit\n'; }

# a row with no card file is drawn in the card shape from its own text (lead-ux F2 a): problem, options, rec, reply
nocard_body() { local w=$(( ${FZF_PREVIEW_COLUMNS:-72} - 2 )); printf '%scard %s%s  %sno card file · drawn from the row%s\n' "$CB" "$1" "$C0" "$CD" "$C0"
  python3 -I -c '
import sys, textwrap, re
w = int(sys.argv[1]); text = sys.argv[2]; say = sys.argv[3]
B, C, L = "\033[1m", "\033[34m", "\033[0m"; pad = " " * 10
labels = "problem|stakes|happened|options|rec|unverified|trace|reply"
out = []                                   # (label, text)
def add(lab, t):
    t = t.strip(" ;·")
    if t: out.append((lab, t))
rest = []
for seg in re.split(r"\s+·\s+", text):
    parts = re.split(r"(?:(?<=^)|(?<=[\s;.(]))(%s):\s*" % labels, seg)
    if parts[0].strip(): rest.append(parts[0])
    for i in range(1, len(parts) - 1, 2): add(parts[i], parts[i + 1])
body = " · ".join(r.strip() for r in rest if r.strip())
opts = []
m = re.search(r"\(\s*(a[ )].*?)\)\s*$", body)        # "(a this, b that, c other)"
if m:
    items = re.split(r"(?:^|,\s+|;\s+)(?=[a-e]\)?\s)", m.group(1))
    items = [i.strip() for i in items if i.strip()]
    if len(items) >= 2: opts = items; body = body[:m.start()].strip()
if not opts:
    m = re.search(r"[;.]\s*or\s+(\"[^\"]+\"[^.;]*)", body)   # ...; or "X later"
    if m: opts = ["a) " + say if say else "", "b) " + m.group(1).strip()]; opts = [o for o in opts if o]; body = (body[:m.start()] + body[m.end():]).strip()
have = dict((l, 1) for l, _ in out)
final = []
if body and "problem" not in have: final.append(("problem", body))
elif body: final.append(("", body))
final += [(l, t) for l, t in out if l != "reply"]
if opts and "options" not in have: final.append(("options", "\n".join(re.sub(r"^([a-e])\)?\s+", r"\1) ", o) for o in opts)))
if say: final.append(("reply", say))
for lab, t in final:
    print()
    first = True
    for part in t.split("\n"):
        body = textwrap.fill(part, width=w, initial_indent=pad, subsequent_indent=pad + ("   " if lab == "options" else ""))
        if first and lab: body = C + B + lab.ljust(10) + L + body[10:]
        first = False; print(body)
' "$w" "$2" "$3"; echo; }

preview() { local kind=$1 id=$2 where=$3 line=$4 say k u pane f
  case "$kind" in head|gap|-|'') echo "move to an item."; return;;
    green) printf '%sgreen%s  building, autonomous to the next STOP; nothing to do here\n\n' "$CW" "$C0"; tr '|' '\n' <<<"$line" | while read -r ic; do case "$ic" in ''|-) continue;; esac; printf '%s%s%s  %s\n' "$CB" "$ic" "$C0" "$(sed -n 's/^stop: *//p' "$FLEET/checks/$ic/STATE.md" 2>/dev/null | cut -c1-$(( ${FZF_PREVIEW_COLUMNS:-72} - 14 )))"
        live_of "$ic" && printf '  %slive%s  %s\n' "$CB" "$C0" "$(live_txt)"; done; return;;
    report) printf '%s%s%s\n\n' "$CW" "$(head -1 "$line")" "$C0"; sed 1d "$line" | head -60; return;;
    "done today") printf '%s%s%s  today, in order\n\n' "$CW" "$id" "$C0"; tr '¶' '\n' <<<"$line" | awk '{ t="     "; if (match($0, /[0-9][0-9]:[0-9][0-9]Z/)) t=substr($0, RSTART, 5); printf "%s  %s\n\n", t, $0 }' | fold -s -w 70; return;; esac
  say=$(tok say "$line"); k=$(key_of "$id"); u=$(url_of "$k" "$where"); pane=$(pane_of "$where")
  local w=$(( ${FZF_PREVIEW_COLUMNS:-72} - 2 )) cf; cf=$(card_files "$line"); printf '%s%s%s\n\n' "$CW" "$id" "$C0"
  if [ -n "$cf" ]; then text_of "$line" | fold -s -w "$w"; echo; printf '%s\n' "$cf" | while read -r f; do card_body "$f"; done
  else nocard_body "$id" "$(text_of "$line")" "$say"; fi
  [ -n "$say" ] && printf '%ssay%s    %s\n' "$CB" "$C0" "$(fold -s -w $((w-7)) <<<"$say" | sed '2,$s/^/       /')"
  [ -n "$where" ] && printf '%swhere%s  %s\n' "$CB" "$C0" "$where"
  live_of "${pane:-$id}" && printf '%slive%s   %s\n' "$CB" "$C0" "$(live_txt)"
  [ -n "$say" ] && printf '%sr%s      copies the say line\n' "$CB" "$C0"
  [ -n "$pane" ] && printf '%sa%s      copies  tmux attach -t %s   (type your word there)\n' "$CB" "$C0" "$pane"
  [ -n "$u" ] && printf '%so%s      opens  %s\n' "$CB" "$C0" "$u"
  f="$FLEET/checks/${pane:-$id}/STATE.md"; [ -f "$f" ] && printf '\n%senter%s  %s\x27s state: %s\n' "$CD" "$C0" "${pane:-$id}" "$(sed -n 's/^stop: *//p' "$f" | cut -c1-$((w-30)))"; }

case "${1:-}" in
  list) list | sed '1{/^$/d;}' ;; header) header ;;
  # preview saves its arguments, the pane width and its text in $D/pv.shown; the watcher re-runs it with FB_PEEK set and
  # refreshes the details pane only when the text changed, so a push does not scroll the reader back to the top
  preview) out=$(preview "$2" "$3" "$4" "$5"); printf '%s\n' "$out"
    [ -n "${FB_PEEK:-}" ] || { printf '%s\n%s\n%s\n%s\n%s\n%s\n' "${FZF_PREVIEW_COLUMNS:-}" "$2" "$3" "$4" "$5" "$out" > "$D/pv.new.$$" && mv -f "$D/pv.new.$$" "$D/pv.shown"; } ;;
  # d, l and ctrl-r: the watcher renders on a touch of $D/kick; when it is gone the key renders here (no frozen board)
  kick) [ -f "$D/live.pid" ] && read -r p < "$D/live.pid" && [ -n "$p" ] && kill -0 "$p" 2>/dev/null && { touch "$D/kick"; exit 0; }
    printf 'reload(%s render)' "$0" ;;
  # the watcher's push when only the ages moved: no reload (it would scroll the details pane to the top) while the
  # reader has scrolled the details (J K shift-up shift-down and the wheel set the preview label to one space; a cursor
  # move or a reload clears it), for up to 5 minutes without a key; the next tick tries again
  agereload) [ "${FZF_PREVIEW_LABEL:-}" = " " ] && [ "${FZF_IDLE_TIME:-0}" -lt 300 ] && exit 0
    printf 'reload(cat %s)' "$D/view" ;;
  render) "$0" list | gaps; "$0" header > "$D/header.sh.new" 2>/dev/null && mv -f "$D/header.sh.new" "$D/header" ;;
  say) tok say "$2" | tr -d '\n' | pbcopy ;;
  attach) p=$(pane_of "$2"); [ -n "$p" ] && printf 'tmux attach -t %s' "$p" | pbcopy ;;
  open) k=$(key_of "$2"); u=$(url_of "$k" "$3"); [ -n "$u" ] && open "$u" ;;
  done) echo "$2" >> "$D/read"; echo "$2" > "$D/read.last" ;;
  undone) [ -s "$D/read" ] && { sed '$d' "$D/read" > "$D/read.new.$$" && mv -f "$D/read.new.$$" "$D/read"; } ;;
  toggle) if [ -f "$D/logview" ]; then rm -f "$D/logview"; else touch "$D/logview"; fi ;;
  detail) if [ "$2" = report ]; then less -R "$3"; elif [ "$2" = shaping ]; then f="$FLEET/shaping/$4/brief.md"; [ -f "$f" ] && less -R "$f" || less -R "$FLEET/shaping/$4/CLAUDE.md"; else cf=$(card_files "$3"); if [ -n "$cf" ]; then for f in $cf; do card_body "$f"; done | less -R; exit 0; fi; p=$(pane_of "$4"); f="$FLEET/checks/${p:-$3}/STATE.md"; [ -f "$f" ] && less -R "$f" || less -R "$PAGE"; fi ;;
  *) command -v fzf >/dev/null || { echo "brew install fzf first"; exit 1; }
     EVERY=${REFRESH_SECS:-30}; export FZF_API_KEY=$(head -c 16 /dev/urandom | xxd -p); SOCK=${BOARD_SOCK:-$D/board.sock}; RMSOCK=""; PORT=""
     # one board per HOME: a second one would share $D's files and take the first one's socket (lead-ux F1 fix 4)
     if [ -f "$D/board.pid" ] && read -r OP < "$D/board.pid" && [ -n "$OP" ] && [ "$OP" != $$ ] && kill -0 "$OP" 2>/dev/null && ps -p "$OP" -o command= | grep -q fleet-board; then
       OS=$(tmux list-panes -a -F '#{pane_pid} #{session_name}' 2>/dev/null | awk -v p="$OP" '$1==p { print $2; exit }')
       printf 'a fleet-board already runs for this HOME (pid %s%s). quit it with q there first; this one does not start.\n' "$OP" "${OS:+, tmux session $OS}"; read -r -t 30 _; exit 1; fi
     if [ -S "$SOCK" ] && [ "$(curl -s -m 1 -o /dev/null -w '%{http_code}' --unix-socket "$SOCK" http://fzf/ 2>/dev/null)" != 000 ]; then
       printf 'another fzf answers on %s. quit that board first; this one does not start.\n' "$SOCK"; read -r -t 30 _; exit 1; fi
     echo $$ > "$D/board.pid"
     # push on change (lead-ux F1, v3): fleet-board-live.py watches the sources with kqueue and the Claude panes with a
     # read-only tmux list-panes, renders on a change and pushes to fzf's --listen unix socket; a socket path over 100
     # bytes (macOS limit 104) falls back to the TCP port. EVERY is only the fallback tick (ages, the clock).
     if [ ${#SOCK} -le 100 ]; then [ -S "$SOCK" ] && rm -f "$SOCK"; LISTEN="--listen=$SOCK"; TARGET="unix:$SOCK"; RMSOCK=$SOCK
     else PORT=${BOARD_PORT:-6266}; LISTEN="--listen-unsafe=127.0.0.1:$PORT"; TARGET="tcp:127.0.0.1:$PORT"; fi
     rm -f "$D/live" "$D/live.pid" "$D/sessions" "$D/view" "$D/header" "$D/started" "$D/pv.shown" "$D"/pv.new.*
     # the first list and header run before the watcher starts, so two lists never write $D/*.tmp at once
     "$0" list | gaps > "$D/view.start"; HDR=$("$0" header); printf '%s\n' "$HDR" > "$D/header"
     fzf_post() { if [ -n "$RMSOCK" ]; then curl -s -m 2 -o /dev/null --unix-socket "$SOCK" -H "x-api-key: $FZF_API_KEY" --data-binary "$1" http://fzf/
       else curl -s -m 2 -o /dev/null -H "x-api-key: $FZF_API_KEY" --data-binary "$1" "http://127.0.0.1:$PORT/"; fi; }
     # the watcher, started again when it crashes while the board runs (fix 3); exit 0 means the board or its fzf is gone.
     # Three crashes within 20 s of a start each: it stays down, and the header says so (live_strip reads $D/live.pid).
     live_loop() { local t0 rc quick=0 w
       while kill -0 $$ 2>/dev/null; do t0=$SECONDS
         python3 -I "$(dirname "$0")/fleet-board-live.py" "$0" "$TARGET" "$EVERY" "$$" >/dev/null 2>>"$D/live.err" & w=$!; echo $w > "$D/live.pid"
         wait $w; rc=$?; kill -0 $$ 2>/dev/null || break; [ $rc -eq 0 ] && break
         if [ $((SECONDS - t0)) -lt 20 ]; then quick=$((quick + 1)); else quick=1; fi
         printf '%sZ launch: the watcher exited with status %s, %s\n' "$(date -u +%H:%M:%S.000)" $rc "$([ $quick -ge 3 ] && echo 'the third quick exit: left down' || echo 'starting it again in 1 s')" >> "$D/live.log"
         [ $quick -ge 3 ] && break; sleep 1; done
       kill -0 $$ 2>/dev/null && { "$0" header > "$D/header.sh.new" 2>/dev/null && mv -f "$D/header.sh.new" "$D/header"; fzf_post "transform-header(cat $D/header)"; }; }
     live_loop 2>>"$D/live.err" & LIVE=$!     # its stderr too: a "Killed: 9" from wait would draw over fzf's screen
     trap 'kill $LIVE 2>/dev/null; [ -f "$D/live.pid" ] && read -r W < "$D/live.pid" && kill $W 2>/dev/null; rm -f "$D/live.pid" "$D/live"
       [ -n "$RMSOCK" ] && [ -S "$RMSOCK" ] && rm -f "$RMSOCK"; [ -f "$D/board.pid" ] && read -r OP < "$D/board.pid" && [ "$OP" = $$ ] && rm -f "$D/board.pid"' EXIT
     # fzf drops the actions after reload in a chained POST, so the watcher posts reload last and the load event
     # (fired when the reloaded list is in) applies the header: row and count in one frame. The details pane is
     # refreshed by the watcher only when its text changed (fix 5).
     fzf --ansi --delimiter="$TAB" --with-nth=1 --no-sort --track --id-nth=2,5 --layout=reverse-list --prompt='> ' "$LISTEN" \
       --header="$HDR" --header-first --preview="$0 preview {2} {3} {4} {5}" --preview-window=right,46%,wrap \
       --color='light,hl:166,hl+:166,fg+:-1,bg+:254,pointer:26,marker:26,header:-1,info:244,border:244,prompt:26' \
       --bind "enter:execute($0 detail {2} {5} {3} {4})" \
       --bind "r:execute-silent($0 say {5})+change-header(copied the say line. paste it where the item says: the lead-1 chat, or the IC's pane)" \
       --bind "a:execute-silent($0 attach {4})+change-header(copied the attach line. paste it in your own terminal; this board never attaches)" \
       --bind "o:execute-silent($0 open {3} {4})" \
       --bind "y:execute-silent(printf %s {3} | pbcopy)+change-header(copied {3}. to select text instead, hold Option while dragging)" \
       --bind "d:execute-silent($0 done {5})+transform($0 kick)" \
       --bind "u:execute-silent($0 undone)+transform($0 kick)" \
       --bind "l:execute-silent($0 toggle)+transform($0 kick)" \
       --bind "ctrl-r:transform($0 kick)" --bind "p:change-preview-window(right,60%|right,75%|down,60%|hidden|right,46%)" --bind "J:preview-down+change-preview-label( )" --bind "K:preview-up+change-preview-label( )" --bind "shift-down:preview-page-down+change-preview-label( )" --bind "shift-up:preview-page-up+change-preview-label( )" --bind "preview-scroll-down:preview-down+change-preview-label( )" --bind "preview-scroll-up:preview-up+change-preview-label( )" --bind "focus:change-preview-label()" --bind "q:abort" --bind "load:transform-header(cat $D/header)+change-preview-label()+transform:[ -f $D/started ] || { touch $D/started; echo down; }" < "$D/view.start" ;;
esac
