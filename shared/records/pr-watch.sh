#!/bin/bash
# Watch one pull request for new review comments, for the IC whose rung opened it.
#   shared/records/pr-watch.sh <pr number> [--repo <owner/repo>] [--interval <seconds>] [--seen <file>] [--once]
#   shared/records/pr-watch.sh <pr number> [--repo <owner/repo>] [--seen <file>] --mark <id>...
# Run from the IC's worktree as a background Bash command, right after the draft
# pull request opens (foundations/pr-comments.md). It polls GitHub every
# <interval> seconds (default 60) and exits 0 after the first poll that printed
# something, so the IC's session is told once per batch; the IC handles the batch
# and starts it again. Read-only: every gh call here is a GET.
# Each poll reads three lists and the pull request's state:
#   repos/<o>/<r>/pulls/<n>/comments    comments on a line of the diff   review
#   repos/<o>/<r>/issues/<n>/comments   comments on the conversation     issue
#   repos/<o>/<r>/pulls/<n>/reviews     review summaries with a body     summary
# and prints one line per id that is not in the seen file, then appends the id:
#   comment <review|issue|summary> <id> · <author> · <path>:<line or -> · <first 160 chars, newlines folded> · <html url>
# (`-` in place of <path>:<line> for a comment on no line.) When the pull request
# is merged or closed it prints `state merged <sha>` or `state closed` and exits 0.
#   --once      one poll, then exit 0 even when nothing was new (tests, a first look)
#   --mark      append the ids to the seen file and exit: the IC's own replies,
#               so the next poll does not hand them back
#   --seen      the seen file, default ${TMPDIR:-/tmp}/pr-watch-<owner>-<repo>-<n>.seen
#   --repo      default: the repo of the cwd (gh repo view)
# A failed gh call goes to stderr and the loop goes on; after 5 failed polls in a
# row it prints `watch error: gh failed 5 times` on stdout and exits 1: silence
# is never read as "no comments". With --once a failed poll exits 1.
set -u
usage(){ echo "usage: pr-watch.sh <pr number> [--repo <owner/repo>] [--interval <seconds>] [--seen <file>] [--once] | <pr number> --mark <id>..." >&2; exit 2; }
n="${1:-}"; [[ "$n" =~ ^[0-9]+$ ]] || usage; shift
repo=""; interval=60; seen=""; once=0; mark=0; ids=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 || usage ;;
    --interval) interval="${2:-}"; shift 2 || usage ;;
    --seen) seen="${2:-}"; shift 2 || usage ;;
    --once) once=1; shift ;;
    --mark) mark=1; shift; while [ $# -gt 0 ] && [[ "$1" != --* ]]; do ids+=("$1"); shift; done ;;
    *) usage ;;
  esac
done
[[ "$interval" =~ ^[0-9]+$ ]] || usage
if [ -z "$repo" ] && { [ -z "$seen" ] || [ "$mark" = 0 ]; }; then
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" ||
    { echo "pr-watch: no repo: run from the worktree or pass --repo <owner/repo>" >&2; exit 2; }
fi
[ -n "$seen" ] || seen="${TMPDIR:-/tmp}/pr-watch-${repo//\//-}-$n.seen"
seen="${seen/#\~/$HOME}"
if [ "$mark" = 1 ]; then
  [ "${#ids[@]}" -gt 0 ] || usage
  for i in "${ids[@]}"; do [[ "$i" =~ ^[0-9]+$ ]] || usage; done
  printf '%s\n' "${ids[@]}" >> "$seen"
  exit 0
fi
[[ "$repo" == */* ]] || usage
touch "$seen" || exit 2

# one line per item: <id> TAB <the line to print>; newlines and tabs in a body fold to one space
FOLD='gsub("[\r\n\t]+"; " ") | .[0:160]'
list(){  # $1 endpoint, $2 jq program over one page (an array)
  local out
  out="$(gh api --paginate "repos/$repo/$1")" || return 1
  printf '%s' "$out" | jq -r "$2" || return 1
}
poll(){  # prints the new lines; 0 printed nothing, 10 printed something, 11 merged or closed, 1 a gh call failed
  local rows more st printed=0 id line
  rows="$(list "pulls/$n/comments" '.[] | "\(.id)\tcomment review \(.id) · \(.user.login) · \(.path // "-"):\(.line // .original_line // "-") · \((.body // "") | '"$FOLD"') · \(.html_url)"')" || return 1
  more="$(list "issues/$n/comments" '.[] | "\(.id)\tcomment issue \(.id) · \(.user.login) · - · \((.body // "") | '"$FOLD"') · \(.html_url)"')" || return 1
  rows="$rows"$'\n'"$more"
  more="$(list "pulls/$n/reviews" '.[] | select((.body // "") != "") | "\(.id)\tcomment summary \(.id) · \(.user.login) · - · \(.body | '"$FOLD"') · \(.html_url)"')" || return 1
  rows="$rows"$'\n'"$more"
  st="$(gh pr view "$n" --repo "$repo" --json state,mergedAt,mergeCommit)" || return 1
  while IFS=$'\t' read -r id line; do
    [ -n "$id" ] || continue
    grep -qxF -- "$id" "$seen" && continue
    printf '%s\n' "$line"; printf '%s\n' "$id" >> "$seen"; printed=1
  done <<< "$rows"
  case "$(printf '%s' "$st" | jq -r '.state // ""')" in
    MERGED) printf 'state merged %s\n' "$(printf '%s' "$st" | jq -r '.mergeCommit.oid // "-"')"; return 11 ;;
    CLOSED) echo "state closed"; return 11 ;;
  esac
  [ "$printed" = 1 ] && return 10
  return 0
}
fails=0
while :; do
  poll; rc=$?
  case "$rc" in
    10|11) exit 0 ;;
    0) fails=0 ;;
    *) fails=$((fails+1))
       [ "$once" = 1 ] && exit 1
       if [ "$fails" -ge 5 ]; then echo "watch error: gh failed 5 times"; exit 1; fi ;;
  esac
  [ "$once" = 1 ] && exit 0
  sleep "$interval"
done
