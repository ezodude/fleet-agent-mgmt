#!/bin/bash
# Idempotent agent launcher. `agent-up.sh <name>` starts the named agent in a
# detached tmux session if it isn't already running; `agent-up.sh --all` does
# the same for every roster row. Safe to run any time, by anyone (human, Lead,
# or Tech Lead). The roster's fenced `fleet` block is the single source.
# Row format: name TAB directory [TAB extra-claude-flags]. Model policy:
# lead-1 and ICs both run
# claude-opus-5-5, the lead at high effort and ICs at medium, no advisor. The
# model and effort live in the --settings file for each role, never on the
# launch line, so there is one place to read and one to change; the ICs'
# earlier advisor (claude-fable-5-1) was dropped because Opus 5.5 is
# positioned at Fable level on most work. The IC pin rides on the launch
# line as --settings shared/launch/ic-settings.json (FLEET_REPO and FLEET_HOME
# are exported on the same line; the roster is read from $FLEET_HOME/roster.md); no repo file, no .claude/settings.json symlink, so a
# repo that tracks .claude/settings.json is
# never clobbered and never clobbers the pin.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/paths.sh"
ROSTER="$FLEET_HOME/roster.md"
IC_SETTINGS="$FLEET_REPO/shared/launch/ic-settings.json"
LEAD_SETTINGS="$FLEET_REPO/shared/launch/lead-settings.json"
NAME="${1:?usage: agent-up.sh <name>|--all [--resume | --resume-id <id>] [--no-advisor] [--model <id>]}"
# --resume: continue the agent's most recent conversation instead of starting
# a fresh one; the transcript is kept and the hooks and settings on the launch
# line load fresh. Used to pick up hooks added after a session started.
# Resumes by session id (`claude -r <id>`, the newest
# transcript in the agent's project dir) because `claude -c` refuses a
# transcript whose last record is a deferred-tool marker, which is what a
# session killed mid-tool leaves behind (dbx-ic-1, 2026-09-15 14:10).
# --no-advisor: launch with the advisor off for the duration of an advisor
# model outage, whatever advisorModel the settings file names; the main model
# is unchanged. Works by exporting CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1 on the
# launch line, which makes any configured advisorModel ignored (added
# during Fable uptime issues; kept when the advisor was dropped, in the
# owner's words "not a feature to lose").
# --model <id>: run this launch on <id> instead of the model in the role's
# settings file; a launch-line --model outranks any settings file for that
# session only, so the file stays the policy and this is the override
# ("handy for overriding the lead-settings or ic-settings.json", the
# owner's words).
# --resume-id <id>: like --resume, for this session id (`claude -r <id>`); the
# launch receipt's second line shows it. Used to bring the lead up in its new
# folder after the cut-over with the settings, name and plugin on the line.
RESUME=""; RESUME_ID=""; NOADV=""; MODEL=""
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) RESUME=1 ;;
    --resume-id) RESUME_ID="${2:?--resume-id needs a session id}"; RESUME=1; shift
      case "$RESUME_ID" in *[!A-Za-z0-9_-]*) echo "bad session id: $RESUME_ID"; exit 1 ;; esac ;;
    --no-advisor) NOADV="CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1 " ;;
    --model) MODEL="${2:?--model needs a model id}"; shift ;;
    *) echo "unknown flag: $1"; exit 1 ;;
  esac
  shift
done

[ -f "$ROSTER" ] || { echo "no roster at $ROSTER: copy $FLEET_REPO/shared/launch/roster.example.md there and edit it"; exit 1; }
command -v tmux >/dev/null || { echo "tmux not found (brew install tmux)"; exit 1; }
command -v claude >/dev/null || { echo "claude not found on PATH"; exit 1; }

rows() { awk '/^```fleet/{f=1;next} /^```/{f=0} f && NF>=2' "$ROSTER"; }

