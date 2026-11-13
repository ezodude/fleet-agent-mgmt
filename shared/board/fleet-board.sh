#!/usr/bin/env bash
# fleet-board V2 (lead-ux R1 a, B1): YOURS, RED and one green line by default; l shows the log.: a viewer of lead-1's living page, $FLEET_HOME/checks/lead-1/board.md,
# written by lead-1 from $FLEET_REPO/shared/skills/keeping-the-board/board-template.md: ## yours, ## next, ## running, ## owed, ## done today, ## to read. One bullet per item,
# fields split by " · ": id · sentences · say: <line> · where: <lead-1 chat | <ic> pane> · since: <HH:MMZ>.
# Reads only. Never attaches, switches or types into a pane. Scrap: delete this file, kill tmux session fleet-board.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/../lib/paths.sh"
FLEET="$FLEET_HOME"; PAGE="$FLEET/checks/lead-1/board.md"; CARDS="$FLEET/checks/lead-1/cards"; REPORTS="$FLEET/checks/lead-1/reports"
D="$FLEET_HOME/board-state"; mkdir -p "$D"; touch "$D/read"
ORANGE=${ORANGE_AFTER:-30}; RED=${RED_AFTER:-60}; BUDGET=${BUDGET:-5}
C0=$'\e[0m'; CB=$'\e[1;38;5;26m'; CG=$'\e[38;5;28m'; CD=$'\e[38;5;244m'; CO=$'\e[38;5;166m'; CR=$'\e[1;38;5;160m'; CW=$'\e[1m'
TAB=$'\t'; SEP=' · '; NOW=$(date -u +%s)

tok() { grep -oE "(^| · )$1: *[^·]*" <<<"$2" | head -1 | sed "s/^.*$1: *//;s/ *$//"; }
# since: accepts HH:MMZ (today), MM-DD, YYYY-MM-DD, or YYYY-MM-DD HH:MMZ; prints minutes ago, or nothing
mins_since() { local t=$1 s=""; [ -z "$t" ] && { echo ""; return; }
  case "$t" in
    [0-9][0-9]:[0-9][0-9]Z|[0-9][0-9]:[0-9][0-9]) s=$(TZ=UTC date -j -f '%Y-%m-%d %H:%M' "$(date -u +%Y-%m-%d) ${t%Z}" +%s 2>/dev/null);;
    [0-9][0-9]-[0-9][0-9]) s=$(TZ=UTC date -j -f '%Y-%m-%d %H:%M' "$(date -u +%Y)-$t 00:00" +%s 2>/dev/null);;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) s=$(TZ=UTC date -j -f '%Y-%m-%d %H:%M' "$t 00:00" +%s 2>/dev/null);;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]*) s=$(TZ=UTC date -j -f '%Y-%m-%d %H:%M' "${t%Z}" +%s 2>/dev/null);;
  esac
  [ -z "$s" ] && { echo ""; return; }; [ "$s" -gt "$NOW" ] && s=$((s-86400)); echo $(( (NOW-s)/60 )); }
age() { local m=$1 t c; [ -z "$m" ] && { printf '%7s' ''; return; }
  if [ "$m" -ge 1440 ]; then t="$((m/1440))d"; elif [ "$m" -ge 60 ]; then t="$((m/60))h$(printf %02d $((m%60)))"; else t="${m}m"; fi
  if [ "$m" -ge "$RED" ]; then c=$CR; t="$t ▲"; elif [ "$m" -ge "$ORANGE" ]; then c=$CO; else c=$CD; fi; printf '%s%7s%s' "$c" "$t" "$C0"; }
