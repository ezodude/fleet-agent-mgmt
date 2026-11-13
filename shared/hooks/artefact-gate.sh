#!/bin/bash
# PreToolUse hook, matcher "Write|Edit|MultiEdit". An artefact path is written
# only after its skill was invoked this session; otherwise the call is denied
# with the instruction, the model invokes the skill, and the retry passes.
# ic: */analysis/, */adr/, */specs/, *-close.md, and the rung's record folder under
# ~/.fleet-agent-mgmt/records/ (decision-record.md, evidence.md, close.md).
# FROZEN, ic: rules.md, gate.md, frozen.sha256, stop1.log and a *-pre-*.md copy in a record
# folder are denied outright: the freeze writes them, the message gate writes stop1.log at
# STOP 1, lead-1 amends them and re-hashes with shared/amend-frozen.sh. A write through Bash
# is denied by push-gate.sh (FROZEN WRITE GATE, best effort); frozen.sha256 and the chain to
# the STOP 1 commit catch the rest at gate-run, dr-check, the STOP and the push.
# HANDOFF, ic: the record's handoff.md (lead-1's) and ic-sessions.log (the IC hooks' line per IC
# session, shared/frozen.py stamp) are denied outright: a rung's handoff edited into a chore's is
# how an IC would skip its spec and STOP 1.
# APPEND ONLY, ic: decision-record.md and evidence.md in a record folder take an entry only at
# the end (shared/records/record_add.py --guard): an Edit or MultiEdit is denied unless each edit's
# old_string is the end of the file and its new_string starts with it; a Write over the file
# when it has text is denied; creating it is allowed when it starts with its header. The
# deny names shared/records/record-add.sh. A write through Bash is denied by push-gate.sh (RECORD
# WRITE GATE, best effort). lead-1 is not guarded: it writes review lines mid-file at its audit.
# An appended entry is checked too: it starts on a line of its own, at the left edge (an indented
# line would join the entry above after its check), each line at the left edge is the header of the
# next entry by number, and it carries no jev line and no review line other than `-`.
# RECEIPTS, ic: a receipts/*-jev-*.json is written only by the Jev check; an IC's write is denied.
# SESSION LOGS, ic: a .jsonl under ~/.claude/projects/ (Claude Code's session logs, where the freeze reads
# the owner's "spec ok") is denied outright, the path resolved first; the memory/ folder beside them stays
# writable; push-gate.sh denies the Bash forms.
# The names are matched in any case (the macOS file system ignores it), and a path to a record file
# is resolved first (/./, //, a link to the folder or the file), so another spelling of it is the file.
# lead: session handoffs under Leads/lead-1/handoffs/; the rung's brief.md and
# handoff.md in its record folder. Rung handoffs, briefs and tickets under
# Leads/lead-1/ are history: a write there is denied, project data stays out of AgentMgmt.
# PRECEDENTS, lead: the record's precedents.json is written with sweeping-precedents, and the first write of a
# rung brief (records/<project>/<record>/brief.md not there yet) is denied until precedents.json beside it is
# there and shared/records/precedents-check.sh <record dir> passes (the schema's shape, every row the gatherer prints
# placed exactly once and nothing invented; {"none": "<reason>"} only on a project with no close report): the
# brief-grilling step 0 sweep comes first. The deny carries the check's first fault lines. A
# brief already written (a rung briefed before the sweep existed) is edited as before. A lead path is read
# with /./, // and /../ folded first, so another spelling of a brief is the brief. precedents.md is not used.
# Scratchpad and /tmp paths never match. Solo: exit 0.
# Then, for an IC, the content: a committed doc (*/specs/, */plans/, */adr/,
# */analysis/ *.md, not under ~/.fleet-agent-mgmt or ~/.claude) is public, read by
# the team on GitHub. The text the write leaves (Write: content; Edit: the file
# with old_string -> new_string applied, replace_all honoured; MultiEdit: each
# edit in order) is denied when leak_check.py finds a leak-list pattern, or, for a
# spec, a render fault. Both gates can deny; the reasons are joined.
# SPEC SHAPE, ic, */specs/*.md: the text the write leaves must freeze as written
# (shared/records/freeze-rules.sh --check -). When the path is the frozen spec of the IC's
# rung (the spec line of <record>/frozen.sha256), its rows must also match rules.md
# and gate.md (--check --record), screen one must read as it did at the STOP 1 commit, and
# ## Amendments must stay the last heading with only dated lines (shared/frozen.py spec).
# A rung in shared/records/legacy-records.txt or the settings home's legacy-records.txt is not checked.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "solo" ] && exit 0
p="$(j '.tool_input.file_path')"; [ -n "$p" ] || exit 0
RECORDS="${FLEET_RECORDS:-$FLEET_HOME/records}"
deny(){ jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
real(){ python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s\n' "$1"; }
shopt -s nocasematch   # DECISION-RECORD.md and decision-record.md are one file on macOS
rp="$p"; RR="$RECORDS"
case "${p##*/}" in
  rules.md|gate.md|frozen.sha256|stop1.log|*-pre-*.md|decision-record.md|evidence.md|close.md|*-jev-*.json|handoff.md|ic-sessions.log) rp="$(real "$p")"; RR="$(real "$RECORDS")" ;;
  *) [ -L "$p" ] && { rp="$(real "$p")"; RR="$(real "$RECORDS")"; } ;;
