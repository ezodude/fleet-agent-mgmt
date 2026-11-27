#!/bin/bash
# Tests for shared/records/pr-watch.sh, with a gh stub on PATH that serves canned JSON per endpoint
# from files in a temporary folder. Never calls the network. Prints "N pass, M fail"; exit 1 on any fail.
set -u
W="$(cd "$(dirname "$0")/../records" && pwd)/pr-watch.sh"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/gh"; export PATH="$T/bin:$PATH" STUB="$T/gh"
# the stub: every call is logged; a `fail` file makes every call exit 1; a write form is refused loudly
cat > "$T/bin/gh" <<'S'
#!/bin/bash
echo "$*" >> "$STUB/calls.log"
[ -e "$STUB/fail" ] && { echo "gh: HTTP 502" >&2; exit 1; }
case "$*" in
  *" -X "*|*" -f "*|*" -F "*|*--method*|*--field*|*--input*) echo "gh stub: a write form" >&2; exit 9 ;;
  "repo view "*) echo "acme/atlas" ;;
  "api --paginate repos/acme/atlas/pulls/88/comments") cat "$STUB/review.json" ;;
  "api --paginate repos/acme/atlas/issues/88/comments") cat "$STUB/issue.json" ;;
  "api --paginate repos/acme/atlas/pulls/88/reviews") cat "$STUB/reviews.json" ;;
  "pr view 88 "*) cat "$STUB/state.json" ;;
  *) echo "gh stub: unexpected: $*" >&2; exit 9 ;;
esac
S
chmod +x "$T/bin/gh"
P=0; F=0; ok() { if eval "$2"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $1"; fi; }
SEEN="$T/seen"
LONG="$(printf 'x%.0s' $(seq 1 200))"
cat > "$T/gh/review.json" <<EOF
[{"id":2101,"user":{"login":"robin"},"path":"atlas/retry.py","line":41,"original_line":41,
  "body":"The cap is a literal here.\r\nShould it come from config?\n\nSee settings.py.","html_url":"https://example.test/acme/atlas/pull/88#discussion_r2101"},
 {"id":2103,"user":{"login":"sam"},"path":"atlas/scheduler.py","line":null,"original_line":12,
  "body":"$LONG","html_url":"https://example.test/acme/atlas/pull/88#discussion_r2103"}]
EOF
cat > "$T/gh/issue.json" <<'EOF'
[{"id":3001,"user":{"login":"robin"},"body":"Does this change the CLI import too?","html_url":"https://example.test/acme/atlas/pull/88#issuecomment-3001"}]
EOF
cat > "$T/gh/reviews.json" <<'EOF'
[{"id":4001,"user":{"login":"sam"},"state":"COMMENTED","body":"","html_url":"https://example.test/acme/atlas/pull/88#pullrequestreview-4001"},
 {"id":4002,"user":{"login":"sam"},"state":"CHANGES_REQUESTED","body":"Two things before this goes in.","html_url":"https://example.test/acme/atlas/pull/88#pullrequestreview-4002"}]
EOF
echo '{"state":"OPEN","mergedAt":null,"mergeCommit":null}' > "$T/gh/state.json"

out="$("$W" 88 --seen "$SEEN" --once)"; rc=$?
ok "first poll exits 0" '[ $rc -eq 0 ]'
ok "first poll prints one line per review comment, issue comment and non-empty summary" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" -eq 4 ]'
ok "a review comment line has the stated shape, newlines folded" '[ "$(printf "%s\n" "$out" | sed -n 1p)" = "comment review 2101 · robin · atlas/retry.py:41 · The cap is a literal here. Should it come from config? See settings.py. · https://example.test/acme/atlas/pull/88#discussion_r2101" ]'
ok "a comment on an outdated line reads its original line" 'printf "%s\n" "$out" | grep -q "^comment review 2103 · sam · atlas/scheduler.py:12 · "'
ok "a long body is cut at 160 characters" '[ "$(printf "%s\n" "$out" | sed -n 2p | awk -F" · " "{print length(\$4)}")" -eq 160 ]'
ok "an issue comment line has no path" '[ "$(printf "%s\n" "$out" | sed -n 3p)" = "comment issue 3001 · robin · - · Does this change the CLI import too? · https://example.test/acme/atlas/pull/88#issuecomment-3001" ]'
ok "a review summary with a body is printed" '[ "$(printf "%s\n" "$out" | sed -n 4p)" = "comment summary 4002 · sam · - · Two things before this goes in. · https://example.test/acme/atlas/pull/88#pullrequestreview-4002" ]'
ok "a review summary with an empty body is not printed" '! printf "%s\n" "$out" | grep -q 4001'
ok "the ids are written to the seen file" '[ "$(tr "\n" " " < "$SEEN")" = "2101 2103 3001 4002 " ]'
ok "the repo comes from gh repo view when --repo is absent" 'grep -q "^repo view --json nameWithOwner" "$T/gh/calls.log"'

out="$("$W" 88 --seen "$SEEN" --once)"; rc=$?
ok "a second poll with the same comments prints nothing, exit 0" '[ $rc -eq 0 ] && [ -z "$out" ]'

jq '. + [{"id":3002,"user":{"login":"sam"},"body":"One more.","html_url":"https://example.test/acme/atlas/pull/88#issuecomment-3002"}]' "$T/gh/issue.json" > "$T/gh/issue.new" && mv "$T/gh/issue.new" "$T/gh/issue.json"
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --once)"
ok "a new id prints only its line" '[ "$out" = "comment issue 3002 · sam · - · One more. · https://example.test/acme/atlas/pull/88#issuecomment-3002" ]'