# key_re: ticket-key regex; lowercase lane names (one per line in $FLEET_HOME/lane-prefixes.txt) add "<lane>-N" and "<lane> #N"
key_re() { local l; l=$(grep -E '^[a-z][a-z0-9]*$' "$FLEET_HOME/lane-prefixes.txt" 2>/dev/null | paste -sd'|' -); echo "[A-Za-z]+-[0-9]+${l:+|($l)-[0-9]+|($l) #[0-9]+}"; }
key_of() { local k; k=$(grep -oE "$(key_re)" <<<"$1" | head -1); [ -n "$k" ] && echo "$k" || grep -oE 'PR #[0-9]+|PR [0-9]{3,}|#[0-9]+' <<<"$1" | head -1; }
url_of() { local k=$1; [ -n "$k" ] && [ -f "$FLEET_HOME/board-links.tsv" ] && awk -F'\t' -v k="$k" '$1==k{print $2; exit}' "$FLEET_HOME/board-links.tsv"; return 0; }
# id: the first field when the bullet has fields; else the ticket key in it. text: every other field that is not a token.
id_of() { case "$1" in *"$SEP"*) printf '%s' "${1%%$SEP*}";; *) key_of "$1";; esac; }
text_of() { case "$1" in *"$SEP"*) sed 's/^[^·]*· *//' <<<"$1";; *) local k; k=$(key_of "$1"); [ -n "$k" ] && sed "s/^$k[ :,.]*//" <<<"$1" || printf '%s' "$1";; esac | tr '·' '\n' | grep -vE '^ *(say|where|since):' | sed 's/^ *//;s/ *$//' | paste -sd'|' - | sed 's/|/ · /g'; }
pane_of() { grep -oE '^[a-z0-9-]+ pane' <<<"$1" | sed 's/ pane$//'; }

# done today is a log in lead-1's hand; the board shows one row per ticket (count, latest line), the rest behind the preview
flush_done() { [ -s "$D/done.tmp" ] || return 0
  awk -F"$TAB" '{ id=$1; if(id=="") id="fleet"; if(!(id in n)) order[++k]=id; n[id]++; last[id]=$2; all[id]=all[id] (all[id]==""?"":"¶") $2
      t=""; if (match($2, /[0-9][0-9]:[0-9][0-9]Z/)) t=substr($2, RSTART, 5); if (t!="") { if (first[id]=="" || t<first[id]) first[id]=t; if (t>latest[id]) latest[id]=t } }
    END { for(i=1;i<=k;i++){ id=order[i]; span=(first[id]==""?"":first[id] (latest[id]==first[id]?"":"-" latest[id])); printf "%s\t%d\t%s\t%s\t%s\n", id, n[id], span, last[id], all[id] } }' "$D/done.tmp" | while IFS="$TAB" read -r id n span last all; do
    printf '  %s%-22.22s%s %s%2d acts %-11s%s %-58.58s\tdone today\t%s\t-\t%s\n' "$CW" "$id" "$C0" "$CD" "$n" "$span" "$C0" "$last" "$id" "$all"; done; : > "$D/done.tmp"; }
