#!/usr/bin/env bash
# fleet-board V1 (lead-ux R1 a): a viewer of lead-1's living page, $FLEET_HOME/checks/lead-1/board.md,
# written by lead-1 in prose: ## yours, ## running, ## done today, optional ## to read. One bullet per item,
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
row() { printf '  %s%-22.22s%s %-66.66s %s%-16.16s%s %s\t%s\t%s\t%s\t%s\n' "$CW" "$2" "$C0" "$3" "$CD" "$4" "$C0" "$(age "$5")" "$1" "$2" "$4" "$6"; }
# a pane ask lead-1 cannot see: an IC whose STATE.md awaits the owner and whom the page's yours section does not name
pane_asks() { local f ic a; for f in "$FLEET"/checks/*/STATE.md; do ic=$(basename "$(dirname "$f")"); [ "$ic" = lead-1 ] && continue
    a=$(sed -n 's/^awaiting: *owner: *//p' "$f" | head -1)
    [ -z "$a" ] && ! sed -n 's/^stop: *//p' "$f" | head -1 | grep -qi '^closed' && a=$(sed -n 's/^next: *//p' "$f" | head -1 | grep -i "owner" | grep -vi '^none' | sed 's/$/ (from next:, awaiting says none)/'); [ -z "$a" ] && continue
    sed -n '/^## yours/,/^## [^y]/p' "$PAGE" 2>/dev/null | grep -qi -- "$ic" && continue
    row yours "$ic" "$a · not on lead-1's page" "$ic pane" "$(mins_since "$(sed -n 's/^updated: *//p' "$f" | cut -c1-16)")" "$ic · $a · where: $ic pane"; done; }
# a shaping folder: no brief yet, a brief in progress, or stamped "<idea> brief ok" (then r copies the word for lead-1)
shaping() { local d idea f st say="" m up first=1; for d in "$FLEET"/shaping/*/; do [ -d "$d" ] || continue; idea=$(basename "$d"); f="$d/brief.md"
    tmux has-session -t "=shape-$idea" 2>/dev/null && up="session up" || up="no session"
    if [ ! -f "$f" ]; then st="no brief yet · $up"; m=$(mins_since "$(TZ=UTC date -r "$(stat -f %m "$d")" '+%Y-%m-%d %H:%M')")
    elif grep -qF "$idea brief ok" "$f"; then st="brief ok · r copies the word for the lead-1 pane · $up"; say="shape $idea done"; m=$(mins_since "$(grep -F "$idea brief ok" "$f" | grep -oE '[0-9]{2}:[0-9]{2}Z' | head -1)")
    else st="brief in progress, $(wc -l <"$f" | tr -d ' ') lines · $up"; m=$(mins_since "$(TZ=UTC date -r "$(stat -f %m "$f")" '+%Y-%m-%d %H:%M')"); fi
    [ $first = 1 ] && { printf '\n%sSHAPING%s\thead\t-\t-\t-\n' "$1" "$2"; first=0; }
    row shaping "$idea" "$st" "shape-$idea pane" "$m" "$idea · $st${say:+ · say: $say} · where: shape-$idea pane"; done; }
# cards: lead-1's decision-card files (shared/ledger/card-add.sh). card_files <bullet> prints the open card files the
# row names ("atlas-87 D1"), or every open card on the row's key; open cards the page's yours section does not
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
list() { : > "$D/done.tmp"
  local sec="" line id text say where since m n_you=0 n_run=0 wrote last="" shown
  if [ ! -f "$PAGE" ]; then printf '%slead-1 has not written the page yet%s\t-\t-\t-\t-\n' "$CO" "$C0"; printf '%s  %s%s\t-\t-\t-\t-\n' "$CD" "$PAGE" "$C0"
  else
    wrote=$(head -1 "$PAGE" | grep -oE '[0-9]{2}:[0-9]{2}Z' | head -1)
    while IFS= read -r line; do
      case "$line" in
        '## '*) flush_done; last=""; sec=$(tr 'A-Z' 'a-z' <<<"${line#\#\# }"); case "$sec" in yours) printf '\n%sYOURS%s  %sin lead-1\x27s words, oldest first%s\thead\t-\t-\t-\n' "$CB" "$C0" "$CD" "$C0"; pane_asks; card_rows;;
            running) printf '\n%sRUNNING%s\thead\t-\t-\t-\n' "$CB" "$C0";; "done today") printf '\n%sTODAY, PER TICKET%s  %severy act lead-1 logged, grouped; the preview lists them in order%s\thead\t-\t-\t-\n' "$CB" "$C0" "$CD" "$C0";; *) printf '\n%s%s%s\thead\t-\t-\t-\n' "$CB" "$(tr 'a-z' 'A-Z' <<<"$sec")" "$C0";; esac;;
        '- '*) line=${line#- }; grep -qxF "$line" "$D/read" && continue
          id=$(id_of "$line"); text=$(text_of "$line"); say=$(tok say "$line"); where=$(tok where "$line"); since=$(tok since "$line"); m=$(mins_since "$since")
          case "$sec" in yours) n_you=$((n_you+1));; running) n_run=$((n_run+1));; "done today") printf '%s\t%s\n' "$id" "$text" >> "$D/done.tmp"; continue;; esac
          if [ -n "$id" ] && [ "$id" = "$last" ]; then shown=""; else shown=$id; fi; last=$id
          row "$sec" "$shown" "$text" "${where:-}" "$m" "$line";;
      esac; done < "$PAGE"; flush_done
  fi
  # shaping folders (shape-up.sh): one row each, until --done deletes the folder
  shaping "$CB" "$C0" "$CD"
  # reports and open cards lead-1 wrote as files, newest first
  { for f in "$REPORTS"/*.md; do [ -f "$f" ] || continue; grep -qxF "$f" "$D/read" && continue; printf '%s\t%s\n' "$(stat -f %m "$f")" "$f"; done; } | sort -rn | head -8 | {
    first=1; while IFS="$TAB" read -r mt f; do [ -z "$f" ] && continue; [ $first = 1 ] && { printf '\n%sREPORTS%s  %sfrom lead-1, newest first; d when read%s\thead\t-\t-\t-\n' "$CB" "$C0" "$CD" "$C0"; first=0; }
      printf '  %s%s%s %-78.78s\treport\t-\t-\t%s\n' "$CD" "$(TZ=UTC date -r "$mt" +%H:%MZ)" "$C0" "$(head -1 "$f" | sed 's/^# *//')" "$f"; done; }
  echo "$n_you $n_run ${wrote:-never}" > "$D/counts"
}
header() { local y r w c; read -r y r w < "$D/counts" 2>/dev/null || { y=0; r=0; w=never; }; [ "${y:-0}" -gt "$BUDGET" ] && c=$CR || c=$CG
  printf 'fleet-board   yours %s%s of %s%s   running %s   page written %s   now %s   the lead-1 chat stays for conversation\n' "$c" "$y" "$BUDGET" "$C0" "$r" "$w" "$(date -u +%H:%MZ)"
  printf 'p resize the details   J K or the wheel scroll them   hold Option to select text   enter the card, the IC\x27s state or the report   r copy the say line   y copy the id   a copy the attach line   o open the ticket   d hide   q quit\n'; }

