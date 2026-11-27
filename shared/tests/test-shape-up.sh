#!/bin/bash
# Tests for shape-up.sh and agent-up.sh (fleet rows and reviewer rows), with tmux and claude stubbed on PATH and a temporary
# fleet home. Prints "N pass, M fail"; exit 1 on any fail.
set -u
HERE="$(cd "$(dirname "$0")/../launch" && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"; export FLEET_HOME="$T/home" PATH="$T/bin:$PATH" LOG="$T/tmux.log"
cat > "$T/bin/tmux" <<'S'
#!/bin/bash
echo "$*" >> "$LOG"
[ "$1" = has-session ] && { [ -e "$LOG.running.${3#=}" ]; exit; }
[ "$1" = new-session ] && touch "$LOG.running.$4"
exit 0
S
printf '#!/bin/bash\nexit 0\n' > "$T/bin/claude"; chmod +x "$T/bin/tmux" "$T/bin/claude"
P=0; F=0; ok() { if eval "$2"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $1"; fi; }
SU="$HERE/shape-up.sh"; D="$FLEET_HOME/shaping"

out="$("$SU" 'Bad Idea' 2>&1)"; rc=$?
ok "bad idea name is usage" '[ $rc -eq 2 ] && [[ "$out" == usage:* ]]'
out="$("$SU" alpha)"; rc=$?
ok "launch exit 0" '[ $rc -eq 0 ]'
ok "folder and map copied" 'cmp -s "$HERE/shaping/session-map.md" "$D/alpha/CLAUDE.md"'
ok "detached session, first line boot" 'grep -q -- "new-session -d -s shape-alpha -c $D/alpha FLEET_REPO=.* FLEET_HOME=.* claude -n shape-alpha .*shape-settings.json boot" "$LOG"'
ok "prints the attach line" '[[ "$out" == *"tmux attach -t shape-alpha"* ]]'
ok "never attaches" '! grep -q -E "^(attach|switch-client)" "$LOG"'
out="$("$SU" alpha)"
ok "second launch is idempotent" '[[ "$out" == *"already running"* ]] && [ "$(grep -c new-session "$LOG")" -eq 1 ]'
out="$("$SU" beta)"
ok "lists existing shaping folders" '[[ "$out" == *"already there:"*alpha* ]]'
out="$("$SU" --done alpha)"; rc=$?
ok "done while running keeps folder" '[ $rc -eq 1 ] && [ -d "$D/alpha" ] && [[ "$out" == *"still running; kill it first"* ]]'
rm -f "$LOG.running.shape-alpha"
out="$("$SU" --done alpha)"; rc=$?
ok "done with no stamp deletes folder, prints it" '[ $rc -eq 0 ] && [ ! -e "$D/alpha" ] && [ -d "$D/beta" ] && [[ "$out" == *"deleted $D/alpha"* ]] && [[ "$out" == *"  CLAUDE.md"* ]]'
echo 'beta brief ok · 15:20Z' > "$D/beta/brief.md"; rm -f "$LOG.running.shape-beta"
out="$("$SU" --done beta)"; rc=$?
ok "done with stamp deletes folder" '[ $rc -eq 0 ] && [ ! -e "$D/beta" ] && [[ "$out" == *"  brief.md"* ]]'
out="$("$SU" --done gamma)"; rc=$?
ok "done on a missing folder fails" '[ $rc -eq 1 ]'
# agent-up.sh: roster from FLEET_HOME, launch line, settings hooks
REPO="$(cd "$HERE/../.." && pwd)"; AU="$HERE/agent-up.sh"; mkdir -p "$T/atlas"; : > "$LOG"
out="$("$AU" atlas-ic-1 2>&1)"; rc=$?
ok "no_roster_exit_1_names_example" '[ $rc -eq 1 ] && [[ "$out" == *roster.example.md* ]] && ! grep -q new-session "$LOG"'
printf '```fleet\natlas-ic-1\t%s\n```\n' "$T/atlas" > "$FLEET_HOME/roster.md"
out="$("$AU" atlas-ic-1 2>&1)"; rc=$?
ok "roster_from_home" '[ $rc -eq 0 ] && [[ "$out" == "atlas-ic-1: launched"* ]] && grep -q "new-session -d -s atlas-ic-1 -c $T/atlas" "$LOG"'
ok "launch_receipt_written" '[ "$(sed -n 1p "$FLEET_HOME/checks/atlas-ic-1/launch")" ] && sed -n 1p "$FLEET_HOME/checks/atlas-ic-1/launch" | grep -Eq "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$" && [ "$(sed -n 2p "$FLEET_HOME/checks/atlas-ic-1/launch")" = "$(grep "new-session -d -s atlas-ic-1" "$LOG" | sed "s/^new-session -d -s atlas-ic-1 -c [^ ]* //")" ]'
ok "launch_line_exports_both" 'grep "new-session -d -s atlas-ic-1" "$LOG" | grep -q "FLEET_REPO=$REPO FLEET_HOME=$FLEET_HOME claude .*--settings $REPO/shared/launch/ic-settings.json"'
: > "$LOG"; rm -f "$LOG".running.atlas-ic-1
out="$("$AU" atlas-ic-1 --resume-id 0a1b2c3d-4e5f 2>&1)"; rc=$?
ok "resume_id_on_launch_line" '[ $rc -eq 0 ] && [[ "$out" == "atlas-ic-1: resumed 0a1b2c3d-4e5f"* ]] && grep "new-session -d -s atlas-ic-1" "$LOG" | grep -q "claude -r 0a1b2c3d-4e5f -n atlas-ic-1 "'
ok "resume_id_in_receipt_line_2" 'sed -n 2p "$FLEET_HOME/checks/atlas-ic-1/launch" | grep -q "claude -r 0a1b2c3d-4e5f -n atlas-ic-1 "'
out="$("$AU" atlas-ic-1 --resume-id 'x;y' 2>&1)"; rc=$?
ok "resume_id_rejects_odd_chars" '[ $rc -eq 1 ] && [[ "$out" == "bad session id"* ]]'
out="$("$AU" --all --resume-id abc 2>&1)"; rc=$?
ok "resume_id_not_with_all" '[ $rc -eq 1 ] && [[ "$out" == *"names one agent"* ]]'
# reviewers: a second roster block, launched by name on reviewer-settings.json, never by --all, solo to every hook
mkdir -p "$T/atlas-review" "$T/both"; : > "$LOG"; rm -f "$LOG".running.*
printf '```fleet\natlas-ic-1\t%s\n```\n\n```reviewers\natlas-reviewer\t%s\n```\n' "$T/atlas" "$T/atlas-review" > "$FLEET_HOME/roster.md"
out="$("$AU" atlas-reviewer 2>&1)"; rc=$?
ok "reviewer_launch_uses_reviewer_settings" '[ $rc -eq 0 ] && [[ "$out" == "atlas-reviewer: launched"* ]] && grep "new-session -d -s atlas-reviewer -c $T/atlas-review " "$LOG" | grep -q -- "claude  *-n atlas-reviewer .*--settings $REPO/shared/launch/reviewer-settings.json" && ! grep "new-session -d -s atlas-reviewer" "$LOG" | grep -q ic-settings.json'
ok "reviewer_launch_receipt_written" 'sed -n 2p "$FLEET_HOME/checks/atlas-reviewer/launch" | grep -q -- "--settings $REPO/shared/launch/reviewer-settings.json"'
out="$("$AU" atlas-reviewer 2>&1)"
ok "reviewer_second_launch_idempotent" '[[ "$out" == "atlas-reviewer: already running" ]] && [ "$(grep -c "new-session -d -s atlas-reviewer" "$LOG")" -eq 1 ]'
: > "$LOG"; rm -f "$LOG".running.*
out="$("$AU" --all 2>&1)"; rc=$?
ok "all_skips_reviewers" '[ $rc -eq 0 ] && grep -q "new-session -d -s atlas-ic-1" "$LOG" && ! grep -q "new-session -d -s atlas-reviewer" "$LOG" && [[ "$out" != *atlas-reviewer* ]]'
ok "ic_row_still_ic_settings" 'grep "new-session -d -s atlas-ic-1" "$LOG" | grep -q -- "--settings $REPO/shared/launch/ic-settings.json" && ! grep -q reviewer-settings.json "$LOG"'
out="$("$AU" orbit-reviewer 2>&1)"; rc=$?
ok "unknown_agent_in_neither_block" '[ $rc -eq 1 ] && [[ "$out" == "unknown agent: orbit-reviewer"* ]]'
printf '```fleet\natlas-ic-1\t%s\ntwice\t%s\n```\n\n```reviewers\ntwice\t%s\n```\n' "$T/atlas" "$T/both" "$T/both" > "$FLEET_HOME/roster.md"; : > "$LOG"
out="$("$AU" twice 2>&1)"; rc=$?
ok "name_in_both_blocks_refused" '[ $rc -eq 1 ] && [[ "$out" == "twice is in both the fleet block and the reviewers block"* ]] && ! grep -q new-session "$LOG"'
printf '```fleet\natlas-ic-1\t%s\n```\n\n```reviewers\natlas-reviewer\t%s\n```\n' "$T/atlas" "$T/atlas-review" > "$FLEET_HOME/roster.md"
role() { printf '{"cwd":"%s","session_id":"s1"}' "$1" | (unset FLEET_ROSTER STATE_CHECKS; . "$HERE/../hooks/skill-lib.sh"; echo "$ROLE:$NAME"); }
ok "reviewer_is_solo_for_hooks" '[ "$(role "$T/atlas-review")" = "solo:" ] && [ "$(role "$T/atlas")" = "ic:atlas-ic-1" ]'
RS="$HERE/reviewer-settings.json"
ok "reviewer_settings_shape" 'jq -e "(.model | length > 0) and (.effortLevel | length > 0) and (has(\"hooks\") | not) and .permissions.defaultMode == \"auto\" and ([\"Bash(gh pr comment:*)\", \"Bash(gh pr review:*)\", \"Bash(gh pr merge:*)\", \"Bash(git push:*)\", \"Bash(git commit:*)\"] - .permissions.deny == [])" "$RS" >/dev/null && [ "$(jq -r "[.. | .command? // empty] | length" "$RS")" -eq 0 ] && ! grep -q "/Use""rs/" "$RS"'
# the deny list against real command lines, matched as the settings matcher does: `Bash(<prefix>:*)` is a prefix,
# any other `*` matches any run of characters. Every write form is refused wherever its flag stands; the reads
# the reviewing-a-team-pr skill names are not.
denied() { python3 - "$RS" "$1" <<'PY'
import fnmatch, json, sys
cmd = sys.argv[2]
for rule in json.load(open(sys.argv[1]))["permissions"]["deny"]:
    pat = rule[len("Bash("):-1]
    if pat.endswith(":*"):
        hit = cmd.startswith(pat[:-2])
    else:
        hit = fnmatch.fnmatchcase(cmd, pat)
    if hit:
        print("yes"); break
else:
    print("no")
PY
}
miss=""; while IFS= read -r c; do [ -z "$c" ] || [ "$(denied "$c")" = yes ] || miss="$miss [$c]"; done <<'CMDS'
gh pr comment 91 -b hi
gh pr review 91 --approve
gh pr review 91 --comment -b hi
gh pr merge 91 --squash
gh pr close 91
gh pr ready 91
gh pr edit 91 --title x
gh issue comment 91 -b hi
gh -R acme/atlas pr comment 91 -b hi
gh --repo acme/atlas pr merge 91
gh -R acme/atlas api repos/acme/atlas/pulls/91/merge -X PUT
gh api repos/acme/atlas/pulls/91/merge -X PUT
gh api -X PUT repos/acme/atlas/pulls/91/merge
gh api -XPUT repos/acme/atlas/pulls/91/merge
gh api --method=POST repos/acme/atlas/issues/91/comments -fbody=hi
gh api --method POST repos/acme/atlas/issues/91/comments -f body=hi
gh api -XPOST repos/acme/atlas/pulls/91/reviews --input=r.json
gh api repos/acme/atlas/pulls/91/reviews --input r.json
gh api repos/acme/atlas/issues/91/comments -fbody=hi
gh api repos/acme/atlas/issues/91/comments -F body=@r.txt
gh api repos/acme/atlas/issues/91/comments --raw-field body=hi
gh api repos/acme/atlas/pulls/comments/3104 --method=DELETE
gh api graphql -f query=mutation
git push origin HEAD
git -C . push origin HEAD
git -c user.name=x commit -m x
git commit -m x
git -C /tmp/x commit --amend
bash -c "gh pr merge 91"
sh -c 'git push'
eval gh pr merge 91
CMDS
ok "reviewer_deny_holds_every_write_form" '[ -z "$miss" ]'
[ -z "$miss" ] || echo "    not denied:$miss"
hit=""; while IFS= read -r c; do [ -z "$c" ] || [ "$(denied "$c")" = no ] || hit="$hit [$c]"; done <<'CMDS'
gh pr view 91 --json title,body,author,state,headRefOid,baseRefName,files,commits,comments,reviews,statusCheckRollup
gh pr view 91 --json state -q .state
gh pr diff 91
gh pr checks 91
gh pr list --state open
gh api repos/acme/atlas/pulls/91/comments
gh api repos/acme/atlas/pulls/91/files --paginate
git fetch origin pull/91/head
git checkout --detach FETCH_HEAD
git log --oneline -5
git diff main...FETCH_HEAD -- queue.py
grep -n cap tests/test_queue.py
CMDS
ok "reviewer_deny_leaves_the_skills_reads" '[ -z "$hit" ]'
[ -z "$hit" ] || echo "    denied:$hit"
ok "roster_example_has_both_blocks" '[ "$(awk "/^\`\`\`fleet/{f=1;next} /^\`\`\`/{f=0} f" "$HERE/roster.example.md" | head -1)" = "atlas-ic-1	/path/to/atlas" ] && [ "$(awk "/^\`\`\`reviewers/{f=1;next} /^\`\`\`/{f=0} f" "$HERE/roster.example.md")" = "atlas-reviewer	/path/to/atlas-review" ]'
bad=0; for f in ic lead; do
  n="$(jq -r '.. | .command? // empty' "$HERE/$f-settings.json" | grep -c -v '^"\$FLEET_REPO/shared/hooks/[a-z-]*\.sh"$')"; bad=$((bad+n))
  jq -e '[.. | .command? // empty] | length > 0' "$HERE/$f-settings.json" >/dev/null || bad=$((bad+1))
done
ok "settings_hooks_use_fleet_repo" '[ $bad -eq 0 ] && ! grep -rq "/Use""rs/" "$HERE"/*-settings.json'
echo "$P pass, $F fail"; [ $F -eq 0 ]