# one row, every source: row <sec> <id shown> <text> <where> <mins> <bullet>
# ROWDIM set: the id and text print dim (a running row that is idle or down)
row() { local c=$CW t; t=$(printf '%-66.66s' "$3"); [ -n "${ROWDIM:-}" ] && { c=$CD; t="$CD$t$C0"; }; printf '  %s%-22.22s%s %s %s%-16.16s%s %s\t%s\t%s\t%s\t%s\n' "$c" "$2" "$C0" "$t" "$CD" "$4" "$C0" "$(age "$5")" "$1" "$2" "$4" "$6"; }
# a running row whose second field starts with idle or down (an IC whose session ended) is never building
down_row() { local t w; t=$(sed 's/^[^·]*· *//' <<<"$1"); t=${t%%$SEP*}; w=$(printf '%s' "$t" | tr 'A-Z' 'a-z' | tr -d ',.:' | cut -d' ' -f1); [ "$w" = idle ] || [ "$w" = down ]; }
running_up() { awk -F"$TAB" '$1=="running"{print $2}' "$D/rows.tmp" | while IFS= read -r line; do down_row "$line" || printf '%s\n' "$line"; done; }
# a pane ask lead-1 cannot see: an IC whose STATE.md awaits the owner and whom the page's yours section does not name
pane_asks() { local f ic a; for f in "$FLEET"/checks/*/STATE.md; do [ -f "$f" ] || continue; ic=$(basename "$(dirname "$f")"); [ "$ic" = lead-1 ] && continue
    a=$(sed -n 's/^awaiting: *owner: *//p' "$f" | head -1)
    [ -z "$a" ] && ! sed -n 's/^stop: *//p' "$f" | head -1 | grep -qi '^closed' && a=$(sed -n 's/^next: *//p' "$f" | head -1 | grep -i "owner" | grep -vi '^none' | sed 's/$/ (from next:, awaiting says none)/'); [ -z "$a" ] && continue
    sed -n '/^## yours/,/^## [^y]/p' "$PAGE" 2>/dev/null | grep -qi -- "$ic" && continue
    row yours "$ic" "$a · not on lead-1's page" "$ic pane" "$(mins_since "$(sed -n 's/^updated: *//p' "$f" | cut -c1-16)")" "$ic · $a · where: $ic pane"; done; }
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
card_rows() { local f id q where since ic; for f in "$CARDS"/*.md; do [ -f "$f" ] && grep -q '^status: open' "$f" || continue
    id=$(sed -n 's/^id: //p' "$f"); sed -n '/^## yours/,/^## [^y]/p' "$PAGE" 2>/dev/null | grep -qF -- "$id" && continue
    ic=$(sed -n 's/^row: //p' "$f"); sed -n 's/^stop: *//p' "$FLEET/checks/$ic/STATE.md" 2>/dev/null | grep -qi '^closed' && continue
    where=$(sed -n 's/^where: //p' "$f"); since=$(sed -n 's/^since: //p' "$f" | cut -c1-16); q=$(sed '1,/^---$/d' "$f" | sed -n '2p')
    row yours "$id" "${q:-card} · not on lead-1's page" "$where pane" "$(mins_since "$since")" "$id · ${q:-card} · where: $where pane"; done; }