esac
if [ "$ROLE" = "ic" ]; then
  lp="$(real "$p")"
  case "$p//$lp" in
    */.claude/projects/*.jsonl|*/.claude/projects/*.JSONL)
      deny "SESSION LOGS: $p is under ~/.claude/projects/, Claude Code's session logs. The freeze reads the owner's spec ok there, so an IC never writes one. If the freeze cannot find the owner's word, hold and ask the owner to type it in this pane or lead-1's." ;;
  esac
  case "$rp" in
    */.fleet-agent-mgmt/records/*/*/*|"$FLEET_HOME"/records/*/*/*|"$RECORDS"/*/*/*|"$RR"/*/*/*)
      case "${rp##*/}" in
        *-jev-*.json)
          case "${rp%/*}" in */receipts)
            deny "RECEIPTS: $p is a Jev receipt. Only the Jev check writes one (the dr-check hook, shared/records/record-add.sh, shared/hooks/dr_check.py); the audit reads it as the proof of a jev line. An IC never writes or edits one." ;;
          esac ;;
        rules.md|gate.md|frozen.sha256|stop1.log|*-pre-*.md)
          case "${rp%/*}" in */receipts) ;; *)
            deny "FROZEN: $p is frozen. The freeze writes rules.md, gate.md and frozen.sha256 on \"spec ok\", the message gate writes stop1.log when STOP 1 passes, and gate-run, the dr-check hook, the STOP gate and the push refuse once a file no longer matches frozen.sha256. An IC never writes them, nor a *-pre-*.md copy. A rule or a gate line that must change is a card to lead-1 (decision-card.md); lead-1 amends the file and re-hashes it with shared/amend-frozen.sh." ;;
          esac ;;
        handoff.md|ic-sessions.log)
          case "${rp%/*}" in */receipts) ;; *)
            deny "HANDOFF: $p is lead-1's handoff or the hooks' ic-sessions.log. An IC never writes either: the handoff holds the CHAIN and, for a chore, the Checks lead-1 froze, and ic-sessions.log is how the chore freeze knows an IC has worked on the record. A step or a check that must change is a card to lead-1 (decision-card.md)." ;;
          esac ;;
        decision-record.md|evidence.md)
          case "${rp%/*}" in */receipts) ;; *)
            why="$(printf '%s' "$IN" | python3 "$(dirname "$0")/../records/record_add.py" --guard 2>/dev/null)"
            [ -n "$why" ] && deny "$why" ;;
          esac ;;
      esac ;;
  esac