jq '. + [{"id":3003,"user":{"login":"me"},"body":"Fixed in d4e5f6a.","html_url":"https://example.test/acme/atlas/pull/88#issuecomment-3003"}]' "$T/gh/issue.json" > "$T/gh/issue.new" && mv "$T/gh/issue.new" "$T/gh/issue.json"
"$W" 88 --seen "$SEEN" --mark 3003; rc=$?
out="$("$W" 88 --seen "$SEEN" --once)"
ok "--mark makes that id silent on the next poll" '[ $rc -eq 0 ] && [ -z "$out" ] && grep -qx 3003 "$SEEN"'
: > "$T/gh/calls.log"; "$W" 88 --repo acme/atlas --seen "$SEEN" --mark 3004 3005
ok "--mark takes several ids and calls gh for nothing" 'grep -qx 3005 "$SEEN" && [ ! -s "$T/gh/calls.log" ]'
"$W" 88 --seen "$SEEN" --mark 2>/dev/null; rc=$?
ok "--mark with no id is usage" '[ $rc -eq 2 ]'
"$W" eighty-eight --once 2>/dev/null; rc=$?
ok "a PR number that is not a number is usage" '[ $rc -eq 2 ]'

# the loop: silent polls go on, the first poll that prints ends it
: > "$T/gh/calls.log"
( sleep 2; jq '. + [{"id":3006,"user":{"login":"sam"},"body":"Late one.","html_url":"u"}]' "$T/gh/issue.json" > "$T/gh/issue.new" && mv "$T/gh/issue.new" "$T/gh/issue.json" ) &
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --interval 1)"; rc=$?; wait
ok "without --once it waits, then exits 0 on the first new batch" '[ $rc -eq 0 ] && [ "$out" = "comment issue 3006 · sam · - · Late one. · u" ] && [ "$(grep -c "^pr view" "$T/gh/calls.log")" -ge 2 ]'

echo '{"state":"MERGED","mergedAt":"2026-11-27T10:00:00Z","mergeCommit":{"oid":"d4e5f6a7b8c9"}}' > "$T/gh/state.json"
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --interval 1)"; rc=$?
ok "a merged pull request prints state merged and its sha, exit 0" '[ $rc -eq 0 ] && [ "$out" = "state merged d4e5f6a7b8c9" ]'
echo '{"state":"CLOSED","mergedAt":null,"mergeCommit":null}' > "$T/gh/state.json"
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --interval 1)"; rc=$?
ok "a closed pull request prints state closed, exit 0" '[ $rc -eq 0 ] && [ "$out" = "state closed" ]'
echo '{"state":"OPEN","mergedAt":null,"mergeCommit":null}' > "$T/gh/state.json"

touch "$T/gh/fail"; : > "$T/gh/calls.log"
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --interval 0 2>"$T/err")"; rc=$?
ok "gh failing 5 polls in a row prints the watch error once and exits 1" '[ $rc -eq 1 ] && [ "$out" = "watch error: gh failed 5 times" ] && [ "$(wc -l < "$T/gh/calls.log" | tr -d " ")" -eq 5 ]'
ok "each gh failure goes to stderr" '[ "$(grep -c "HTTP 502" "$T/err")" -eq 5 ]'
out="$("$W" 88 --repo acme/atlas --seen "$SEEN" --once 2>/dev/null)"; rc=$?
ok "--once on a failed poll exits 1 and prints nothing" '[ $rc -eq 1 ] && [ -z "$out" ]'
rm "$T/gh/fail"

ok "the stub was never asked for a write form" '! grep -q -e " -X " -e " -f " -e " -F " -e "--input" "$T/gh/calls.log"'
ok "the script holds no gh write form" '[ "$(grep -c -e "pr comment" -e "-X POST" -e "-f body" "$W")" -eq 0 ]'
ok "every gh call in the script is api --paginate, pr view or repo view" '[ "$(grep -o "(gh [a-z]* [a-z-]*" "$W" | sort -u | tr "\n" ";")" = "(gh api --paginate;(gh pr view;(gh repo view;" ]'

echo "$P pass, $F fail"; [ "$F" -eq 0 ]