# a row: <visible>\t<kind>\t<id>\t<where>\t<bullet>
sec_head() { printf '\n%s%s%s%s\thead\t-\t-\t-\n' "$CB" "$1" "$C0" "${2:+  $CD$2$C0}"; }
# the page, parsed once per list: <section>\t<bullet>, hidden rows dropped
parse_page() { : > "$D/rows.tmp"; local sec="" line; [ -f "$PAGE" ] || return 0
  while IFS= read -r line; do case "$line" in
    '## '*) sec=$(tr 'A-Z' 'a-z' <<<"${line#\#\# }");;
    '- '*) line=${line#- }; grep -qxF "$line" "$D/read" && continue; printf '%s\t%s\n' "$sec" "$line" >> "$D/rows.tmp";; esac; done < "$PAGE"; }
# page_rows <section> [kind] [say]: the rows of one page section; kind overrides the row kind; "say" keeps only rows with a say line
page_rows() { local sec=$1 kind=${2:-$1} only=${3:-} line id text where since m last="" shown
  awk -F"$TAB" -v s="$sec" '$1==s{print $2}' "$D/rows.tmp" | while IFS= read -r line; do
    [ "$only" = say ] && [ -z "$(tok say "$line")" ] && continue
    id=$(id_of "$line"); text=$(text_of "$line"); where=$(tok where "$line"); since=$(tok since "$line"); m=$(mins_since "$since")
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
list() { : > "$D/done.tmp"; parse_page; local wrote n_you=0 n_red=0 n_run=0 n_next=0 n_shape=0 n_rep=0 view ids
  [ -f "$D/logview" ] && view=log || view=board
  [ -f "$PAGE" ] || { printf '%slead-1 has not written the page yet%s\t-\t-\t-\t-\n' "$CO" "$C0"; printf '%s  %s%s\t-\t-\t-\t-\n' "$CD" "$PAGE" "$C0"; }
  wrote=$(head -1 "$PAGE" 2>/dev/null | grep -oE '[0-9]{2}:[0-9]{2}Z' | head -1)
  n_run=$(running_up | grep -c .); n_down=$(( $(awk -F"$TAB" '$1=="running"' "$D/rows.tmp" | grep -c .) - n_run )); n_shape=$(shaping count); n_rep=$(reports_unread | grep -c .)
  if [ "$view" = board ]; then
    sec_head YOURS "waits on your word · r copies it · enter opens the card"
    { page_rows yours; pane_asks; card_rows; page_rows owed yours say; shaping words; } > "$D/yours.tmp"; cat "$D/yours.tmp"; n_you=$(grep -c . "$D/yours.tmp")
    red_rows > "$D/red.tmp"; n_red=$(grep -c . "$D/red.tmp")
    [ "$n_red" -gt 0 ] && { sec_head RED "an IC that cannot move, or that lead-1 flagged · enter opens its state"; cat "$D/red.tmp"; }
    page_rows next > "$D/next.tmp"; n_next=$(grep -c . "$D/next.tmp")
    [ "$n_next" -gt 0 ] && { sec_head NEXT "filed, ok'd or owed, no IC yet · r copies the launch or shape line"; cat "$D/next.tmp"; }
    ids=$(running_up | while IFS= read -r line; do echo "$(id_of "$line")"; done | paste -sd'|' -)
    printf '\n  %sgreen%s  %s building · %s shaping · %s reports to read%s   %sl shows the log%s\tgreen\t-\t-\t%s\n' "$CG" "$C0" "$((n_run-n_red))" "$n_shape" "$n_rep" "$([ "$n_down" -gt 0 ] && printf ' · %s down' "$n_down")" "$CD" "$C0" "$ids"
  else
    sec_head YOURS "in lead-1's words, oldest first"; page_rows yours; pane_asks; card_rows
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
  printf 'l the log   p resize the details   J K or the wheel scroll them   hold Option to select text   enter the card, the IC\x27s state or the report   r copy the say line   y copy the id   a copy the attach line   o open the ticket   d hide   q quit\n'; }

preview() { local kind=$1 id=$2 where=$3 line=$4 say k u pane f
  case "$kind" in head|-) echo "move to an item."; return;;
    green) printf '%sgreen%s  building, autonomous to the next STOP; nothing to do here\n\n' "$CW" "$C0"; tr '|' '\n' <<<"$line" | while read -r ic; do [ -z "$ic" ] && continue; printf '%s%s%s  %s\n' "$CB" "$ic" "$C0" "$(sed -n 's/^stop: *//p' "$FLEET/checks/$ic/STATE.md" 2>/dev/null | cut -c1-$(( ${FZF_PREVIEW_COLUMNS:-72} - 14 )))"; done; return;;
    report) printf '%s%s%s\n\n' "$CW" "$(head -1 "$line")" "$C0"; sed 1d "$line" | head -60; return;;
    "done today") printf '%s%s%s  today, in order\n\n' "$CW" "$id" "$C0"; tr '¶' '\n' <<<"$line" | awk '{ t="     "; if (match($0, /[0-9][0-9]:[0-9][0-9]Z/)) t=substr($0, RSTART, 5); printf "%s  %s\n\n", t, $0 }' | fold -s -w 70; return;; esac
  say=$(tok say "$line"); k=$(key_of "$id"); u=$(url_of "$k" "$where"); pane=$(pane_of "$where")
  local w=$(( ${FZF_PREVIEW_COLUMNS:-72} - 2 )); printf '%s%s%s\n\n' "$CW" "$id" "$C0"; text_of "$line" | fold -s -w "$w"; echo
  card_files "$line" | while read -r f; do card_body "$f"; done
  [ -n "$say" ] && printf '%ssay%s    %s\n' "$CB" "$C0" "$(fold -s -w $((w-7)) <<<"$say" | sed '2,$s/^/       /')"
  [ -n "$where" ] && printf '%swhere%s  %s\n' "$CB" "$C0" "$where"
  [ -n "$say" ] && printf '%sr%s      copies the say line\n' "$CB" "$C0"
  [ -n "$pane" ] && printf '%sa%s      copies  tmux attach -t %s   (type your word there)\n' "$CB" "$C0" "$pane"
  [ -n "$u" ] && printf '%so%s      opens  %s\n' "$CB" "$C0" "$u"
  f="$FLEET/checks/${pane:-$id}/STATE.md"; [ -f "$f" ] && printf '\n%senter%s  %s\x27s state: %s\n' "$CD" "$C0" "${pane:-$id}" "$(sed -n 's/^stop: *//p' "$f" | cut -c1-$((w-30)))"; }