# Newest transcript in the agent's project dir, as a session id. Claude Code
# keys the dir by the cwd with every non-alphanumeric character turned into
# `-`; subagent transcripts (agent-*.jsonl) are not sessions.
# Newest transcript in the agent's project dir that was launched under this
# agent's name: `claude -n <name>` writes a {"type":"custom-title",
# "customTitle":"<name>"} record. Newest-by-mtime alone is wrong: the dir
# also holds one-line ai-title stubs and any stray `claude -p` run from the
# same cwd, both newer than the real transcript (lead-1, 2026-09-23 11:12,
# "No conversation found with session ID"). Falls back to newest non-stub.
latest_session() {
  local key f; key="$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"
  for f in $(ls -t "$HOME/.claude/projects/$key"/*.jsonl 2>/dev/null | grep -v '/agent-'); do
    if /usr/bin/grep -a -q -m1 "\"customTitle\":\"$2\"" "$f"; then basename "$f" .jsonl; return; fi
  done
  for f in $(ls -t "$HOME/.claude/projects/$key"/*.jsonl 2>/dev/null | grep -v '/agent-'); do
    [ "$(stat -f %z "$f")" -gt 4096 ] && { basename "$f" .jsonl; return; }
  done
}

launch() {
  local n="$1" dir="$2" extra="${3:-}" model_flags resume_flags="" verb="launched"
  local settings; if [ "$n" = "lead-1" ]; then settings="$LEAD_SETTINGS"; else settings="$IC_SETTINGS"; fi
  model_flags="--settings $(printf '%q' "$settings")"
  # A resumed session keeps the model saved in its transcript and ignores the
  # settings file's `model`; only a launch-line --model outranks it (Claude
  # Code model-config docs, fetched 2026-09-23). So on --resume the file's
  # model goes on the launch line too, and the file stays the single policy
  # (the owner's ruling). An explicit --model still wins.
  if [ -n "$MODEL" ]; then
    model_flags="$model_flags --model $MODEL"; verb="$verb on $MODEL"
  elif [ -n "$RESUME" ]; then
    local m; m="$(jq -r '.model // empty' "$settings")"
    [ -z "$m" ] || model_flags="$model_flags --model $m"
  fi
  [ -d "$dir" ] || { echo "$n: directory missing: $dir"; return 1; }
  if tmux has-session -t "=$n" 2>/dev/null; then
    echo "$n: already running"
    return 0
  fi
  if [ -n "$RESUME" ]; then
    local id; if [ -n "$RESUME_ID" ]; then id="$RESUME_ID"; else id="$(latest_session "$dir" "$n")"; fi
    if [ -n "$id" ]; then resume_flags="-r $id"; verb="resumed $id"
    else resume_flags="-c"; verb="resumed (no transcript found, using -c)"; fi
  fi
  [ -z "$NOADV" ] || verb="$verb, no advisor"
  local cmd="${NOADV}FLEET_REPO=$(printf '%q' "$FLEET_REPO") FLEET_HOME=$(printf '%q' "$FLEET_HOME") claude $resume_flags -n $n --permission-mode auto $model_flags $extra"
  # launch receipt: line 1 UTC time (state-gate.log format), line 2 the exact command; read by check-cutover.sh
  mkdir -p "$FLEET_HOME/checks/$n" && printf '%s\n%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$cmd" > "$FLEET_HOME/checks/$n/launch"
  tmux new-session -d -s "$n" -c "$dir" "$cmd"
  echo "$n: $verb (attach: tmux attach -t $n)"
}

if [ "$NAME" = "--all" ]; then
  [ -z "$RESUME_ID" ] || { echo "--resume-id names one agent, not --all"; exit 1; }
  rc=0
  while IFS=$'\t' read -r n d x; do launch "$n" "$d" "$x" || rc=1; done < <(rows)
  exit "$rc"
fi

ROW="$(rows | awk -F'\t' -v n="$NAME" '$1==n {print; exit}')"
[ -n "$ROW" ] || { echo "unknown agent: $NAME (not in $ROSTER)"; exit 1; }
DIR="$(printf '%s' "$ROW" | cut -f2)"
EXTRA="$(printf '%s' "$ROW" | cut -f3- -s)"
[ "$EXTRA" = "$DIR" ] && EXTRA=""
launch "$NAME" "$DIR" "$EXTRA"