preview() { local kind=$1 id=$2 where=$3 line=$4 say k u pane f
  case "$kind" in head|-) echo "move to an item."; return;;
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
  detail) if [ "$2" = report ]; then less -R "$3"; elif [ "$2" = shaping ]; then f="$FLEET/shaping/$4/brief.md"; [ -f "$f" ] && less -R "$f" || less -R "$FLEET/shaping/$4/CLAUDE.md"; else cf=$(card_files "$3"); if [ -n "$cf" ]; then for f in $cf; do card_body "$f"; done | less -R; exit 0; fi; p=$(pane_of "$4"); f="$FLEET/checks/${p:-$3}/STATE.md"; [ -f "$f" ] && less -R "$f" || less -R "$PAGE"; fi ;;
  *) command -v fzf >/dev/null || { echo "brew install fzf first"; exit 1; }
     PORT=${BOARD_PORT:-6266}; EVERY=${REFRESH_SECS:-30}; export FZF_API_KEY=$(head -c 16 /dev/urandom | xxd -p)
     ( while sleep "$EVERY"; do curl -s -H "x-api-key: $FZF_API_KEY" -X POST "127.0.0.1:$PORT" -d "reload($0 list)+change-header($("$0" header))" >/dev/null || break; done ) &
     rm -f "$D/started"; TICK=$!; trap 'kill $TICK 2>/dev/null' EXIT
     "$0" list | fzf --ansi --delimiter="$TAB" --with-nth=1 --no-sort --layout=reverse-list --prompt='> ' --listen-unsafe="127.0.0.1:$PORT" \
       --header="$("$0" header)" --header-first --preview="$0 preview {2} {3} {4} {5}" --preview-window=right,46%,wrap \
       --color='light,hl:166,hl+:166,fg+:-1,bg+:254,pointer:26,marker:26,header:-1,info:244,border:244,prompt:26' \
       --bind "enter:execute($0 detail {2} {5} {3} {4})" \
       --bind "r:execute-silent($0 say {5})+change-header(copied the say line. paste it where the item says: the lead-1 chat, or the IC's pane)" \
       --bind "a:execute-silent($0 attach {4})+change-header(copied the attach line. paste it in your own terminal; this board never attaches)" \
       --bind "o:execute-silent($0 open {3} {4})" \
       --bind "y:execute-silent(printf %s {3} | pbcopy)+change-header(copied {3}. to select text instead, hold Option while dragging)" \
       --bind "d:execute-silent($0 done {5})+reload($0 list)+change-header($("$0" header))" \
       --bind "ctrl-r:reload($0 list)+change-header($("$0" header))" --bind "p:change-preview-window(right,60%|right,75%|down,60%|hidden|right,46%)" --bind "J:preview-down" --bind "K:preview-up" --bind "shift-down:preview-page-down" --bind "shift-up:preview-page-up" --bind "q:abort" --bind "load:transform:[ -f $D/started ] || { touch $D/started; echo down; }" ;;
esac