case "${1:-}" in
  list) list | sed '1{/^$/d;}' ;; header) header ;; preview) preview "$2" "$3" "$4" "$5" ;;
  say) tok say "$2" | tr -d '\n' | pbcopy ;;
  attach) p=$(pane_of "$2"); [ -n "$p" ] && printf 'tmux attach -t %s' "$p" | pbcopy ;;
  open) k=$(key_of "$2"); u=$(url_of "$k" "$3"); [ -n "$u" ] && open "$u" ;;
  done) echo "$2" >> "$D/read" ;;
  toggle) if [ -f "$D/logview" ]; then rm -f "$D/logview"; else touch "$D/logview"; fi ;;
  detail) if [ "$2" = report ]; then less -R "$3"; elif [ "$2" = shaping ]; then f="$FLEET/shaping/$4/brief.md"; [ -f "$f" ] && less -R "$f" || less -R "$FLEET/shaping/$4/CLAUDE.md"; else cf=$(card_files "$3"); if [ -n "$cf" ]; then for f in $cf; do card_body "$f"; done | less -R; exit 0; fi; p=$(pane_of "$4"); f="$FLEET/checks/${p:-$3}/STATE.md"; [ -f "$f" ] && less -R "$f" || less -R "$PAGE"; fi ;;
  *) command -v fzf >/dev/null || { echo "brew install fzf first"; exit 1; }
     PORT=${BOARD_PORT:-6266}; EVERY=${REFRESH_SECS:-30}; export FZF_API_KEY=$(head -c 16 /dev/urandom | xxd -p)
     ( while sleep "$EVERY"; do curl -s -H "x-api-key: $FZF_API_KEY" -X POST "127.0.0.1:$PORT" -d "reload($0 list)+change-header($("$0" header))+refresh-preview" >/dev/null || break; done ) &
     rm -f "$D/started"; TICK=$!; trap 'kill $TICK 2>/dev/null' EXIT
     "$0" list | fzf --ansi --delimiter="$TAB" --with-nth=1 --no-sort --layout=reverse-list --prompt='> ' --listen-unsafe="127.0.0.1:$PORT" \
       --header="$("$0" header)" --header-first --preview="$0 preview {2} {3} {4} {5}" --preview-window=right,46%,wrap \
       --color='light,hl:166,hl+:166,fg+:-1,bg+:254,pointer:26,marker:26,header:-1,info:244,border:244,prompt:26' \
       --bind "enter:execute($0 detail {2} {5} {3} {4})" \
       --bind "r:execute-silent($0 say {5})+change-header(copied the say line. paste it where the item says: the lead-1 chat, or the IC's pane)" \
       --bind "a:execute-silent($0 attach {4})+change-header(copied the attach line. paste it in your own terminal; this board never attaches)" \
       --bind "o:execute-silent($0 open {3} {4})" \
       --bind "y:execute-silent(printf %s {3} | pbcopy)+change-header(copied {3}. to select text instead, hold Option while dragging)" \
       --bind "d:execute-silent($0 done {5})+reload($0 list)+transform-header($0 header)+refresh-preview" \
       --bind "l:execute-silent($0 toggle)+reload($0 list)+transform-header($0 header)+refresh-preview" \
       --bind "ctrl-r:reload($0 list)+transform-header($0 header)+refresh-preview" --bind "p:change-preview-window(right,60%|right,75%|down,60%|hidden|right,46%)" --bind "J:preview-down" --bind "K:preview-up" --bind "shift-down:preview-page-down" --bind "shift-up:preview-page-up" --bind "q:abort" --bind "load:transform:[ -f $D/started ] || { touch $D/started; echo down; }" ;;
esac