fi
case "$rp" in /tmp/*|/private/tmp/*) exit 0 ;; esac
case "$p" in *.md|*/precedents.json) ;; *) exit 0 ;; esac
need=""
if [ "$ROLE" = "ic" ]; then
  case "$rp" in
    */analysis/*) need=writing-an-analysis ;;
    */adr/*)      need=writing-an-adr ;;
    */specs/*)    need=writing-a-design-spec ;;
    *-close.md)   need=closing-a-rung ;;
    */.fleet-agent-mgmt/records/*/decision-record.md|"$FLEET_HOME"/records/*/decision-record.md) need=recording-a-decision ;;
    */.fleet-agent-mgmt/records/*/evidence.md|"$FLEET_HOME"/records/*/evidence.md)               need=recording-evidence ;;
    */.fleet-agent-mgmt/records/*/close.md|"$FLEET_HOME"/records/*/close.md)                     need=closing-a-rung ;;
    "$RR"/*/decision-record.md) need=recording-a-decision ;;
    "$RR"/*/evidence.md)        need=recording-evidence ;;
  esac
else
  np="$p"   # /./, // and /../ folded, so records//<p>/<r>/./brief.md is the brief
  case "$p" in *//*|*/./*|*/../*|*/.|*/..) np="$(python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "$p" 2>/dev/null || printf '%s\n' "$p")" ;; esac
  case "$np" in
    */Leads/lead-1/handoffs/*-session-handoff.md) need=drafting-handoff ;;
    */.fleet-agent-mgmt/records/*/handoff.md|"$FLEET_HOME"/records/*/handoff.md) need=writing-a-rung-handoff ;;
    */.fleet-agent-mgmt/records/*/brief.md|"$FLEET_HOME"/records/*/brief.md)     need=brief-grilling ;;
    */.fleet-agent-mgmt/records/*/*/precedents.json|"$FLEET_HOME"/records/*/*/precedents.json) need=sweeping-precedents ;;
    */Leads/lead-1/handoffs/*|*/Leads/lead-1/briefs/*|*/Leads/lead-1/tickets/*) need=moved ;;
  esac
fi
shopt -u nocasematch
if [ "$need" = "moved" ]; then
  reason="MOVED: $p is history. A rung's brief, ticket and handoff are project data and live in its record folder, ~/.fleet-agent-mgmt/records/<project>/<lane>-r<n>/ (brief.md, ticket.md, handoff.md); only session handoffs stay under Leads/lead-1/handoffs/."
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi
reason=""
if [ -n "$need" ] && ! has "$need"; then
  reason="SKILL GATE: $p is written with the $need skill, $(why "$need"). Invoke it now with the Skill tool ($SKILLS_ROOT/$need/SKILL.md), follow its steps, then write the file."
fi
# A rung brief waits for the precedents sweep: its record folder holds precedents.json, and
# shared/records/precedents-check.sh <record dir> passes on it. Only the first write: a brief already there was
# written before the sweep existed, or after it passed.
if [ "$need" = brief-grilling ]; then
  shopt -s nocasematch
  if { [[ "$np" =~ /\.fleet-agent-mgmt/records/[^/]+/[^/]+/brief\.md$ ]] || [[ "$np" =~ ^"$FLEET_HOME"/records/[^/]+/[^/]+/brief\.md$ ]]; } && [ ! -e "$np" ]; then
    rd="${np%/*}"; pf="$rd/precedents.json"; miss=""
    if [ ! -f "$pf" ]; then miss="there is no $pf. "
    else
      faults="$("$(dirname "$0")/../records/precedents-check.sh" "$rd" 2>&1)" \
        || miss="shared/records/precedents-check.sh $rd fails:
$(printf '%s\n' "$faults" | head -5 | sed 's/^/  /')
"
    fi
    [ -n "$miss" ] && reason="${reason:+$reason }PRECEDENTS: $p is a rung brief, written only after the precedents sweep, and ${miss}Invoke the sweeping-precedents skill ($SKILLS_ROOT/sweeping-precedents/SKILL.md): shared/records/precedents-gather.sh <project> pasted into the haiku sweep prompt, its JSON reply saved as $pf (or {\"none\": \"<reason>\"} on a project with no close report), the lead's pick, until shared/records/precedents-check.sh $rd passes. Then write the brief."
  fi
  shopt -u nocasematch
fi
# The text this write leaves in the file, for the content check.
post_text(){ printf '%s' "$IN" | python3 -c '
import json, sys
h = json.load(sys.stdin)
t, i = h.get("tool_name") or "", h.get("tool_input") or {}
if t not in ("Edit", "MultiEdit"):
    sys.stdout.write(i.get("content") or ""); sys.exit(0)
edits = (i.get("edits") or []) if t == "MultiEdit" else [i]
try:
    text = open(i.get("file_path") or "", encoding="utf-8", errors="replace").read()
except OSError:
    text = ""
for e in edits:
    old, new = e.get("old_string") or "", e.get("new_string") or ""
    if old and old in text:
        text = text.replace(old, new) if e.get("replace_all") else text.replace(old, new, 1)
    else:
        text += ("\n" if text else "") + new
sys.stdout.write(text)
' 2>/dev/null; }
# The spec's shape: what the freeze reads, checked at every write, not first at "spec ok".
spec_shape(){
  local mine rec fspec args shape n
  mine="$(grep -ls "· $NAME\$" "$RECORDS"/*/*/decision-record.md 2>/dev/null | tr '\n' '\0' | xargs -0 ls -t 2>/dev/null | head -1)"
  rec="${mine:+$(dirname "$mine")}"
  args=(--check - --path "$p")
  if [ -n "$rec" ]; then
    python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; sys.exit(0 if f.legacy(sys.argv[2]) else 1)' "$(dirname "$0")/../records" "$rec" 2>/dev/null && return 0   # either legacy listing
    fspec="$(sed -n 's/^spec  *//p' "$rec/frozen.sha256" 2>/dev/null | head -1)"
    [ -n "$fspec" ] && [ "${p%"/$fspec"}" != "$p" ] && args+=(--record "$rec")
  fi
  local rc=0 more=""
  shape="$(post_text | python3 "$(dirname "$0")/../records/freeze_rules.py" "${args[@]}" 2>/dev/null)" || rc=1
  if [ "${args[*]}" != "${args[*]%--record*}" ]; then
    more="$(post_text | python3 "$(dirname "$0")/../frozen.py" spec "$rec" --repo "${cwd:-.}" 2>/dev/null)" || rc=1
    shape="$(printf '%s\n%s\n' "$shape" "$more" | awk 'NF && !seen[$0]++')"   # a row reason both name, once
  fi
  [ "$rc" = 0 ] && return 0
  n="$(printf '%s\n' "$shape" | grep -c .)"
  reason="${reason:+$reason }SPEC SHAPE: $p would not freeze as written, or no longer matches the rung's frozen rules (shared/records/freeze-rules.sh --check). $n reasons:
$(printf '%s\n' "$shape" | head -20)
Screen one holds ## Terms, ## One-way, ## Decided, ## Rejected and ## Checks, each heading exactly so with one table under it (writing-a-design-spec, templates/design-spec.md). After the freeze a rule or a Checks row changes only through a card to lead-1, and a new fact is a dated line under ## Amendments, the last heading. Then write the file again."
}
if [ "$ROLE" = "ic" ]; then
  case "$p" in
    "$HOME"/.claude/*|"$HOME"/.fleet-agent-mgmt/*|"$FLEET_HOME"/*|*/.fleet-agent-mgmt/*) ;;
    */specs/*.md|*/plans/*.md|*/adr/*.md|*/analysis/*.md)
      hits="$(post_text | python3 "$(dirname "$0")/leak_check.py" --doc - --path "$p" 2>/dev/null)"
      if [ -n "$hits" ]; then
        n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
        hits="$(printf '%s\n' "$hits" | head -30)"; hits="${hits//"$p:"/line }"
        [ "$n" -gt 30 ] && hits="$hits
... and $((n-30)) more"
        reason="${reason:+$reason }LEAK GATE: $p is a committed doc: the team reads it on GitHub and it never names the fleet or its process. $n hits (line n: pattern: text):
$hits
Rewrite each hit: cite the Jira ticket, a repo file and line, an incident or a PR instead of a local path, a record file or a fleet id; name people by their role in the team; drop STOP, screen one, spec ok and the style:, source:, record: and Reply: lines (they go in the STOP report). A spec also needs a blank line above every --- and every \`\`\` fence closed. Then write the file again."
      fi
      case "$p" in */specs/*.md) spec_shape ;; esac
      ;;
  esac
fi
[ -n "$reason" ] || exit 0
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
