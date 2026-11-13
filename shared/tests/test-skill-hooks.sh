#!/bin/bash
# Unit test for the skill hooks. Throwaway roster and marker dir under $TMPDIR.
#   shared/tests/test-skill-hooks.sh     expect: skill hooks: N pass, 0 fail
set -u
TD="$(cd "$(dirname "$0")" && pwd -P)"; HERE="$TD/../hooks"   # HERE stays the hooks folder
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf 'FAIL  %s  (%s)\n' "$1" "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got $2 want $3"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" FLEET_HOME="$T/home/.fleet-agent-mgmt"; mkdir -p "$HOME" "$FLEET_HOME"   # never the real home
# The hooks run from a COPY of shared/ whose freeze_rules.py reads a test settings file (USER_SETTINGS is a
# constant, never an env var) naming the temp FLEET_HOME, so the legacy listing in that home is the test's own.
CP="$T/shared"; cp -R "$TD/.." "$CP"; HERE="$CP/hooks"
sed -i '' "s|^USER_SETTINGS = .*|USER_SETTINGS = \"$T/user-settings.json\"|" "$CP/records/freeze_rules.py"
printf '{"env":{"FLEET_HOME":"%s"}}\n' "$FLEET_HOME" > "$T/user-settings.json"
printf '# invented legacy rows\norbit/orb-42-r1\norbit/orb-43-r1\n' > "$FLEET_HOME/legacy-records.txt"
mkdir -p "$T/lead" "$T/ic" "$T/solo" "$T/checks"
printf '```fleet\nlead-1\t%s\ntest-ic\t%s\n```\n' "$T/lead" "$T/ic" > "$T/roster.md"
export FLEET_ROSTER="$T/roster.md" STATE_CHECKS="$T/checks" FLEET_SKILLS="$T/skills" FLEET_RECORDS="$T/records"
export JEV_STUB_OK=1   # the audit counts receipts made with JEV_STUB (tests only); "receipt-trust" tests unset it
for d in reporting-a-rung closing-a-rung writing-a-rung-handoff recording-a-decision recording-evidence brief-grilling sweeping-precedents foundations; do mkdir -p "$T/skills/$d"; echo x > "$T/skills/$d/SKILL.md"; done
S=s1
U="/Use""rs"   # the home-path prefix, spelt in two parts so no real-looking path sits in this file
boot(){ printf '{"cwd":"%s","session_id":"%s","source":"startup"}' "$1" "$S" | "$HERE/skill-boot.sh" 2>/dev/null; }
mark(){ printf '{"cwd":"%s","session_id":"%s","tool_name":"%s","tool_input":%s}' "$1" "$S" "$2" "$3" | "$HERE/skill-mark.sh" 2>/dev/null; echo $?; }
gate0(){ printf '{"cwd":"%s","session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" "$S" "$2" | "$HERE/artefact-gate.sh" 2>/dev/null; }; gate(){ o="$(gate0 "$@")"; [ -n "$o" ] && printf "%s" "$o" | jq -r ".hookSpecificOutput.permissionDecision" || echo allow; }
stop(){ printf '{"cwd":"%s","session_id":"%s","last_assistant_message":%s,"stop_hook_active":%s}' "$1" "$S" "$2" "${3:-false}" | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?; }
I="$T/ic"; L="$T/lead"
# seal: what the freeze writes beside rules.md and gate.md (a minimal pair when absent), for fixtures written by hand
hx(){ shasum -a 256 "$1" | cut -d' ' -f1; }
# a spec that freezes to the record's rows (fences), committed on $I's HEAD; stop1.log names that commit
cat > "$T/seal.py" <<'EOF'
import os, re, sys
r, spec, repo, shared = sys.argv[1:5]
sys.path.insert(0, shared)
import gate_run
rows, kind = {"TERMS": [], "ONE-WAY": [], "DECIDED": [], "REJECTED": []}, None
for l in open(os.path.join(r, "rules.md"), encoding="utf-8").read().split("\n"):
    if l.strip() and not l[0].isspace():
        m = re.match(r"(TERMS|ONE-WAY|DECIDED|REJECTED)\b", l); kind = m.group(1) if m else None
    elif kind and l.strip() and "[standing]" not in l and l.strip() != "none":
        rows[kind].append(l)
head = {"TERMS": "TERMS", "ONE-WAY": "ONE-WAY  stop and ask before:", "DECIDED": "DECIDED  never change:",
        "REJECTED": "REJECTED  do not come back to:"}
out = ["# ATL-42: retry failed nightly imports", ""]
for k, name in (("TERMS", "Terms"), ("ONE-WAY", "One-way"), ("DECIDED", "Decided"), ("REJECTED", "Rejected")):
    out += [f"## {name}", "", "```", head[k]] + (rows[k] or ["  none"]) + ["```", ""]
gate = open(os.path.join(r, "gate.md"), encoding="utf-8").read()
g = gate.split("\n"); i = next(n for n, l in enumerate(g) if l.startswith("GATE BLOCK"))
try:
    n = len(gate_run.read_gate(gate)[0])
except Exception:
    n = 1
out += ["## Checks", "", "```"] + [l for l in g[i + 1:] if l.strip()] + ["  on main       ok"] + ["                ok"] * (n - 1)
out += ["```", "", "---", "", "## Amendments", "", "none", ""]
os.makedirs(os.path.dirname(os.path.join(repo, spec)), exist_ok=True)
open(os.path.join(repo, spec), "w", encoding="utf-8").write("\n".join(out))
EOF
seal(){ local r="$1" sp="${2:-docs/specs/atl-42.md}" a; [ -f "$r/rules.md" ] || printf 'rules · ATL-42 r1 · frozen at 9b2e7c1\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n' > "$r/rules.md"; [ -f "$r/gate.md" ] || printf 'gate · ATL-42 r1 · frozen at 9b2e7c1 · 2026-10-08 09:00\n\nGATE BLOCK\n  proves done   make test\n  pass          exit 0\n' > "$r/gate.md"
  for b in TERMS ONE-WAY DECIDED REJECTED; do grep -q "^$b" "$r/rules.md" || printf '\n%s\n  none\n' "$b" >> "$r/rules.md"; done   # the freeze writes all four
  python3 "$T/seal.py" "$r" "$sp" "$I" "$HERE/../records"; git -C "$I" add -f "$sp"; git -C "$I" -c user.name=t -c user.email=t@t commit -q -m seal "$sp"; a="$(git -C "$I" rev-parse HEAD)"; H="$a"
  printf '2026-10-08 08:50 · STOP 1 · spec %s @ %s · test-ic · session s1\n' "$sp" "$a" > "$r/stop1.log"
  printf 'frozen · ATL-42 r1 · 2026-10-08 09:00\nspec      %s\napproved  %s\nsha256    %s  rules.md\nsha256    %s  gate.md\n' "$sp" "$a" "$(hx "$r/rules.md")" "$(hx "$r/gate.md")" > "$r/frozen.sha256"; }

# boot
check "boot ic prints skills" "$(boot "$I" | grep -c 'writing-an-analysis')" 1
check "boot lead prints skills" "$(boot "$L" | grep -c 'holding-rollups')" 1
check "boot ic prints the record folder" "$(boot "$I" | grep -c 'recording-a-decision')" 1
check "boot ic prints on resume too" "$(printf '{"cwd":"%s","session_id":"%s","source":"resume"}' "$I" "$S" | "$HERE/skill-boot.sh" 2>/dev/null | grep -c 'reporting-a-rung')" 1
check "boot solo silent" "$(boot "$T/solo" | wc -c | tr -d ' ')" 0
# artefact gate, ic
check "ic: analysis write denied cold" "$(gate "$I" /repo/docs/analysis/x.md)" deny
check "ic: adr write denied cold" "$(gate "$I" /repo/docs/adr/0001-x.md)" deny
check "ic: spec write denied cold" "$(gate "$I" /repo/docs/superpowers/specs/x-design.md)" deny
check "ic: close write denied cold" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/checks/test-ic/atl-42-r1-close.md)" deny
check "ic: decision record denied cold" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/decision-record.md)" deny
check "ic: evidence denied cold" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/evidence.md)" deny
check "ic: record close denied cold" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/close.md)" deny
check "ic: rules.md denied cold" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/rules.md)" deny
check "ic: a receipt in the record folder is not gated" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/receipts/2026-10-08-1340-gate.md)" allow
check "ic: a records dir inside a repo is not gated" "$(gate "$I" /repo/records/x/decision-record.md)" allow
check "ic: other md allowed" "$(gate "$I" /repo/README.md)" allow
check "ic: non-md in adr allowed" "$(gate "$I" /repo/docs/adr/x.py)" allow
check "ic: scratchpad allowed" "$(gate "$I" /private/tmp/x/specs/x.md)" allow
mark "$I" Skill '{"skill":"writing-an-analysis"}' >/dev/null
check "ic: analysis write allowed after skill" "$(gate "$I" /repo/docs/analysis/x.md)" allow
check "ic: adr still denied" "$(gate "$I" /repo/docs/adr/0001-x.md)" deny
mark "$I" Skill '{"skill":"plugin:writing-an-adr"}' >/dev/null
mark "$I" Skill '{"skill":"closing-a-rung"}' >/dev/null
check "ic: close write allowed after skill" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/checks/test-ic/atl-42-r1-close.md)" allow
check "ic: record close allowed after skill" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/close.md)" allow
check "ic: decision record still denied" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/decision-record.md)" deny
mark "$I" Skill '{"skill":"recording-a-decision"}' >/dev/null
mark "$I" Skill '{"skill":"recording-evidence"}' >/dev/null
check "ic: decision record allowed after skill" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/decision-record.md)" allow
check "ic: evidence allowed after skill" "$(gate "$I" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/evidence.md)" allow
check "ic: plugin-prefixed skill name marks" "$(gate "$I" /repo/docs/adr/0001-x.md)" allow
# content gate, ic: a committed doc never names the fleet, and a spec renders on GitHub
aw(){ o="$(jq -n --arg d "$1" --arg s "$S" --arg p "$2" --arg c "$3" '{cwd:$d,session_id:$s,tool_name:"Write",tool_input:{file_path:$p,content:$c}}' | "$HERE/artefact-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
ae(){ o="$(jq -n --arg d "$I" --arg s "$S" --arg t "$1" --arg p "$2" --argjson e "$3" '{cwd:$d,session_id:$s,tool_name:$t,tool_input:({file_path:$p}+$e)}' | "$HERE/artefact-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
CLEAN="$(printf '# ATL-42: retry the nightly import\n\n**Problem:** the nightly import fails on a timeout about once a week (ATL-42, importer/run.py line 40). E2E runs and the ICU build are not affected.\n\n**Verdict:** wrap the scheduler call in a bounded retry.\n\n## Terms\n\n```\nretry   one more call of the scheduler job\n```\n\n## One-way\n\n| stop and ask before | source |\n|---|---|\n| run anything against the shared dev database | ATL-42 |\n\n## Decided\n\n| # | never change | source |\n|---|---|---|\n| 1 | retry 3 times | ATL-42 |\n\n## Rejected\n\n| do not come back to | source |\n|---|---|\n| retry forever | INC-118 |\n\n## Checks\n\n| command | pass | on main |\n|---|---|---|\n| `make test` | exit 0 | exit 0 |\n\n## Direction\n\nRetry three times because the timeouts clear within minutes.\n\n---\n\n## Appendix\n\nMore detail.\n')"
SP=/repo/docs/superpowers/specs/atl-42-design.md
check "content: a cold spec with a leak is denied by both gates, reasons joined" "$(aw "$I" "$SP" "$CLEAN
see /Use""rs/robin/x" | grep -o 'SKILL GATE\|LEAK GATE' | tr '\n' ' ')" "SKILL GATE LEAK GATE "
mark "$I" Skill '{"skill":"writing-a-design-spec"}' >/dev/null
check "content: a clean spec allowed" "$(aw "$I" "$SP" "$CLEAN")" allow
n=0; while IFS= read -r l; do l="${l//@U@/$U}"; case "$(aw "$I" "$SP" "$CLEAN
$l")" in "LEAK GATE"*) n=$((n+1));; *) printf 'not denied: %s\n' "$l";; esac; done <<'LEAKS'
see @U@/robin/x.md
see ~/notes.md
see records under .fleet-agent-mgmt
see .claude/checks/x
asked lead-1 about it
test-ic wrote this
at STOP 1 we agreed
screen one ends here
reply spec ok
Reply: atlas spec ok
style: fleet form
source: the brief
record: the folder
per DR3
per UAT2
per E4
the IC decided
see the decision-record
see evidence.md
see handoff.md
see $HOME/Projects/x
see ${HOME}/notes
asked Lead-1 about it
TEST-IC wrote this
THE IC decided
LEAKS
check "content: each of the 25 leak lines denied (names in any case, \$HOME paths)" "$n" 25
n=0; while IFS= read -r l; do l="${l//@U@/$U}"; [ "$(aw "$I" "$SP" "$CLEAN
$l")" = allow ] || { n=$((n+1)); printf 'denied: %s\n' "$l"; }; done <<'OKS'
Deploys to /Workspace@U@/${workspace.current_user.userName}/x
Genie reads @U@/<user>/.assistant
OKS
check "content: the two Databricks workspace path forms allowed" "$n" 0
check "content: a fenced yaml source: line allowed" "$(aw "$I" "$SP" "$CLEAN

\`\`\`yaml
source: raw.events
record: policy
\`\`\`")" allow
check "content: the same source: line unfenced denied" "$(aw "$I" "$SP" "$CLEAN

source: raw.events" | grep -c 'source: line')" 1
check "content: a --- inside a ~~~ fence is not a render fault" "$(aw "$I" "$SP" "$CLEAN

~~~
text
---
~~~")" allow
check "content: the deny names the hit with its line" "$(aw "$I" "$SP" "$CLEAN
see /Use""rs/robin/x" | grep -c "^line 46: /Use""rs/: see /Use""rs/robin/x$")" 1
check "content: text straight above --- denied in a spec" "$(aw "$I" "$SP" "$(printf '%s' "$CLEAN" | sed '40d')" | grep -c '^line 40: text above ---: Retry three times')" 1
check "content: an unclosed fence denied in a spec" "$(aw "$I" "$SP" "$(printf '%s' "$CLEAN" | sed '11d')" | grep -c '^line 9: unclosed ``` fence')" 1
check "content: the render check is for specs only" "$(aw "$I" /repo/docs/adr/0001-x.md "$(printf '%s' "$CLEAN" | sed '40d')")" allow
check "content: a leak in a plan denied" "$(aw "$I" /repo/docs/superpowers/plans/atl-42.md "$CLEAN
per DR3" | grep -c 'LEAK GATE')" 1
check "content: a spec in a worktree under a repo's .claude is checked" "$(aw "$I" /repo/.claude/worktrees/w1/docs/specs/x.md "$CLEAN
per DR3" | grep -c 'LEAK GATE')" 1
check "content: a spec under ~/.claude is not checked" "$(aw "$I" "$HOME/.claude/x/specs/x.md" "$CLEAN
per DR3")" allow
check "content: a README is not checked" "$(aw "$I" /repo/README.md "$CLEAN
per DR3")" allow
check "content: lead not checked" "$(aw "$L" "$SP" "$CLEAN
per DR3")" allow
D="$T/repo/docs/specs/atl-42.md"; mkdir -p "$(dirname "$D")"; printf '%s\n' "$CLEAN" > "$D"
check "content: an Edit introducing a path denied, at its line" "$(ae Edit "$D" '{"old_string":"within minutes.","new_string":"within minutes (/Use''rs/robin/notes.md)."}' | grep -c '^line 39: /Use''rs/:')" 1
check "content: a clean Edit allowed" "$(ae Edit "$D" '{"old_string":"within minutes.","new_string":"within five minutes."}')" allow
printf '%s\n\nper DR3.\n\nper DR3.\n' "$CLEAN" > "$D"
check "content: an Edit that leaves a second leak denied" "$(ae Edit "$D" '{"old_string":"per DR3.","new_string":"per ATL-42."}' | grep -c '^line 49: DR id')" 1
check "content: an Edit with replace_all that clears every leak allowed" "$(ae Edit "$D" '{"old_string":"per DR3.","new_string":"per ATL-42.","replace_all":true}')" allow
printf '%s\n' "$CLEAN" > "$D"
check "content: MultiEdit edits apply in order" "$(ae MultiEdit "$D" '{"edits":[{"old_string":"within minutes.","new_string":"within minutes, see /Use''rs/x."},{"old_string":"see /Use''rs/x.","new_string":"see the runbook."}]}')" allow
check "content: a MultiEdit adding a name denied" "$(ae MultiEdit "$D" '{"edits":[{"old_string":"More detail.","new_string":"More detail from lead-1."}]}' | grep -c '^line 45: lead-1:')" 1
check "leak_check --diff: added lines only, paths and names only, file:line" "$(printf 'diff --git a/x.py b/x.py\n--- a/x.py\n+++ b/x.py\n@@ -3,0 +4,2 @@\n+ok = 1\n+p = "/Use''rs/robin/x"  # DR1 E2\n@@ -9 +11 @@\n-q = "/Use''rs/old"\n+q = 2\n' | python3 "$HERE/leak_check.py" --diff; echo "rc=$?")" 'x.py:5: /Use''rs/: p = "/Use''rs/robin/x"  # DR1 E2
rc=1'
check "leak_check --diff: an added line starting with ++ after a removed -- line is read" "$(printf 'diff --git a/x.sql b/x.sql\n--- a/x.sql\n+++ b/x.sql\n@@ -1 +1 @@\n--- old\n+++ see /Use''rs/robin/x\n' | python3 "$HERE/leak_check.py" --diff; echo "rc=$?")" 'x.sql:1: /Use''rs/: ++ see /Use''rs/robin/x
rc=1'
# leak_tokens_file_read: FLEET_HOME/leak-tokens.txt, one token per line; # and blanks ignored; ATL-<digits> is the regex
LTH="$T/leak-home"; mkdir -p "$LTH"; printf '# invented tokens\n\nzebrafish\nATL-<digits>\n' > "$LTH/leak-tokens.txt"
LTD='diff --git a/x.py b/x.py\n--- a/x.py\n+++ b/x.py\n@@ -0,0 +1,4 @@\n+clean = 1\n+x = "Zebrafish"\n+# see ATL-1234 for why\n+# a comment line\n'
# a token is a hit only where no letter or digit sits directly before or after it
LTB="$T/leak-bound"; mkdir -p "$LTB"; printf 'bs''cr\nlu''ca\nATL-<digits>\n<digits>\n' > "$LTB/leak-tokens.txt"
lt(){ printf '%s\n' "$1" | FLEET_HOME="$LTB" python3 "$HERE/leak_check.py" --tokens --text m >/dev/null; echo "rc=$?"; }
check "leak_tokens_bounds: a word holding the token inside it is not a hit" "$(lt 'a subs''cription or paid plan')" rc=0
check "leak_tokens_bounds: the token alone and the token with -x after it are hits" "$(lt 'the bs''cr')$(lt 'see bs''cr-x here')" rc=1rc=1
check "leak_tokens_bounds: the token in capitals before -crosswalk is a hit" "$(lt 'LU''CA-crosswalk')" rc=1
check "leak_tokens_bounds: 'ATL-12' with ATL-<digits> is a hit, 'ATL-12x' is not" "$(lt 'see ATL-12 now')$(lt 'see ATL-12x now')" rc=1rc=0
check "leak_tokens_bounds: a bare <digits> token is skipped, a digit run is no hit" "$(lt 'build 12345')" rc=0
check "leak_tokens_file_read: tokens are hits in --diff, any case, ATL-<digits> a regex" "$(printf "$LTD" | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --tokens --diff; echo "rc=$?")" 'x.py:2: zebrafish (leak token): x = "Zebrafish"
x.py:3: ATL-<digits> (leak token): # see ATL-1234 for why
rc=1'
check "leak_tokens_flag: without --tokens the file is not read, --diff, --text and --doc all clean" "$(printf "$LTD" | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --diff; echo "rc=$?"; echo 'feat(ATL-123): x' | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --text m; echo "rc=$?"; echo 'Ticket ATL-1234.' | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --doc -; echo "rc=$?")" 'rc=0
rc=0
rc=0'
check "leak_tokens_flag: with --tokens, --text and --doc are hits" "$(echo 'feat(ATL-123): x' | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --tokens --text m >/dev/null; echo "rc=$?"; echo 'Ticket ATL-1234.' | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --doc - --tokens >/dev/null; echo "rc=$?")" 'rc=1
rc=1'
check "leak_tokens_file_read: a file-less FLEET_HOME gives today's answer" "$(printf "$LTD" | FLEET_HOME="$T/no-home" python3 "$HERE/leak_check.py" --tokens --diff; echo "rc=$?")" 'rc=0'
check "leak_tokens_file_read: a comment line and a blank line are no tokens" "$(printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -0,0 +1,2 @@\n+# invented tokens\n+ \n' | FLEET_HOME="$LTH" python3 "$HERE/leak_check.py" --tokens --diff; echo "rc=$?")" 'rc=0'
check "leak_check --doc: a relative specs/ path gets the render check" "$(printf 'a\n---\n' | python3 "$HERE/leak_check.py" --doc - --path specs/finance/x.md; echo "rc=$?")" 'specs/finance/x.md:2: text above ---: a
rc=1'
# artefact gate, lead + solo
check "lead: handoff denied cold" "$(gate "$L" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/handoff.md)" deny
check "lead: brief denied cold" "$(gate "$L" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/brief.md)" deny
mark "$L" Skill '{"skill":"brief-grilling"}' >/dev/null
# a rung brief is written only beside a precedents.json (sweeping-precedents) that passes precedents-check.sh <record dir>;
# a folder under a fake home, never the real one. atlas has one close report with one LEARNED row; beacon has none.
PB="$T/fh/.fleet-agent-mgmt/records/atlas"; PN="$T/fh/.fleet-agent-mgmt/records/beacon"; mkdir -p "$PB/atl-40-r1" "$PB/atl-42-r1" "$PB/atl-43-r1" "$PN/bcn-1-r1"
printf 'close · atlas-ic · ATL-40 rung 1 · retry failed nightly imports · 2026-09-16 15:40 · merged 7c1e2a9\n\nLEARNED, what bites the next rung\n\n  | KIND       | FACT                                       |\n  |------------|--------------------------------------------|\n  | went wrong | a sleep blocks the shared scheduler thread |\n' > "$PB/atl-40-r1/close.md"
PJ='{"project":"atlas","rows_read":1,"records":["atl-40-r1"],"rows":[{"id":"P1","rule":"A wait inside the nightly job reschedules it.","sources":["atl-40-r1 · LEARNED · row 1"],"fits":"constraint","why":"the retry runs in the same job","status":"live"}],"not_carried":[]}'
printf '%s\n' "$PJ" > "$PB/atl-42-r1/precedents.json"
check "lead: brief allowed after skill, a checked precedents.json beside it" "$(gate "$L" "$PB/atl-42-r1/brief.md")" allow
check "lead: analysis path not gated" "$(gate "$L" /repo/docs/analysis/x.md)" allow
mark "$L" Skill '{"skill":"writing-a-rung-handoff"}' >/dev/null
check "lead: handoff allowed after skill" "$(gate "$L" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/handoff.md)" allow
check "lead: session handoff still denied, rung skill is the wrong one" "$(gate "$L" /Use""rs/robin/Projects/fleet/Leads/lead-1/handoffs/2026-10-13-lead-1-session-handoff.md)" deny
mark "$L" Skill '{"skill":"drafting-handoff"}' >/dev/null
check "lead: session handoff allowed after drafting-handoff" "$(gate "$L" /Use""rs/robin/Projects/fleet/Leads/lead-1/handoffs/2026-10-13-lead-1-session-handoff.md)" allow
check "lead: old rung handoff path denied as moved" "$(gate "$L" /Use""rs/robin/Projects/fleet/Leads/lead-1/handoffs/atl-43-r1.md)" deny
check "lead: old brief path denied as moved" "$(gate "$L" /Use""rs/robin/Projects/fleet/Leads/lead-1/briefs/atl-43-r1.md)" deny
check "lead: old tickets path denied as moved" "$(gate "$L" /Use""rs/robin/Projects/fleet/Leads/lead-1/tickets/atl-43-r1.md)" deny
check "lead: moved reason names the record folder" "$(printf '{"cwd":"%s","session_id":"%s","tool_input":{"file_path":"%s"}}' "$L" "$S" /Use""rs/robin/Projects/fleet/Leads/lead-1/briefs/x.md | "$HERE/artefact-gate.sh" | grep -c 'fleet-agent-mgmt/records')" 1
check "lead: boot names both handoff skills" "$(boot "$L" | grep -c 'drafting-handoff\|writing-a-rung-handoff')" 2
check "solo: never gated" "$(gate "$T/solo" /repo/docs/adr/x.md)" allow
# precedents gate, lead: a rung brief is refused until its record folder holds a precedents.json that passes
# shared/records/precedents-check.sh <record dir>, the same command the lead runs
gr(){ o="$(printf '{"cwd":"%s","session_id":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$L" "$S" "${2:-Write}" "$1" | "$HERE/artefact-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r .hookSpecificOutput.permissionDecisionReason || echo allow; }
mark "$L" Skill '{"skill":"brief-grilling"}' >/dev/null; mark "$L" Skill '{"skill":"writing-a-rung-handoff"}' >/dev/null   # the boot check above cleared the markers
check "precedents: a brief with no precedents.json beside it denied after the skill" "$(gate "$L" "$PB/atl-43-r1/brief.md")" deny
check "precedents: the reason names the skill and the file" "$(gr "$PB/atl-43-r1/brief.md" | grep -c "^PRECEDENTS: .*there is no $PB/atl-43-r1/precedents.json.*sweeping-precedents")" 1
check "precedents: the reason names the check on the record folder" "$(gr "$PB/atl-43-r1/brief.md" | grep -c "until shared/records/precedents-check.sh $PB/atl-43-r1 passes")" 1
check "precedents: the reason names no removed mode or file" "$(gr "$PB/atl-43-r1/brief.md" | grep -c -e '--sweep' -e '--final' -e 'sweep.json')" 0
check "precedents: an Edit and a MultiEdit of a brief not written yet denied too" "$(gr "$PB/atl-43-r1/brief.md" Edit | grep -c '^PRECEDENTS: '):$(gr "$PB/atl-43-r1/brief.md" MultiEdit | grep -c '^PRECEDENTS: ')" "1:1"
check "precedents: a brief in a record folder not made yet denied" "$(gr "$PB/atl-44-r1/brief.md" | grep -c '^PRECEDENTS: ')" 1
check "precedents: BRIEF.md is the same file" "$(gate "$L" "$PB/atl-43-r1/BRIEF.md")" deny
printf 'none: first rung on atlas\n' > "$PB/atl-43-r1/precedents.md"
check "precedents: a precedents.md, the old file, does not count" "$(gr "$PB/atl-43-r1/brief.md" | grep -c "^PRECEDENTS: .*there is no $PB/atl-43-r1/precedents.json")" 1
rm -f "$PB/atl-43-r1/precedents.md"
# precedents.json is there but the check fails: the refusal carries the check's fault lines
: > "$PB/atl-43-r1/precedents.json"
check "precedents: an empty precedents.json denied, the check's fault named" "$(gr "$PB/atl-43-r1/brief.md" | grep -c "precedents-check.sh $PB/atl-43-r1 fails")" 1
check "precedents: an empty precedents.json, the fault line" "$(gr "$PB/atl-43-r1/brief.md" | grep -c "^  $PB/atl-43-r1/precedents.json: not JSON")" 1
printf '{"none": "first rung on atlas"}\n' > "$PB/atl-43-r1/precedents.json"
check "precedents: none on a project whose gatherer prints rows denied" "$(gr "$PB/atl-43-r1/brief.md" | grep -c '^  none: the gatherer printed 1 rows')" 1
printf '{"none": ""}\n' > "$PB/atl-43-r1/precedents.json"
check "precedents: none with no reason denied" "$(gate "$L" "$PB/atl-43-r1/brief.md")" deny
printf '%s\n' "$PJ" | jq -c '.rows_read=2' > "$PB/atl-43-r1/precedents.json"
check "precedents: rows_read off the gatherer's count denied, naming the field" "$(gr "$PB/atl-43-r1/brief.md" | grep -c '^  rows_read: 2, the gatherer printed 1 rows')" 1
printf '%s\n' "$PJ" | jq -c '.rows[0].brief="constraints 3"' > "$PB/atl-43-r1/precedents.json"
check "precedents: a brief field denied (the brief's own bracket carries the link)" "$(gr "$PB/atl-43-r1/brief.md" | grep -c '^  rows\[0\].brief: not allowed')" 1
printf '%s\n' "$PJ" | jq -c '.rows[0].sources=["atl-40-r1 · LEARNED · row 2"]' > "$PB/atl-43-r1/precedents.json"
check "precedents: a row the gatherer printed left out denied, naming the reference" "$(gr "$PB/atl-43-r1/brief.md" | grep -c '^  atl-40-r1 · LEARNED · row 1: the gatherer printed it')" 1
printf '%s\n' "$PJ" > "$PB/atl-43-r1/precedents.json"
check "precedents: a precedents.json that passes the check allowed" "$(gate "$L" "$PB/atl-43-r1/brief.md")" allow
printf '{"none": "first rung on beacon"}\n' > "$PN/bcn-1-r1/precedents.json"
check "precedents: none: <reason> on a project with no close report allowed" "$(gate "$L" "$PN/bcn-1-r1/brief.md")" allow
rm -f "$PB/atl-43-r1/precedents.json"
# another spelling of the same brief is the brief: /./, // and /../ are folded first
for sp in "$PB/atl-43-r1/./brief.md" "${PB%/atlas}//atlas/atl-43-r1/brief.md" "$PB/atl-43-r1//brief.md" "$PB/x/../atl-43-r1/brief.md" "$PB/./atl-43-r1/brief.md"; do
  check "precedents: the brief spelled ${sp#"$T"/fh} denied" "$(gr "$sp" | grep -c "^PRECEDENTS: .*$PB/atl-43-r1/precedents.json")" 1; done
printf '%s\n' "$PJ" > "$PB/atl-43-r1/precedents.json"
check "precedents: the brief spelled with // allowed once precedents.json passes" "$(gate "$L" "$PB/atl-43-r1//brief.md")" allow
rm -f "$PB/atl-43-r1/precedents.json"
check "precedents: a ticket spelled with /./ in that folder still allowed" "$(gate "$L" "$PB/atl-43-r1/./ticket.md")" allow
check "precedents: a lead handoff spelled with // still gated on its skill cold" "$(S=cold-prec gr "${PB%/atlas}//atlas/atl-43-r1/handoff.md" | grep -c '^SKILL GATE: .*writing-a-rung-handoff')" 1
# only the first write: a brief already there (a rung briefed before the sweep) is edited as before
mkdir -p "$PB/atl-46-r1"; printf '# ATL-46 brief\n' > "$PB/atl-46-r1/brief.md"
check "precedents: an Edit of a brief already there, no precedents.json, allowed" "$(gr "$PB/atl-46-r1/brief.md" Edit)" allow
check "precedents: a MultiEdit and a Write over it allowed" "$(gr "$PB/atl-46-r1/brief.md" MultiEdit):$(gr "$PB/atl-46-r1/brief.md" Write)" "allow:allow"
check "precedents: that brief cold, the skill gate only" "$(S=cold-prec gr "$PB/atl-46-r1/brief.md" Edit | grep -o '^SKILL GATE\|PRECEDENTS:' | tr '\n' ' ')" "SKILL GATE "
check "precedents: cold, both reasons, skill gate first" "$(S=cold-prec gr "$PB/atl-43-r1/brief.md" | grep -o '^SKILL GATE\|PRECEDENTS:' | tr '\n' ' ')" "SKILL GATE PRECEDENTS: "
check "precedents: cold with a checked precedents.json, the skill gate only" "$(S=cold-prec gr "$PB/atl-42-r1/brief.md" | grep -c 'PRECEDENTS')" 0
# precedents.json is written with sweeping-precedents; precedents.md is not used and not gated
check "precedents: precedents.json denied cold, naming sweeping-precedents" "$(gr "$PB/atl-43-r1/precedents.json" | grep -c '^SKILL GATE: .*sweeping-precedents')" 1
check "precedents: PRECEDENTS.JSON is the same file" "$(gate "$L" "$PB/atl-43-r1/PRECEDENTS.JSON")" deny
check "precedents: precedents.md is not gated" "$(S=cold-prec gr "$PB/atl-43-r1/precedents.md")" allow
check "precedents: another .json in the record folder not gated" "$(gate "$L" "$PB/atl-43-r1/notes.json")" allow
mark "$L" Skill '{"skill":"sweeping-precedents"}' >/dev/null
check "precedents: precedents.json allowed after the skill" "$(gate "$L" "$PB/atl-43-r1/precedents.json")" allow
check "precedents: precedents.json is not checked at its own write" "$(gate "$L" "$PB/atl-43-r1/precedents.json"):$([ -e "$PB/atl-43-r1/precedents.json" ] && echo there || echo absent)" "allow:absent"
# every other path unchanged
check "precedents: the handoff beside a brief with no precedents.json allowed" "$(gate "$L" "$PB/atl-43-r1/handoff.md")" allow
check "precedents: the ticket in that folder allowed" "$(gate "$L" "$PB/atl-43-r1/ticket.md")" allow
check "precedents: a brief.md outside the records folder allowed" "$(gate "$L" /repo/docs/brief.md)" allow
check "precedents: a brief.md in the scratchpad allowed" "$(gate "$L" /private/tmp/x/.fleet-agent-mgmt/records/atlas/atl-43-r1/brief.md)" allow
check "precedents: a brief one level up (not a record folder) not checked" "$(gate "$L" "$PB/brief.md")" allow
check "precedents: an IC is not gated on a brief" "$(gate "$I" "$PB/atl-43-r1/brief.md")" allow
check "precedents: an IC is not gated on precedents.json" "$(gate "$I" "$PB/atl-43-r1/precedents.json")" allow
check "precedents: solo is not gated on a brief" "$(gate "$T/solo" "$PB/atl-43-r1/brief.md")" allow
check "precedents: the IC boot text unchanged" "$(printf '{"cwd":"%s","session_id":"%s","source":"resume"}' "$I" "$S" | "$HERE/skill-boot.sh" 2>/dev/null | grep -c 'precedents')" 0
check "precedents: lead boot names precedents.json and sweeping-precedents" "$(boot "$L" | grep -c 'precedents.json.*sweeping-precedents')" 1   # clears the lead's markers, as the boot check above did
# stop gate, ic
check "ic: STOP header bounces cold" "$(stop "$I" '"atlas-sbx · ATL-71 r1 · STOP 2 · 11:08 · holding on lead-1\n  ✔ 1 x"')" 2
check "ic: STOP header bounces once more on the bounce turn" "$(stop "$I" '"x · STOP 2 · y"' true)" 2
check "ic: bounce count is 2" "$(cat "$T/checks/test-ic/skills/$S/.bounces")" 2
check "ic: STOP header passes on the third try" "$(stop "$I" '"x · STOP 2 · y"' true)" 0
check "ic: a cold turn resets the count and bounces" "$(stop "$I" '"x · STOP 2 · y"')" 2
check "ic: count back to 1" "$(cat "$T/checks/test-ic/skills/$S/.bounces")" 1
rm -rf "$T/checks/test-ic/skills/$S"   # what skill-boot does on compaction
check "ic: bounce turn after a compaction bounces again" "$(stop "$I" '"x · STOP 2 · y"' true)" 2
check "ic: plain message passes" "$(stop "$I" '"done with step 3"')" 0
mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null
check "ic: STOP header passes after skill" "$(stop "$I" '"x · STOP 2 · y"')" 0
boot "$I" >/dev/null
check "ic: close header bounces cold" "$(stop "$I" '"close · test-ic · ATL-42 rung 1 · x · 2026-09-16 15:40 · merged 7c1e2a9\n\nVerdict: ✔"')" 2
echo 2 > "$T/checks/test-ic/skills/$S/.bounces"
check "ic: close header passes on bounce turn at count 2" "$(stop "$I" '"close · x"' true)" 0
check "ic: close mid-message does not bounce" "$(stop "$I" '"the close · file is at"')" 0
mark "$I" Skill '{"skill":"closing-a-rung"}' >/dev/null
check "ic: close header passes after skill" "$(stop "$I" '"close · test-ic · ATL-42 rung 1 · x"')" 0
check "lead: close header not gated" "$(stop "$L" '"close · x"')" 0
# stop gate, lead
check "lead: check header bounces cold" "$(stop "$L" '"rows\n  happened   check · atlas-sbx · ATL-71 r1 · STOP 2 · received 11:08"')" 2
mark "$L" Skill '{"skill":"reporting-a-rung"}' >/dev/null
check "lead: check header still bounces without haiku" "$(stop "$L" '"happened   check · x"')" 2
mark "$L" Agent '{"model":"haiku","prompt":"x"}' >/dev/null
check "lead: check header passes with skill + haiku" "$(stop "$L" '"happened   check · x"')" 0
check "lead: held line bounces cold" "$(stop "$L" '"held 3 since 14:05 · ✖ 1"')" 2
mark "$L" Skill '{"skill":"holding-rollups"}' >/dev/null
check "lead: held line passes after skill" "$(stop "$L" '"held 3 since 14:05 · ✖ 1"')" 0
# explaining-in-steps: over 15 prose lines in the final text, fences not counted, check and held exempt
p15="$(for i in $(seq 1 15); do printf 'line %d\\n' "$i"; done)"; p16="${p15}line 16"
check "lead: 15 prose lines pass cold" "$(stop "$L" "\"$p15\"")" 0
check "lead: 16 prose lines bounce cold" "$(stop "$L" "\"$p16\"")" 2
check "lead: the bounce names explaining-in-steps" "$(printf '{"cwd":"%s","session_id":"%s","last_assistant_message":"%s"}' "$L" "$S" "$p16" | "$HERE/stop-skill-gate.sh" 2>&1 | grep -c explaining-in-steps)" 1
check "lead: 3 prose lines over a 14-line fence pass" "$(stop "$L" "\"a\\nb\\nc\\n\`\`\`\\n$(for i in $(seq 1 14); do printf 'd%d\\n' "$i"; done)\`\`\`\"")" 0
check "lead: a long check message is exempt" "$(stop "$L" "\"happened   check · x\\n$p16\"")" 0
check "lead: a long held message is exempt" "$(stop "$L" "\"held 3 since 14:05\\n$p16\"")" 0
mark "$L" Skill '{"skill":"explaining-in-steps"}' >/dev/null
check "lead: 16 prose lines pass after skill" "$(stop "$L" "\"$p16\"")" 0
check "lead: boot names explaining-in-steps" "$(boot "$L" | grep -c 'explaining-in-steps')" 1
check "solo: STOP header passes" "$(stop "$T/solo" '"x · STOP 1 · y"')" 0
# resume keeps markers
mark "$I" Skill '{"skill":"writing-an-analysis"}' >/dev/null
printf '{"cwd":"%s","session_id":"%s","source":"resume"}' "$I" "$S" | "$HERE/skill-boot.sh" >/dev/null 2>&1
check "resume keeps markers: analysis still allowed" "$(gate "$I" /repo/docs/analysis/x.md)" allow
# boot clears markers
boot "$I" >/dev/null
check "boot clears markers: analysis denied again" "$(gate "$I" /repo/docs/analysis/x.md)" deny
# transcript fallback
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"x · STOP 1 · y"}]}}\n' > "$T/tr.jsonl"
r="$(printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$I" "$S" "$T/tr.jsonl" | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?)"
check "ic: transcript fallback bounces" "$r" 2
printf '{"type":"user","message":{"role":"user","content":"go"}}\n{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"SendMessage","input":{"to":"lead-1","message":"x · STOP 2 · 11:08 · holding"}}]}}\n{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"sent"}]}}\n{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"sent, holding"}]}}\n' > "$T/tr2.jsonl"
boot "$I" >/dev/null
r="$(printf '{"cwd":"%s","session_id":"%s","last_assistant_message":"sent, holding","transcript_path":"%s"}' "$I" "$S" "$T/tr2.jsonl" | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?)"
check "ic: STOP header inside SendMessage bounces" "$r" 2
printf '{"type":"user","message":{"role":"user","content":"go"}}\n{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"SendMessage","input":{"to":"lead-1","message":"x · STOP 2 · y"}}]}}\n{"type":"user","message":{"role":"user","content":"next thing"}}\n{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"done"}]}}\n' > "$T/tr3.jsonl"
r="$(printf '{"cwd":"%s","session_id":"%s","last_assistant_message":"done","transcript_path":"%s"}' "$I" "$S" "$T/tr3.jsonl" | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?)"
check "ic: STOP header in an earlier turn does not bounce" "$r" 0
# chat gate, lead: a turn the owner did not start ends with no chat text, or one line naming no key and no IC
cg(){ jq -n --arg c "$L" --arg s "$S" --arg m "$2" --arg p "$TD/testdata/$1" '{cwd:$c,session_id:$s,last_assistant_message:$m,transcript_path:$p}' | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?; }
check "turn_text: owner-typed turn starts owner" "$(python3 "$HERE/turn_text.py" --start "$TD/testdata/chat-gate-owner.jsonl")" owner
check "turn_text: stop hook feedback keeps the peer turn machine" "$(python3 "$HERE/turn_text.py" --start "$TD/testdata/chat-gate-peer-stop.jsonl")" machine
check "chat gate: owner-typed turn with IC text passes" "$(cg chat-gate-owner.jsonl "$(printf 'ATL-42: test-ic is at STOP 1.\nThe card is on the board.')")" 0
check "chat gate: peer turn with one plain line passes" "$(cg chat-gate-peer-plain.jsonl 'Recorded on the board.')" 0
check "chat gate: peer turn with a STOP line bounces" "$(cg chat-gate-peer-stop.jsonl 'test-ic is at STOP 1 on ATL-42 r1, holding for your spec ok.')" 2
check "chat gate: peer turn with empty text passes" "$(cg chat-gate-peer-plain.jsonl '')" 0
check "chat gate: peer turn with two plain lines bounces" "$(cg chat-gate-peer-plain.jsonl "$(printf 'Recorded.\nAll quiet.')")" 2
check "chat gate: the bounce names the key" "$(jq -n --arg c "$L" --arg s "$S" --arg p "$TD/testdata/chat-gate-peer-stop.jsonl" '{cwd:$c,session_id:$s,last_assistant_message:"see ATL-42",transcript_path:$p}' | "$HERE/stop-skill-gate.sh" 2>&1 >/dev/null | grep -c 'CHAT GATE.*names ATL-42')" 1
check "turn_text: an owner line mid-turn holds against a later task notice" "$(python3 "$HERE/turn_text.py" --start "$TD/testdata/chat-gate-midturn.jsonl")" owner
check "chat gate: owner line typed mid-turn in a peer turn passes" "$(cg chat-gate-midturn.jsonl "$(printf 'ATL-42: yes, on the board.\nIts reply words are there too.')")" 0
check "chat gate: ic sessions are not gated" "$(jq -n --arg c "$I" --arg s "$S" --arg p "$TD/testdata/chat-gate-peer-stop.jsonl" '{cwd:$c,session_id:$s,last_assistant_message:"ATL-42 noted\nmore",transcript_path:$p}' | "$HERE/stop-skill-gate.sh" 2>/dev/null; echo $?)" 0
# message gate, ic
send(){ o="$(printf '{"cwd":"%s","session_id":"%s","tool_name":"SendMessage","tool_input":{"to":"lead-1","message":%s}}' "$1" "$S" "$2" | "$HERE/message-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
boot "$I" >/dev/null
long="$(python3 -c 'print(chr(34)+"x · STOP 2 · y"+"\\nrow"*35+chr(34))')"
check "ic: STOP send denied cold" "$(send "$I" '"x · STOP 2 · y\n  ✔ 1 x"' | grep -c 'SKILL GATE')" 1
check "ic: a STOP header with text before its · (STOP 2 (re-send) ·) denied cold" "$(send "$I" '"x · STOP 2 (re-send) · y\n  ✔ 1 x"' | grep -c 'SKILL GATE')" 1
check "ic: plain send allowed" "$(send "$I" '"question for lead-1"')" allow
mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null
check "ic: short STOP send allowed after skill" "$(send "$I" '"x · STOP 2 · y\n  ✔ 1 x"')" allow
check "ic: 36-line STOP send denied" "$(send "$I" "$long" | grep -c 'LENGTH GATE')" 1
tpl="$(grep -v '^#' "$HERE/../skills/reporting-a-rung/templates/stop-report.md" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
check "ic: the template with its stakes line fits the 30-line cap" "$(send "$I" "$tpl")" allow
# receipt gate: record folder named on the files line, newest receipt at HEAD, no ✔ over red
export FLEET_RECORDS="$T/records"; R="$T/records/atlas/atl-42-r1"; mkdir -p "$R/receipts"
git -C "$I" init -q 2>/dev/null; git -C "$I" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one 2>/dev/null
printf '# ATL-42 rung 1 · decision record · test-ic\n' > "$R/decision-record.md"; seal "$R"; GH="$(hx "$R/gate.md")"   # seal sets H
check "ic: STOP without its record folder denied once the IC has one" "$(send "$I" '"x · STOP 2 · y\n  ✔ 1 x"' | grep -c 'does not name it')" 1
msg="$(printf '"x · STOP 2 · y\\n  ✔ 1  make test  = pass\\n  files record %s/"' "$R")"
check "ic: STOP with the folder but no receipt denied" "$(send "$I" "$msg" | grep -c 'no gate receipt')" 1
printf 'receipt · atl-42-r1 · 2026-10-08 10:00 · HEAD 0000000000000000000000000000000000000000 · dirty 0 · %s\nverdict  green\ngate     sha256 %s\n  1  green  exit 0  make test\n' "$I" "$GH" > "$R/receipts/2026-10-08-1000-gate.md"
check "ic: receipt at another HEAD denied" "$(send "$I" "$msg" | grep -c 'is at HEAD 0000000')" 1
printf 'receipt · atl-42-r1 · 2026-10-08 10:01 · HEAD %s · dirty 0 · %s\nverdict  red: 1 of 2\ngate     sha256 %s\n  1  green  exit 0  make test\n     pass   exit 0\n  2  red    exit 1  make import-dry-run FILE=bad.csv\n     pass   exit 0\n' "$H" "$I" "$GH" > "$R/receipts/2026-10-08-1001-gate.md"
check "ic: red receipt, red reported as red, allowed" "$(send "$I" "$(printf '"x · STOP 2 · y\\n  ✔ 1  make test  = pass\\n  ✖ 2  make import-dry-run FILE=bad.csv  exit 1  ≠ pass\\n  files record %s/"' "$R")")" allow
check "ic: ticked over red denied" "$(send "$I" "$(printf '"x · STOP 2 · y\\n  ✔ 2  make import-dry-run FILE=bad.csv  = pass\\n  files record %s/"' "$R")" | grep -c 'ticked over red')" 1
check "ic: green receipt at HEAD allowed" "$(printf 'receipt · atl-42-r1 · 2026-10-08 10:02 · HEAD %s · dirty 0 · %s\nverdict  green\ngate     sha256 %s\n  1  green  exit 0  make test\n' "$H" "$I" "$GH" > "$R/receipts/2026-10-08-1002-gate.md"; send "$I" "$msg")" allow
check "ic: plain message with no STOP header still allowed" "$(send "$I" '"question for lead-1"')" allow
# gate-run.sh: runs gate.md, writes a receipt, exit 0 green / 1 red
printf 'GATE BLOCK\n  proves done   echo "3 passed"\n                sh -c "echo boom; exit 1"\n  pass          exit 0 and "3 passed" in the summary line\n                exit 0\n  on failure    stop.\n  owner'"'"'s word  none\n' > "$R/gate.md"; seal "$R"
r="$(cd "$I" && "$HERE/../records/gate-run.sh" "$R" 2>&1; echo "rc=$?")"
check "gate-run: red when one command fails" "$(printf '%s' "$r" | grep -c '^gate-run: red: 1 of 2')" 1
check "gate-run: exit 1 on red" "$(printf '%s' "$r" | tail -1)" rc=1
rcpt="$(ls -t "$R"/receipts/*-gate.md | head -1)"
check "gate-run: receipt carries HEAD" "$(grep -c "HEAD $H" "$rcpt")" 1
check "process-3: the receipt names the sha256 of the gate.md it ran" "$(grep -c "^gate     sha256 $(hx "$R/gate.md")$" "$rcpt")" 1
check "gate-run: receipt marks the failing command red with its exit" "$(grep -c '^  2  red    exit 1  sh -c' "$rcpt")" 1
check "gate-run: receipt tail quotes the output" "$(grep -c 'tail   boom' "$rcpt")" 1
printf 'GATE BLOCK\n  proves done   echo "3 passed"\n  pass          "3 passed", no "failed"\n' > "$R/gate.md"; seal "$R"
check "gate-run: green with a quoted string present and an absent one absent" "$(cd "$I" && "$HERE/../records/gate-run.sh" "$R" >/dev/null 2>&1; echo $?)" 0
printf 'GATE BLOCK\n  proves done   echo "2 failed"\n  pass          no "failed"\n' > "$R/gate.md"; seal "$R"
check "gate-run: red when a string that must be absent is present" "$(cd "$I" && "$HERE/../records/gate-run.sh" "$R" >/dev/null 2>&1; echo $?)" 1
rm -rf "$T/records"
# dr-check: the newest entry against rules.md, stubbed
export FLEET_RECORDS="$T/records"; R="$T/records/atlas/atl-42-r1"; mkdir -p "$R"
printf 'rules · ATL-42 r1 · frozen at 9b2e7c1\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n  any run against the shared dev database   [gate block]\n\nDECIDED  never change:\n  ✔ 1  the retry wraps the scheduler call, never importer.run()   retry.py, new   [brief 3]\n\nREJECTED  do not come back to:\n  retry forever   [brief]\n' > "$R/rules.md"; seal "$R"
dr(){ printf '{"cwd":"%s","session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" "$S" "$2" | JEV_ENV="$T/nokey" JEV_STUB="${3:-}" "$HERE/dr-check.sh" 2>/dev/null; }
dump(){ JEV_ENV="$T/nokey" python3 "$HERE/dr_check.py" "$R/decision-record.md" --dump; }
entry(){ printf '# ATL-42 rung 1 · decision record · test-ic\n\nATL-42 DR1 · task 2 · 2026-10-08 11:00 · test-ic\n  plan        2 "the task line"\n  question    which path?\n  decided     %s\n  instead of  -\n  because     x\n%s  undo        git revert abc\n  evidence    -\n  review      -\n' "$1" "${2:-}" > "$R/decision-record.md"; }
entry "wrap scheduler.nightly()"
check "dr-check: no key appends a no-key line" "$(dr "$I" "$R/decision-record.md" >/dev/null; grep -c '^  jev         stop and ask, no check (no key)$' "$R/decision-record.md")" 1
check "dr-check: runs once per entry" "$(dr "$I" "$R/decision-record.md" >/dev/null; grep -c '^  jev' "$R/decision-record.md")" 1
stub(){ printf '{"model":"jev-stub","answers":{"standing-1":{"type":"noul","noul":%s},"standing-2":{"type":"noul","noul":0.03},"oneway-5":{"type":"noul","noul":%s},"decided-8":{"type":"noul","noul":%s},"rejected-11":{"type":"noul","noul":0.01}}}' "$1" "$2" "$3" > "$T/stub-$4.json"; }
stub 0.05 0.08 0.02 ok; stub 0.91 0.08 0.02 push; stub 0.05 0.90 0.02 shared; stub 0.05 0.08 0.88 decided; stub 0.70 0.08 0.02 band
entry "wrap scheduler.nightly()"
check "dr-check: continue when no line fires" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         continue, max yes 0.08 · jev-stub' "$R/decision-record.md")" 1
entry "force-push feat/atl-42 to origin"
check "dr-check: standing yes without the word is stop and ask" "$(dr "$I" "$R/decision-record.md" "$T/stub-push.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c 'stop and ask, standing-1 0.91 (outside the worktree).*Ask in this pane')" 1
entry "force-push feat/atl-42 to origin" '  owner       "ATL-42 force-push ok" typed in the test-ic pane, 11:02\n'
check "dr-check: standing yes with the word continues" "$(dr "$I" "$R/decision-record.md" "$T/stub-push.json" >/dev/null; grep -c '^  jev         continue, standing-1 with the owner.s word' "$R/decision-record.md")" 1
entry "run the dry run against the shared dev database"
check "dr-check: per-rung one-way yes without the word is stop and ask" "$(dr "$I" "$R/decision-record.md" "$T/stub-shared.json" >/dev/null; grep -c '^  jev         stop and ask, oneway-5 0.90 (any run against the shared dev database)' "$R/decision-record.md")" 1
entry "wrap importer.run() directly"
check "dr-check: DECIDED yes is rework, first cell only" "$(dr "$I" "$R/decision-record.md" "$T/stub-decided.json" >/dev/null; grep -c '^  jev         rework, decided-8 0.88 (the retry wraps the scheduler call, never importer.run())' "$R/decision-record.md")" 1
entry "wrap importer.run() directly" '  owner       "ATL-42 D4 b, wrap importer.run()" typed in the test-ic pane, 11:30\n'
check "dr-check: DECIDED yes with the word continues and names the row (J12)" "$(dr "$I" "$R/decision-record.md" "$T/stub-decided.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c 'continue, decided-8 with the owner.s word (the retry wraps the scheduler call, never importer.run()).*DECIDED line 8 of rules.md is changed by the owner')" 1
entry "something near the cut"
check "dr-check: band says read the line" "$(dr "$I" "$R/decision-record.md" "$T/stub-band.json" >/dev/null; grep -c '^  jev         continue, read standing-1 0.70' "$R/decision-record.md")" 1
entry "deploy to the sandbox, sandbox 3 of 2"
check "dr-check: a third sandbox deploy without the word is stop and ask" "$(dr "$I" "$R/decision-record.md" "$T/stub-push.json" >/dev/null; grep -c '^  jev         stop and ask, standing-1 0.91' "$R/decision-record.md")" 1
check "dr-check: standing-1 asks about a branch another person pushed to and a third sandbox deploy" "$(dump | jq -r '.request.body.questions["standing-1"].instructions' | grep -c 'a branch another person pushed to.*a third sandbox deploy or e2e run in one rung')" 1
# one write adding two entries: both checked, each under its own entry (ATL-43 N3)
two(){ printf '\nATL-42 DR%s · task 3 · 2026-10-08 12:00 · test-ic\n  plan        3 "the task line"\n  question    which?\n  decided     %s\n  instead of  -\n  because     x\n  undo        git revert def\n  evidence    -\n  review      -\n' "$1" "$2" >> "$R/decision-record.md"; }
entry "wrap scheduler.nightly()"; two 2 "keep the retry count at 3"; two 3 "log each retry"
ctx="$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext')"
check "dr-check: one write with three new entries checks all three" "$(grep -c '^  jev         continue, max yes 0.08 · jev-stub' "$R/decision-record.md")" 3
check "dr-check: each jev line sits under its own entry" "$(awk '/ DR[0-9]+ ·/{e=$2} /^  jev/{print e}' "$R/decision-record.md" | tr '\n' ' ')" "DR1 DR2 DR3 "
check "dr-check: the hook message names every entry checked" "$(printf '%s\n' "$ctx" | grep -o 'ATL-42 DR[0-9]' | tr '\n' ' ')" "ATL-42 DR1 ATL-42 DR2 ATL-42 DR3 "
two 4 "alert after the third retry"
check "dr-check: a later write checks only the new entry" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -o 'ATL-42 DR[0-9]' | tr '\n' ' '; grep -c '^  jev' "$R/decision-record.md")" "ATL-42 DR4 4"
# --audit and the ready-for-push gate: a jev line with no receipt behind it
rfp="$(printf '"x · STOP 2 · ready for push\\n  files record %s/"' "$R")"
check "dr-check: --audit passes when every jev line has its receipt" "$(python3 "$HERE/dr_check.py" "$R/decision-record.md" --audit; echo "rc=$?")" "rc=0"
check "ic: ready for push with every jev line backed has no jev gate" "$(send "$I" "$rfp" | grep -c 'JEV RECEIPT GATE')" 0
two 5 "skip the alert"; printf '  jev         continue, max yes 0.01 · jev-stub\n' >> "$R/decision-record.md"
check "dr-check: --audit names a hand-written jev line, exit 1" "$(python3 "$HERE/dr_check.py" "$R/decision-record.md" --audit | grep -c '^ATL-42 DR5: jev'; python3 "$HERE/dr_check.py" "$R/decision-record.md" --audit >/dev/null; echo "rc=$?")" "1
rc=1"
check "ic: ready for push with a hand-written jev line denied" "$(send "$I" "$rfp" | grep -c 'JEV RECEIPT GATE: ATL-42 DR5')" 1
check "ic: a STOP 1 message is not jev-gated" "$(send "$I" "$(printf '"x · STOP 1 · y\\n  files record %s/"' "$R")" | grep -c 'JEV RECEIPT GATE')" 0
check "dr-check: a write elsewhere is ignored" "$(dr "$I" /repo/docs/adr/x.md "$T/stub-ok.json" | wc -c | tr -d ' ')" 0
check "dr-check: lead not checked" "$(dr "$L" "$R/decision-record.md" "$T/stub-ok.json" | wc -c | tr -d ' ')" 0
entry "wrap scheduler.nightly()"
check "dr-check: --dump keys name kind and line" "$(dump | jq -r '.request.body.questions | keys | join(" ")')" "decided-8 oneway-5 rejected-11 standing-1 standing-2"
check "dr-check: --dump state is the entry's fields, no owner" "$(dump | jq -r '.request.body.state | keys | join(" ")')" "because decided plan question undo"
check "dr-check: a rule that starts with a number keeps it; a row number is cut" "$(python3 -c 'import sys; sys.path.insert(0, "'"$HERE"'"); from dr_check import rule_text as r; print(r("  3 retries then alert   [brief 3]"), "|", r("  2  3 retries then alert   retry.py   [brief 3]"), "|", r("  ✔ 2  3 retries then alert   [brief 3]"))')" "3 retries then alert | 3 retries then alert | 3 retries then alert"
check "dr-check: --dump writes nothing" "$(grep -c '^  jev' "$R/decision-record.md")" 0
check "dr-check: --dump question reads as a sentence" "$(dump | jq -r '.request.body.questions["decided-8"].instructions' | grep -c '^It was decided earlier: the retry wraps the scheduler call, never importer.run(). Does the `decided` field go against that')" 1
check "dr-check: DR_STANDING=lines asks each standing line" "$(DR_STANDING=lines dump | jq -r '.request.body.questions | keys | join(" ")')" "decided-8 oneway-5 rejected-11 standing-4"
printf '# ATL-42 rung 1 · decision record · test-ic\n\nATL-42 UAT1 · 2026-10-08 12:00 · test-ic\n  words       "push it" (test-ic pane, 11:59)\n  done        pushed feat/atl-42\n  commit      abc\n  undo        git push --delete origin feat/atl-42\n' > "$R/decision-record.md"
check "dr-check: a UAT entry's words count as the owner's word" "$(dr "$I" "$R/decision-record.md" "$T/stub-push.json" >/dev/null; grep -c '^  jev         continue, standing-1 with the owner.s word' "$R/decision-record.md")" 1
R2="$T/records/atlas/atl-42-r2"; mkdir -p "$R2"; entry "wrap scheduler.nightly()"; cp "$R/decision-record.md" "$R2/"
printf 'rules · ATL-42 r2 · frozen at 9b2e7c1\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n\nDECIDED  never change:\n  ✔ 1  run it from cron   retry.py, new   [brief 3] [retired 2026-10-20 by 11]\n  ✔ 2  the retry wraps the scheduler call   retry.py   [brief 3] [retired 2026-10-20 by 99]\n\nDECIDED  amended 2026-10-20:\n  ✔ 3  run it from the nightly job   [card ATL-42 C2]\n' > "$R2/rules.md"
dump2(){ JEV_ENV="$T/nokey" python3 "$HERE/dr_check.py" "$R2/decision-record.md" --dump; }
check "dr-check: a retired row is not asked; the amended line is" "$(dump2 | jq -r '.request.body.questions | keys | join(" ")')" "decided-11 decided-8 standing-1 standing-2"
check "dr-check: --dump lists the retired row with its date and line" "$(dump2 | jq -c '.lines_retired[0] | [.line, .on, .by]')" "[7,\"2026-10-20\",11]"
check "dr-check: a tag naming no live line is ignored, the row still asked" "$(dump2 | jq -r '.lines_retired[1].ignored')" "no live rule at line 99; still asked"
rm -rf "$R/receipts"; entry "wrap scheduler.nightly()"
printf '{"model":"jev-stub","answers":{"standing-1":{"type":"noul","noul":0.05},"standing-2":{"type":"noul","noul":0.03},"oneway-5":{"type":"noul","noul":0.08}}}' > "$T/stub-short.json"
check "dr-check: a missing score is an error, never 0.0" "$(dr "$I" "$R/decision-record.md" "$T/stub-short.json" >/dev/null; grep -c '^  jev         stop and ask, no check (missing answers decided-8, rejected-11)$' "$R/decision-record.md")" 1
check "dr-check: the missing-score receipt names the gap" "$(jq -r '.error' "$(ls -t "$R"/receipts/*.json | head -1)")" "no noul score for 2 of 5 keys"
rm -rf "$R/receipts"; entry "wrap scheduler.nightly()"
check "dr-check: each call leaves a receipt next to the record" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c 'Receipt: .*/receipts/.*-jev-DR1.json')" 1
rcpt="$(ls -t "$R"/receipts/*-jev-DR1.json | head -1)"
check "dr-check: the receipt carries the request as sent" "$(jq -r '.request.body.state.decided' "$rcpt")" "wrap scheduler.nightly()"
check "dr-check: the receipt carries the response and the verdict" "$(jq -r '[.response.model, .verdict] | join(" / ")' "$rcpt")" "jev-stub / continue, max yes 0.08 · jev-stub"
check "dr-check: the receipt never holds the key" "$(grep -c 'not written here' "$rcpt")" 1
entry "wrap scheduler.nightly()"
check "dr-check: a receipt is never overwritten" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; ls "$R"/receipts/*-jev-DR1*.json | wc -l | tr -d ' ')" 2
entry "wrap scheduler.nightly()" '    with a human watching [cli.py line 40]\n'
check "dr-check: a wrapped line is named, not read" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c 'Not read (a field is one line): line 9 "with a human watching')" 1
check "dr-check: the wrapped line is not in the state" "$(dump | jq -r '.request.body.state.because + " · " + (.lines_not_read | length | tostring)')" "x · 1"
rm -rf "$R/receipts"; entry "wrap scheduler.nightly()"; printf 'KEY=test-only\n' > "$T/key"
check "dr-check: a failed call is stop and ask, no check, with the error type" "$(printf '{"cwd":"%s","session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$I" "$S" "$R/decision-record.md" | JEV_ENV="$T/key" JEV_URL="http://127.0.0.1:9/" "$HERE/dr-check.sh" >/dev/null 2>&1; grep -c '^  jev         stop and ask, no check (error URLError)$' "$R/decision-record.md")" 1
check "dr-check: the call-error receipt holds the error, never the key" "$(f="$(ls -t "$R"/receipts/*.json | head -1)"; jq -r '.error' "$f" | cut -c1-9; grep -c test-only "$f")" "URLError:
0"
rm -rf "$R/receipts"; entry "wrap scheduler.nightly()"
rm "$R/rules.md"; entry "anything"
check "dr-check: no rules.md before the freeze" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         no rules.md' "$R/decision-record.md")" 1
rm -rf "$T/records"
check "lead: send not gated" "$(printf '{"cwd":"%s","session_id":"%s","tool_name":"SendMessage","tool_input":{"message":%s}}' "$L" "$S" "$long" | "$HERE/message-gate.sh" 2>/dev/null | wc -c | tr -d ' ')" 0
check "garbage stdin exits 0" "$(echo garbage | "$HERE/artefact-gate.sh" 2>/dev/null; echo $?)" 0
# stale markers: a skill file newer than the marker means the skill changed after this session read it
S=stale; mkdir -p "$T/checks/test-ic/skills/$S" "$T/checks/lead-1/skills/$S"
mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null; touch -t 202001010000 "$T/checks/test-ic/skills/$S/reporting-a-rung"; touch "$T/skills/reporting-a-rung/SKILL.md"
check "ic: STOP bounces on a stale marker" "$(stop "$I" '"x · STOP 2 · y"')" 2
check "ic: the bounce says changed, not not-invoked" "$(printf '{"cwd":"%s","session_id":"%s","last_assistant_message":"x · STOP 2 · y","stop_hook_active":false}' "$I" "$S" | "$HERE/stop-skill-gate.sh" 2>&1 >/dev/null | grep -c 'changed since this session read it')" 1
check "ic: STOP send denied on a stale marker" "$(send "$I" '"x · STOP 2 · y"' | grep -c 'changed since')" 1
mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null
check "ic: STOP passes once re-invoked" "$(stop "$I" '"x · STOP 2 · y"')" 0
mark "$I" Skill '{"skill":"closing-a-rung"}' >/dev/null; touch -t 202001010000 "$T/checks/test-ic/skills/$S/closing-a-rung"; touch "$T/skills/foundations/decision-card.md"
check "ic: a foundations change stales every skill" "$(stop "$I" '"close · x"')" 2
check "ic: boot on resume lists the stale skill" "$(printf '{"cwd":"%s","session_id":"%s","source":"resume"}' "$I" "$S" | "$HERE/skill-boot.sh" 2>/dev/null | grep -c 'CHANGED since.*closing-a-rung')" 1
mark "$L" Skill '{"skill":"writing-a-rung-handoff"}' >/dev/null; touch -t 202001010000 "$T/checks/lead-1/skills/$S/writing-a-rung-handoff"; touch "$T/skills/writing-a-rung-handoff/SKILL.md"
check "lead: handoff write denied on a stale marker" "$(gate "$L" /Use""rs/robin/.fleet-agent-mgmt/records/atlas/atl-42-r1/handoff.md)" deny
mark "$L" Skill '{"skill":"agent-haiku"}' >/dev/null 2>&1; touch -t 202001010000 "$T/checks/lead-1/skills/$S/agent-haiku" 2>/dev/null
check "lead: a marker with no skill dir cannot go stale" "$([ -f "$T/checks/lead-1/skills/$S/agent-haiku" ] && printf '{"cwd":"%s","session_id":"%s"}' "$L" "$S" | (. "$HERE/skill-lib.sh"; has agent-haiku && echo ok || echo stale) || echo nomarker)" ok

# freeze-rules.sh: rules.md from the committed spec, byte for byte, under the spec's sha
F="$T/freeze"; mkdir -p "$F/repo/docs" "$F/records/atlas/atl-42-r1"
sed -n '/^# ATL-42: /,$p' "$HERE/../skills/writing-a-design-spec/templates/design-spec.md" > "$F/repo/docs/atl-42-spec.md"   # the template, its comment deleted
sed -n '/^# ATL-42 rung/,/^plan:/p' "$HERE/../skills/recording-a-decision/templates/decision-record.md" > "$F/records/atlas/atl-42-r1/decision-record.md"
(cd "$F/repo" && git init -q && git add . && git -c user.name=t -c user.email=t@t commit -qm spec)
ap(){ git -C "$F/repo" log -1 --format=%h -- "docs/$1"; }   # the approved sha: the spec's last commit
# the owner's word: one user entry in the session log folder of <cwd> under <root>, the shape Claude Code writes
cat > "$T/olog.py" <<'EOF'
import json, os, sys, time
shared, root, cwd, kind, local, text = sys.argv[1:7]
sys.path.insert(0, shared); import freeze_rules as f
d = os.path.join(root, f.log_slug(os.path.realpath(cwd))); os.makedirs(d, exist_ok=True)
ts = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(time.mktime(time.strptime(local, "%Y-%m-%d %H:%M"))))
o = {"kind": kind} if kind != "peer" else {"kind": "peer", "name": "lead-1"}
e = {"type": "user", "message": {"role": "user", "content": text}, "origin": o, "promptSource": "typed" if kind == "human" else "system",
     "timestamp": ts, "cwd": cwd, "sessionId": "t"}
with open(os.path.join(d, "t.jsonl"), "a") as fh:
    fh.write(json.dumps(e) + "\n")
EOF
# the freeze with its session-log root and lead-1's folder set from python, never from the environment
cat > "$T/fzh.py" <<'EOF'
import sys
shared, root, lead = sys.argv[1:4]
sys.path.insert(0, shared); import freeze_rules as f
f.SESSION_LOGS, f.LEAD_CWD = root, lead
sys.exit(f.main(["freeze_rules.py"] + sys.argv[4:]))
EOF
OL="$T/projects"   # the session logs the test freeze reads
olog(){ python3 "$T/olog.py" "$HERE/../records" "${OLR:-$OL}" "$1" "$2" "$3" "$4"; }   # <cwd> human|peer <local time> <text>
rn(){ local b; b="$(basename "$1")"; printf '%s %s' "$(printf '%s' "${b%-r*}" | tr a-z A-Z)" "${b##*-}"; }   # atl-42-r1 -> ATL-42 r1
# the message gate's line at STOP 1, and the owner's "<lane> r<n> spec ok" typed in the IC's pane two minutes later
lg(){ mkdir -p "$1"; printf '2026-10-14 10:00 · STOP 1 · spec %s @ %s · test-ic · session s1\n' "$2" "$(git -C "$F/repo" rev-parse "$3")" >> "$1/stop1.log"
  [ -n "${NOOWN:-}" ] || olog "$F/repo" human "2026-10-14 10:02" "$(rn "$1") spec ok"; }
fz(){ local rec="" a="" p="" x; [ "${2:-}" != "${2#--}" ] || rec="${2:-}"; for x in "$@"; do [ "$p" = --approved ] && a="$x"; p="$x"; done
  [ -z "${NOLOG:-}" ] && [ -n "$a" ] && [ -n "$rec" ] && [ "${rec#\~}" = "$rec" ] && git -C "$F/repo" rev-parse -q --verify "$a^{commit}" >/dev/null 2>&1 && lg "$rec" "$1" "$a"
  (cd "$F/repo" && python3 "$T/fzh.py" "$HERE/../records" "$OL" "$L" "$@" 2>&1; echo "rc=$?"); }
RU="$F/records/atlas/atl-42-r1/rules.md"; RF="$F/records/atlas/atl-42-r1"
check "the design-spec template, its comment deleted, passes the leak check" "$(python3 "$HERE/leak_check.py" --doc "$F/repo/docs/atl-42-spec.md" --path /repo/docs/specs/atl-42.md; echo "rc=$?")" rc=0
echo x >> "$F/repo/docs/atl-42-spec.md"
check "freeze: a spec with uncommitted changes is refused" "$(fz docs/atl-42-spec.md "$RF" --approved "$(ap atl-42-spec.md)" | tail -1)" rc=2
check "freeze: nothing is written on a refusal" "$([ -f "$RU" ] && echo written || echo none)" none
(cd "$F/repo" && git checkout -q docs/atl-42-spec.md)
check "freeze: --dump writes nothing" "$(fz docs/atl-42-spec.md "$RF" --approved "$(ap atl-42-spec.md)" --dump >/dev/null; [ -f "$RU" ] && echo written || echo none)" none
sha="$(cd "$F/repo" && git log -1 --format=%h -- docs/atl-42-spec.md)"
check "freeze: writes and exits 0" "$(fz docs/atl-42-spec.md "$RF" --approved "$(ap atl-42-spec.md)" | tail -1)" rc=0
mkdir -p "$F/home"; lg "$F/home/records/atlas/atl-42-r2" docs/atl-42-spec.md "$(ap atl-42-spec.md)"
check "freeze: a record folder given with ~ lands under HOME, not in the worktree" "$(cd "$F/repo" && HOME="$F/home" python3 "$T/fzh.py" "$HERE/../records" "$OL" "$L" docs/atl-42-spec.md '~/records/atlas/atl-42-r2' --approved "$(ap atl-42-spec.md)" >/dev/null 2>&1; [ -f "$F/home/records/atlas/atl-42-r2/rules.md" ] && [ ! -e "$F/repo/~" ] && echo ok || echo miss)" ok
check "freeze: the header names the lane, the rung and the spec's commit" "$(grep -c "^rules · ATL-42 r1 · frozen at $sha · 20" "$RU")" 1
check "freeze: TERMS comes first" "$(sed -n 3p "$RU")" "TERMS"
check "freeze: the standing block follows TERMS" "$(sed -n 7p "$RU")" "ONE-WAY  stop and ask before:"
NS="$(sed -n '/^```$/,/^```$/p' "$HERE/../skills/foundations/one-way.md" | grep -c '\[standing\]$')"
check "freeze: every standing line of one-way.md, verbatim" "$(sed -n "8,$((7+NS))p" "$RU" | grep -c -x -F -f <(sed -n '/^```$/,/^```$/p' "$HERE/../skills/foundations/one-way.md" | grep '\[standing\]$'))" "$NS"
check "freeze: every row of the Terms table and the three rule tables lands on one rules.md line, cells in order" "$(python3 - "$F/repo/docs/atl-42-spec.md" "$RU" <<'EOF'
import re, sys
spec, rules = open(sys.argv[1]).read().split("\n---\n")[0], open(sys.argv[2]).read().split("\n")
n = miss = 0
for blk in re.findall(r"^## (?:Terms|One-way|Decided|Rejected)\n\n((?:\|.*\n)+)", spec, re.M):
    for row in blk.strip().split("\n")[2:]:
        cs = [c.strip() for c in row.strip("|").split("|")]
        pat = r"\s+".join(re.escape(c) for c in cs).replace(re.escape(cs[-1]), r"\[?" + re.escape(cs[-1]) + r"\]?")
        n += 1; miss += not any(re.fullmatch(r"  " + pat, l.rstrip()) for l in rules)
print(f"{n}:{miss}")
EOF
)" "8:0"
check "freeze: a source cell is bracketed in rules.md" "$(grep -c -x -E '  run anything against the shared dev database +\[ATL-42\]' "$RU")" 1
GT="$F/records/atlas/atl-42-r1/gate.md"
check "freeze: gate.md from the Checks table, the on main column dropped" "$(grep -c 'red, this change builds it\|212 passed' "$GT"):$(grep -c '^  proves done   make test$' "$GT")" "0:1"
check "freeze: gate_run reads the Checks table's 2 commands and 2 pass lines" "$(python3 -c "import sys; sys.path.insert(0,'$HERE/../records'); import gate_run as g; c,p=g.read_gate(open('$GT').read()); print(len(c), len(p), c[1])")" "2 2 make import-dry-run FILE=tests/fixtures/bad.csv"
check "golden: freezing the design-spec template reproduces testdata rules.md and gate.md byte for byte, header line excluded" "$(cmp -s <(tail -n +2 "$RU") "$TD/testdata/design-spec.rules.md" && cmp -s <(tail -n +2 "$GT") "$TD/testdata/design-spec.gate.md" && echo same || echo differs)" same
tspec(){ printf '# ATL-42: t\n\n**Problem:** p\n\n**Verdict:** v\n\n## Terms\n\n| name | what it is |\n|---|---|\n| a | b |\n\n## Rejected\n\n| do not come back to | source |\n|---|---|\n| x | INC-1 |\n\n## One-way\n\n| stop and ask before | source |\n|---|---|\n| y | ATL-42 |\n\n## Decided\n\n| # | never change | source |\n|---|---|---|\n| 1 | z | ATL-42 |\n\n## Checks\n\n%s\n\n---\n' "$(printf '%b' "$1")" > "$F/repo/docs/$2"; (cd "$F/repo" && git add "docs/$2" && git -c user.name=t -c user.email=t@t commit -qm "$2"); }
tspec '| command | pass | on main |\n|---|---|---|\n| `grep -c x a.log \\| head -1` | exit 0 | exit 0 |' t-pipe.md
check "freeze: a \\| in a Checks cell is a pipe in gate.md, the backticks dropped" "$(fz docs/t-pipe.md "$F/records/atlas/atl-42-r4" --approved "$(ap t-pipe.md)" | tail -1; grep -c -x -F '  proves done   grep -c x a.log | head -1' "$F/records/atlas/atl-42-r4/gate.md")" "rc=0
1"
tspec '| command | pass |\n|---|---|\n| `make test` | exit 0 |' t-nomain.md
check "freeze: a Checks table with no on main column is refused" "$(fz docs/t-nomain.md "$F/records/atlas/atl-42-r5" --approved "$(ap t-nomain.md)" | tail -2 | tr '\n' ' ')" "freeze-rules: checks table has no on main column rc=2 "
tspec '| command | pass | on main |\n|---|---|---|\n| `make test` | exit 0 |' t-short.md
check "freeze: a table row with a missing cell is refused, nothing written" "$(fz docs/t-short.md "$F/records/atlas/atl-42-r6" --approved "$(ap t-short.md)" | tail -1; [ -e "$F/records/atlas/atl-42-r6/rules.md" ] && echo written || echo none)" "rc=2
none"
tspec '```\n  proves done   make test\n  pass          exit 0\n  on main       exit 0\n```' t-fence.md
check "freeze: a Checks fence beside rule tables still freezes" "$(fz docs/t-fence.md "$F/records/atlas/atl-42-r7" --approved "$(ap t-fence.md)" | tail -1; grep -c -x -F '  proves done   make test' "$F/records/atlas/atl-42-r7/gate.md")" "rc=0
1"
check "freeze: nothing else is added (header, TERMS, the standing lines, 3 blocks)" "$(wc -l < "$RU" | tr -d ' ')" "$((19+NS))"
check "freeze: the record header carries the sha" "$(grep -c "^rules: $sha  (rules.md, frozen 20" "$F/records/atlas/atl-42-r1/decision-record.md")" 1
check "freeze: a second run is refused, the rules are frozen" "$(fz docs/atl-42-spec.md "$RF" --approved "$(ap atl-42-spec.md)" | tail -1)" rc=2
check "freeze: dr-check reads every standing line and 6 rung lines, TERMS ignored" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; rs=d.read_rules(open('$RU').read()); n=sum(r.standing for r in rs); print(n, len(rs)-n)")" "$NS 6"
printf '# ATL-42 · retry\nrecord: %s/records/atlas/atl-42-r3/\n\nTERMS  (words)\n  nightly()   the 01:00 import call\n\nONE-WAY  stop and ask before:\n  run anything against the shared dev database   [ATL-42]\n\nDECIDED  never change:\n  1  retry 3 times   retry.py, new   [ATL-42]\n\nREJECTED  do not come back to:\n  retry forever   [INC-118]\n\n---\n' "$F" > "$F/repo/docs/atl-42-old.md"
(cd "$F/repo" && git add docs/atl-42-old.md && git -c user.name=t -c user.email=t@t commit -qm old)
lg "$F/records/atlas/atl-42-r3" docs/atl-42-old.md "$(ap atl-42-old.md)"
check "freeze: a spec in the old shape, folder on its record: line, still freezes" "$(fz docs/atl-42-old.md --approved "$(ap atl-42-old.md)" | tail -1; grep -c -x -F -e '  1  retry 3 times   retry.py, new   [ATL-42]' -e '  retry forever   [INC-118]' "$F/records/atlas/atl-42-r3/rules.md")" "rc=0
2"
# freeze_rules.py --check and the readers: one check per hole closed (ids from the freeze hole hunt)
FZ="$HERE/../records/freeze_rules.py"; SP="$F/repo/docs/atl-42-spec.md"
vr(){ n="$1"; shift; python3 - "$SP" "$F/v-$n.md" "$@" <<'EOF'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = sys.argv[3:]
for old, new in zip(a[::2], a[1::2]):
    old, new = old.replace("\\n", "\n"), new.replace("\\n", "\n")
    if t.count(old) != 1:
        sys.exit(f"vr: {old!r} found {t.count(old)} times")
    t = t.replace(old, new)
open(sys.argv[2], "w", encoding="utf-8").write(t)
EOF
}
ckr(){ o="$(python3 "$FZ" --check "$@" 2>/dev/null)"; rc=$?; printf '%s:rc=%s' "$(printf '%s\n' "$o" | grep -c -F -- "${PAT:-.}")" "$rc"; }
ck(){ f="$1"; PAT="$2"; shift 2; ckr "$f" "$@"; }
rq(){ python3 -c "
import sys; sys.path[:0] = ['$HERE/../records', '$HERE']; import freeze_rules as f, dr_check as d
p = f.parse(open(sys.argv[1], encoding='utf-8').read())
out = ['rules · x', ''] + p['blocks']['TERMS'] + [''] + f.standing_block() + ['']
for b in p['order']: out += p['blocks'][b] + ['']
print('|'.join(r.text for r in d.read_rules('\n'.join(out)) if r.section == sys.argv[2] and not r.standing))" "$1" "${2:-DECIDED}" 2>&1; }
gr(){ python3 -c "
import sys; sys.path.insert(0, '$HERE/../records'); import gate_run as g
p = []; c, q = g.read_gate(sys.argv[1].replace('\\\\n', '\n'), p); print(len(c), len(q), len(p))" "$1"; }
pl(){ python3 -c "import sys; sys.path.insert(0, '$HERE/../records'); import gate_run as g; print(g.passes_line(sys.argv[1], 0, sys.argv[2]))" "$1" "$2"; }
pp(){ python3 -c "import sys; sys.path.insert(0, '$HERE/../records'); import gate_run as g; print(len(g.pass_problems(sys.argv[1])))" "$1"; }
DEC='| # | never change | lands in | source |\n|---|---|---|---|\n| 1 | retry 3 times, backoff 1m 5m 15m, then alert | retry.py, new | product owner, ATL-42, 2026-09-14 |\n| 2 | nightly imports only; the CLI import is unchanged | scheduler.py, modify | ATL-42, definition of done |'
check "A: --check passes the design-spec template, exit 0" "$(ck "$SP" x)" "0:rc=0"
check "A: --check reads the spec from stdin" "$(python3 "$FZ" --check - --path docs/atl-42-spec.md < "$SP"; echo "rc=$?")" "rc=0"
check "A: --check with a CRLF spec reads the same, exit 0" "$(perl -pe 's/\n/\r\n/' "$SP" > "$F/v-crlf.md"; ck "$F/v-crlf.md" x)" "0:rc=0"
check "A: --check with no argument prints usage, exit 2" "$(python3 "$FZ" --check >/dev/null; echo "rc=$?")" "rc=2"
vr p1c "## Decided\n\n" '<!--\n## Decided\n\n| # | never change | source |\n|---|---|---|\n| 1 | unseen | x |\n-->\n\n## Decided\n\n'
check "parser-1: a block heading inside an HTML comment refused" "$(ck "$F/v-p1c.md" 'inside an HTML comment')" "1:rc=2"
vr p1f "## Terms" '```\n## Decided\n| # | never change | source |\n```\n\n## Terms'
check "parser-1: a block heading inside a fence is not a heading, the visible block is frozen" "$(ck "$F/v-p1f.md" x; echo; rq "$F/v-p1f.md")" "0:rc=0
retry 3 times, backoff 1m 5m 15m, then alert|nightly imports only; the CLI import is unchanged"
vr p2 "## Direction" "## One-way doors in this design"
check "parser-2: a heading that starts with a block name and has more words refused" "$(ck "$F/v-p2.md" 'is not read as `## One-way` (it has more words')" "1:rc=2"
vr p2c "## Decided" "## decided"
check "parser-2: a block heading in another case refused" "$(ck "$F/v-p2c.md" 'the case differs')" "1:rc=2"
vr p3b "2026-09-14 |\n| 2 |" "2026-09-14 |\n\n| 2 |"
check "parser-3: rows after a blank line refused" "$(ck "$F/v-p3b.md" 'follows the table and would not be frozen')" "1:rc=2"
vr p3l "2026-09-14 |\n| 2 |" "2026-09-14 |\n2 |"
check "parser-3: a row with no leading pipe refused" "$(ck "$F/v-p3l.md" 'follows the table and would not be frozen')" "1:rc=2"
vr p3t "definition of done |\n" 'definition of done |\n\n```\n  3  alerts go to ops only\n```\n'
check "parser-3: a fence after the table refused" "$(ck "$F/v-p3t.md" 'follows the table')" "1:rc=2"
vr p4 "## Building" '## Decided\n\n| # | never change | source |\n|---|---|---|\n| 3 | alerts go to ops only | ATL-42 |\n\n## Building'
check "parser-4: a second heading for the same block refused" "$(ck "$F/v-p4.md" 'appears twice in screen one')" "1:rc=2"
check "parser-5: a continuation that starts with a label word stays a continuation" "$(gr 'GATE BLOCK\n  proves done   true\n                passcheck\n  pass          exit 0\n                records "zzz" written\n')" "2 2 0"
check "parser-5: a label needs two spaces after it, else gate_run names the line" "$(gr 'GATE BLOCK\n  proves done true\n  pass          exit 0\n')" "0 1 1"
vr p6 "| command | pass | on main |" "| command | pass | proves done |"
check "parser-6: a Checks table with the same column twice refused" "$(ck "$F/v-p6.md" 'are the same column')" "1:rc=2"
vr p6b "| command | pass | on main |" "| command | pass | pass |"
check "parser-6: a duplicated column name refused" "$(ck "$F/v-p6b.md" 'two `pass` columns')" "1:rc=2"
vr p7h "## Checks" "### Checks"
check "parser-7: a Checks heading at ### refused" "$(ck "$F/v-p7h.md" 'level-3 heading')" "1:rc=2"
vr p7s "## Checks" "## Check"
check "parser-7: a new-shape spec with no Checks block refused, never frozen without gate.md" "$(ck "$F/v-p7s.md" 'no `## Checks` block')" "1:rc=2"
vr p7f "\n\n## Checks" '\n\nRun once on main before review\n---\n\n## Checks'
check "parser-7: a fold right under a text line refused" "$(ck "$F/v-p7f.md" 'heading underline')" "1:rc=2"
vr p8 "$DEC" '| lands in | # | never change | source |\n|---|---|---|---|\n| retry.py | D1 | retry 3 times | ATL-42 |\n| cli.py | 2. | 3  attempts on the CLI too | ATL-42 |'
check "parser-8: an id column and a rule column not first: dr-check asks the rule cell" "$(rq "$F/v-p8.md")" "retry 3 times|3 attempts on the CLI too"
check "parser-8: rules.md puts the id, then the rule, then the other cells, then [source]" "$(ck "$F/v-p8.md" x; python3 -c "import sys; sys.path.insert(0,'$HERE/../records'); import freeze_rules as f; print(f.parse(open('$F/v-p8.md').read())['blocks']['DECIDED'][1])")" "0:rc=0  D1  retry 3 times              retry.py  [ATL-42]"
vr p9 "retry 3 times, backoff" "retry 3 times,  backoff"
check "parser-9: two spaces inside a rule cell: the whole cell is asked" "$(rq "$F/v-p9.md" | cut -d'|' -f1)" "retry 3 times, backoff 1m 5m 15m, then alert"
check "consumers-7: two spaces inside a cell collapse to one in rules.md" "$(python3 -c "import sys; sys.path.insert(0,'$HERE/../records'); import freeze_rules as f; print(f.parse(open('$F/v-p9.md').read())['blocks']['DECIDED'][1].count('times,  backoff'))")" "0"
vr p10c "$DEC" '```\nnever change:\n  1  retry 3 times\n  2  nightly imports only\n```'
check "parser-10: a fence caption is the heading, never a rule" "$(rq "$F/v-p10c.md")" "retry 3 times|nightly imports only"
vr p10w "$DEC" '```\n  1  retry 3 times, backoff 1m 5m 15m,\n     then alert\n```'
check "parser-10: a wrapped rule in a fence refused" "$(ck "$F/v-p10w.md" 'indented deeper than the row above it')" "1:rc=2"
OS="$F/repo/docs/atl-42-old.md"; O1='  1  retry 3 times   retry.py, new   [ATL-42]\n'
SP="$OS" vr o1 "$O1" "$O1"'\n  2  nightly only   [ATL-42]\n'
check "parser-11: old shape, a block line after a blank line refused" "$(ck "$F/v-o1.md" 'would not be frozen')" "1:rc=2"
SP="$OS" vr o2 "$O1" "$O1"$'\t''2  nightly only   [ATL-42]\n'
check "parser-11: old shape, a tab-indented block line refused" "$(ck "$F/v-o2.md" 'would not be frozen')" "1:rc=2"
SP="$OS" vr o3 "$O1" "$O1"' 2  nightly only   [ATL-42]\n'
check "parser-11: old shape, a one-space block line refused" "$(ck "$F/v-o3.md" 'would not be frozen')" "1:rc=2"
check "parser-11: old shape, the unchanged spec still passes" "$(ck "$OS" x)" "0:rc=0"
vr p12 "| ATL-42 |\n\n## Decided" "| retired 2026-10-01 by 7 |\n\n## Decided"
check "parser-12: a source cell starting retired refused" "$(ck "$F/v-p12.md" 'reads as a rules.md tag')" "1:rc=2"
vr p12b "| ATL-42, definition of done |" "| ATL-42 [retired 2026-10-01 by 7] |"
check "parser-12: a [retired tag in any cell refused" "$(ck "$F/v-p12b.md" 'holds `[standing]` or `[retired`')" "1:rc=2"
mkdir -p "$F/g1"; printf 'gate · x\n\nGATE BLOCK\n  proves done   true\n                true\n  pass          exit 0\n' > "$F/g1/gate.md"; seal "$F/g1"
check "consumers-1: gate_run refuses fewer pass lines than commands, exit 2, no receipt" "$(python3 "$HERE/../records/gate_run.py" "$F/g1" "$F/g1/r.md" "$F/g1/r.log" now abc 0 "$F" | grep -c '2 commands and 1 pass lines'; echo "rc=${PIPESTATUS[0]}"; [ -e "$F/g1/r.md" ] && echo receipt || echo none)" "1
rc=2
none"
vr c2 '| exit 0, "0 failed" in the summary line |' '| exit code 2, "0 failed" in the summary line |'
check "consumers-2: the freeze refuses an exit code not worded exit N" "$(ck "$F/v-c2.md" 'names an exit code another way')" "1:rc=2"
check "consumers-2: gate_run names exits 1 and exit status 1 as problems" "$(pp 'exits 1'):$(pp 'exit status 1, "x"'):$(pp 'exit 0; git diff --exit-code is clean')" "1:1:0"
vr c3 '"0 failed"' '“0 failed”'
check "consumers-3: the freeze refuses curly quotes in a pass cell" "$(ck "$F/v-c3.md" 'curly quotes')" "1:rc=2"
check "consumers-3: a curly-quoted string is still checked, red when missing" "$(pl 'exit 0, “done”' 'nope')" "False"
vr c4 '| exit 0, "0 failed" in the summary line |' '| exit 0, no "ERROR" or "FAILED" |'
check "consumers-4: the freeze refuses an absent clause naming two strings" "$(ck "$F/v-c4.md" 'more than one string')" "1:rc=2"
check "consumers-4: no \"a\", no \"b\" is red when the second is present" "$(pl 'exit 0, no "ERROR", no "FAILED"' 'FAILED')" "False"
check "consumers-4: piano \"tuned\" is a required string, not an absent one" "$(pl 'exit 0, piano "tuned"' 'untuned'):$(pl 'exit 0, piano "tuned"' 'it is tuned')" "False:True"
check "consumers-5: \"0 failed\" does not match 10 failed" "$(pl 'exit 0, "0 failed"' '212 passed, 10 failed'):$(pl 'exit 0, "0 failed"' '212 passed, 0 failed')" "False:True"
vr c6 "| 1 | retry" "| 1. | retry" "| 2 | nightly" "| D2 | nightly"
check "consumers-6: a # cell written 1. or D2: dr-check asks the rule" "$(rq "$F/v-c6.md")" "retry 3 times, backoff 1m 5m 15m, then alert|nightly imports only; the CLI import is unchanged"
vr c6b "| 1 | retry" "| first | retry"
check "consumers-6: a # cell that is not a row number refused" "$(ck "$F/v-c6b.md" 'is not a row number')" "1:rc=2"
vr c8 "| run anything against the shared dev database | ATL-42 |" '| run anything against the shared dev database | ATL-42 |\n| write to the ops channel | standing |'
check "consumers-8: a source cell reading standing refused" "$(ck "$F/v-c8.md" 'reads as a rules.md tag')" "1:rc=2"
check "consumers-8: a [standing] tag on a rung row is asked as that row" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; rs=d.read_rules('rules · x\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n\nONE-WAY  stop and ask before:\n  write to the ops channel   [standing]\n'); print(' '.join(q.key for q in d.questions_for(rs)))")" "standing-1 standing-2 oneway-7"
vr c9 "definition of done |\n" 'definition of done |\n\nAdded after the second review:\n\n| # | never change | source |\n|---|---|---|\n| 3 | alerts go to ops only | ATL-42 |\n'
check "consumers-9: a second table after prose under one heading refused" "$(ck "$F/v-c9.md" 'follows the table')" "1:rc=2"
check "consumers-10: every standing line of one-way.md is held by a named question or check" "$(python3 -c "
import re, sys; sys.path.insert(0,'$HERE'); import dr_check as d
lines = [d.rule_text(l) for l in open('$HERE/../skills/foundations/one-way.md').read().split('\n') if l.rstrip().endswith('[standing]')]
print(len([l for l in lines if l not in d.STANDING_COVER]), len([k for k in d.STANDING_COVER if k not in lines]))")" "0 0"
check "consumers-10: standing-2 asks about writing over another person's or worktree's state" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; print(d.STANDING['standing-2'][1].count('another person or worktree wrote'))")" "1"
check "consumers-10b: standing-1 and standing-2 both carve out the rung's own branch push and draft PR" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; print(sum(d.STANDING[k][1].count('Pushing the agent\'s own feature branch') for k in ('standing-1','standing-2')))")" "2"
check "consumers-11: a # Amended line below GATE BLOCK is a comment, not a command or pass line" "$(gr 'GATE BLOCK\n  proves done   true\n# Amended 2026-10-20 by lead-1: line 2\n                true\n  pass          exit 0\n  # Amended again\n                exit 0\n')" "2 2 0"
R12='rules · x\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n\nDECIDED  never change:\n  1  run it from cron   [brief] [retired 2026-10-20 by 4]\n  2  wrap the call   [brief] [retired 2026-10-20 by 11]\n\nDECIDED  amended 2026-10-20:\n  3  run it nightly   [card C2]\n'
check "consumers-12: a retired tag naming a standing line is ignored, the row still asked" "$(python3 -c "
import sys; sys.path.insert(0,'$HERE'); import dr_check as d; ret=[]
rs = d.read_rules(sys.argv[1].replace('\\\\n', '\n'), ret); print(' '.join(str(r.line) for r in rs if not r.standing), '|', ret[0].get('ignored'), '|', ret[1].get('by'), ret[1].get('ignored'))" "$R12")" "7 11 | line 4 is not a row under a later \`amended <date>:\` heading; still asked | 11 None"
check "consumers-13: a numbered block's one-space row number is cut too" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; print('|'.join(r.text for r in d.read_rules('rules · x\n\nDECIDED  never change:\n  9  keep the job name\n  10 common/ingester.py unchanged   common   [owner]\n')))")" "keep the job name|common/ingester.py unchanged"
check "consumers-13: a lone rule that starts with a number keeps it" "$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import dr_check as d; print('|'.join(r.text for r in d.read_rules('rules · x\n\nDECIDED  never change:\n  3 retries then alert   [brief]\n')))")" "3 retries then alert"
vr e1 "| retry forever | INC-118, 2026-08-29: would have looped 14 hours |\n| a manual rerun button | ATL-42: nobody watches a button; ops asked for an alert |\n" ""
check "A: a block with a header and no row refused; write none" "$(ck "$F/v-e1.md" 'an empty block is one row `none`')" "1:rc=2"
vr e2 "| retry forever | INC-118, 2026-08-29: would have looped 14 hours |\n| a manual rerun button | ATL-42: nobody watches a button; ops asked for an alert |" "| none | |"
check "A: a none row freezes as none and is not asked" "$(ck "$F/v-e2.md" x):$(rq "$F/v-e2.md" REJECTED)" "0:rc=0:"
vr e3 "## One-way\n\n| stop and ask before | source |\n|---|---|\n| run anything against the shared dev database | ATL-42 |\n| apply migration 0008 to any database but the local dev container (make dev-db) | ATL-42 |\n\n" ""
check "A: a new-shape spec missing a block refused" "$(ck "$F/v-e3.md" 'no `## One-way` block')" "1:rc=2"
check "A: --check --record passes when rules.md and gate.md match the spec" "$(ck "$SP" x --record "$RF")" "0:rc=0"
vr r1 "| 2 | nightly imports only" "| 2 | weekly imports only"
check "A: --check --record names a row that differs from rules.md, both ways" "$(ck "$F/v-r1.md" 'nightly imports only' --record "$RF"):$(ck "$F/v-r1.md" 'weekly imports only' --record "$RF")" "1:rc=2:1:rc=2"
vr r2 '| `make test` |' '| `make test-all` |'
check "A: --check --record names a Checks command that differs from gate.md" "$(ck "$F/v-r2.md" 'gate.md command 1' --record "$RF")" "1:rc=2"
# F3b: one check per lost item restored (ids from the F3a skill audit)
vr l1 '| exit 0, "0 failed" in the summary line |' '| exit 0, 0 failed in the summary line |'
check "lost-1: a Checks pass line with words and no quoted string is refused" "$(ck "$F/v-l1.md" 'words with no "quoted string"')" "1:rc=2"
vr l1b '| exit 0, "0 failed" in the summary line |' '| exit 0 |'
check "lost-1: a pass line of exit 0 alone still passes --check" "$(ck "$F/v-l1b.md" x)" "0:rc=0"
check "lost-1: gate-run still runs a hand-written legacy pass line with words" "$(pp 'exit 0: the common ingester and validator unchanged in every copy')" 0
check "lost-1: the spec skill names the output filter caveat and the pass-line refusal" "$(grep -c -F -e 'so quote "212 passed", not "0 failed"' -e 'The freeze refuses a pass' "$HERE/../skills/writing-a-design-spec/SKILL.md")" 2
check "lost-2: the STOP 1 report template has a card line with its plan task and reply words" "$(grep -c -e '^  card       ? ATL-42 D1 · .* · blocks plan task 1 · .* · reply "ATL-42 D1 b"$' "$HERE/../skills/reporting-a-rung/templates/stop-report.md")" 1
check "lost-2: the check prompt names a missing card line per open item" "$(grep -c -F 'a card line for each item under the spec' "$HERE/../skills/reporting-a-rung/templates/check-prompt.md")" 1
check "lost-3: the handoff template carries the brief and profile one-way acts in §2, one per line" "$(grep -c -e '^  one-way   run anything against the shared dev database  *brief, gate block; profile atlas one-way line$' -e '^            apply migration 0008 anywhere but the sandbox  *brief, this grill Q5$' "$HERE/../skills/writing-a-rung-handoff/templates/handoff.md")" 2
check "lost-3: the spec template has a One-way row for each handoff one-way act" "$(rq "$SP" ONE-WAY | tr '|' '\n' | grep -c -e 'shared dev database' -e 'migration 0008')" 2
check "lost-3: the check prompt asks row or NO ROW for each handoff one-way line" "$(grep -c -F '"row" or "NO ROW"' "$HERE/../skills/reporting-a-rung/templates/check-prompt.md")" 1
check "lost-3: the handoff skill takes the profile's one-way line into §2" "$(grep -c -F 'split at each' "$HERE/../skills/writing-a-rung-handoff/SKILL.md")" 1
check "lost-3: one-way.md says the freeze never reads the profile" "$(grep -c -F 'The freeze never reads the profile' "$HERE/../skills/foundations/one-way.md")" 1
check "lost-4: recording-a-decision gives a spec amendment one entry, and amendments run through amend-frozen.sh" "$(grep -c -F -e '**A spec amendment gets one entry.**' -e 'shared/amend-frozen.sh <record> rules|gate' "$HERE/../skills/recording-a-decision/SKILL.md")" 2
check "lost-5: the STOP 1 report row carries the count with its Terms and Checks parts" "$(grep -c -F '4f1d2c9 · 20 content lines + Terms 2 + Checks 2' "$HERE/../skills/reporting-a-rung/templates/stop-report.md")" 1
check "lost-5: the STOP 1 template spec line passes message-gate's spec-line pattern, nothing after the sha" "$(python3 -c "import re,sys; ls=[l for l in open(sys.argv[1]) if re.match(r'\s*spec\s', l)]; print(len(ls), sum(bool(re.match(r'^\s*spec\s+(\S+)\s+@\s+([0-9a-f]{7,40})\s*$', l)) for l in ls))" "$HERE/../skills/reporting-a-rung/templates/stop-report.md")" "1 1"
check "lost-5: no skill puts the count on the spec line" "$(grep -rn -E -e '@ (<?sha>?|[0-9a-f]{7,40}) (with|\+|·) *(the )?count' -e 'spec +[^ ]+ @ [0-9a-f]{7,40} *[·,+(]' "$HERE/../skills" | grep -c .)" 0
vr nr '| 1 | retry 3 times, backoff 1m 5m 15m, then alert | retry.py, new | product owner, ATL-42, 2026-09-14 |
| 2 | nightly imports only; the CLI import is unchanged | scheduler.py, modify | ATL-42, definition of done |' '| none | | | |'
check "none-row: a Decided row whose only filled cell is none freezes as none" "$(ck "$F/v-nr.md" x):$(rq "$F/v-nr.md" DECIDED)" "0:rc=0:"
check "chain: the handoff template's CHAIN freeze carries --approved" "$(grep -c -F 'freeze-rules.sh <spec path> <record folder> --approved <the STOP 1 sha>' "$HERE/../skills/writing-a-rung-handoff/templates/handoff.md")" 1
check "close: closing-a-rung re-checks the merged spec against the record" "$(grep -c -F 'freeze-rules.sh --check - --path <spec path> --record <record folder>' "$HERE/../skills/closing-a-rung/SKILL.md")" 1
RA="$F/records/atlas/atl-42-r9"; mkdir -p "$RA"; sed 's/\(  2  nightly imports only.*\)$/\1 [retired 2026-10-20 by 99]/' "$RU" > "$RA/rules.md"; printf 'DECIDED  amended 2026-10-20:\n  3  alerts go to ops only  [card ATL-42 C2]\n' >> "$RA/rules.md"
check "A: --check --record accepts retired and amended rows whether or not the spec has them" "$(ck "$SP" x --record "$RA")" "0:rc=0"
mkdir -p "$T/records/orbit/orb-42-r1"
check "A: a record folder in legacy-records.txt is not checked, exit 0" "$(ck "$F/v-p4.md" x --record "$T/records/orbit/orb-42-r1")" "0:rc=0"
check "A: the settings home's legacy-records.txt lists orb-42-r1" "$(grep -c -x 'orbit/orb-42-r1' "$FLEET_HOME/legacy-records.txt")" 1
check "A: the shipped legacy-records.txt has a header and no rows" "$(grep -c -v -e '^#' -e '^[[:space:]]*$' "$TD/../records/legacy-records.txt")" 0
check "A: legacy() reads the settings-home file: a listed folder is legacy, an unlisted one is not" "$(python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; r = f.records_root(); print(f.legacy(r + '/orbit/orb-43-r1'), f.legacy(r + '/orbit/orb-99-r1'))" "$HERE/../records")" "True False"
# push-gate.sh: the IC pushes its own feature branch and opens a draft PR only at a green receipt at HEAD
pg(){ o="$(jq -n --arg c "$1" --arg d "${2:-$I}" --arg s "$S" '{cwd:$d,session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' | "$HERE/push-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
export FLEET_RECORDS="$T/records"; R="$T/records/atlas/atl-42-r1"; mkdir -p "$R/receipts"
printf '# ATL-42 rung 1 · decision record · test-ic\n\nATL-42 DR1 · push · 2026-10-13 10:00 · test-ic\n  plan        6 "push the branch, open the draft PR"\n  decided     push feat/atl-42 and open its draft PR\n  owner       -\n  undo        git push origin --delete feat/atl-42\n' > "$R/decision-record.md"   # its jev line comes from dr-check on a stub, below: the audit refuses an entry with no jev line, the JEV VERDICT GATE one that is not continue
printf '# ATL-42 · atlas · rung 1\nBRANCH  feat/atl-42   the rung'"'"'s own\n' > "$R/handoff.md"
git -C "$I" branch -M main 2>/dev/null; git -C "$I" checkout -q -b feat/atl-42
mkdir -p "$I/docs"; cp "$F/repo/docs/atl-42-spec.md" "$I/docs/"; git -C "$I" add docs/atl-42-spec.md
git -C "$I" config user.email t@t; git -C "$I" -c user.name=t commit -q -m two   # HEAD one commit past main
git -C "$I" update-ref refs/remotes/origin/trunk HEAD; git -C "$I" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
H="$(git -C "$I" rev-parse HEAD)"
git -C "$I" fetch -q "$F/repo" HEAD   # the approved commit, as in a real worktree of the same repo
cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RF/stop1.log" "$R/"; GH="$(hx "$R/gate.md")"   # the freeze's files, spec docs/atl-42-spec.md
# a stub answering no (0.02) to every question rules.md asks, so dr-check writes a continue jev line and its receipt
JEV_ENV="$T/nokey" python3 "$HERE/dr_check.py" "$R/decision-record.md" --dump | jq '{model:"jev-stub",answers:(.request.body.questions|keys|map({key:.,value:{type:"noul",noul:0.02}})|from_entries)}' > "$T/stub-pg.json"
check "push-gate fixture: dr-check on a stub writes DR1's continue jev line and its receipt" "$(dr "$I" "$R/decision-record.md" "$T/stub-pg.json" >/dev/null; grep -c '^  jev         continue, max yes 0.02 · jev-stub$' "$R/decision-record.md"):$(ls "$R"/receipts/*-jev-DR1.json | wc -l | tr -d ' ')" "1:1"
green(){ rm -f "$R"/receipts/*-gate.md; printf 'receipt · atl-42-r1 · 2026-10-13 10:00 · HEAD %s · dirty 0 · %s\nverdict  green\ngate     sha256 %s\n  1  green  exit 0  make test\n' "${1:-$H}" "$I" "$GH" > "$R/receipts/2026-10-13-1000-gate.md"; }
green
check "push-gate: green receipt at HEAD, clean audit, feature branch: push allowed" "$(pg 'git push -u origin feat/atl-42')" allow
check "push-gate: a bare git push of the feature branch allowed" "$(pg 'git push')" allow
check "push-gate: git -C <dir> push inside a compound command allowed" "$(pg "git -C $I add . && git -C $I push origin HEAD 2>&1 | tail -3")" allow
check "push-gate: gh pr create --draft allowed" "$(pg 'gh pr create --draft --title "ATL-42 && retry" --body "the spec summary; it'"'"'s short"')" allow
check "push-gate: push to main denied" "$(pg 'git push origin main' | grep -c 'BRANCH GATE: this push targets main')" 1
check "push-gate: git -C <dir> push HEAD:refs/heads/main denied" "$(pg "cd /tmp && git -C $I push origin HEAD:refs/heads/main" | grep -c 'BRANCH GATE: this push targets main')" 1
check "push-gate: push to the remote's default branch denied" "$(pg 'git push origin feat/atl-42:trunk' | grep -c 'targets trunk')" 1
check "push-gate: a bare push from main denied" "$(git -C "$I" checkout -q main; pg 'git push' | grep -c 'targets main'; git -C "$I" checkout -q feat/atl-42)" 1
check "push-gate: --force denied" "$(pg 'git push --force origin feat/atl-42' | grep -c 'PUSH FLAG GATE: this push uses --force')" 1
check "push-gate: -f in a short-flag cluster denied" "$(pg 'git push -uf origin feat/atl-42' | grep -c 'uses -f')" 1
check "push-gate: --force-with-lease denied" "$(pg 'git push --force-with-lease=feat/atl-42 origin feat/atl-42' | grep -c 'uses --force-with-lease')" 1
check "push-gate: a +refspec denied" "$(pg 'git push origin +feat/atl-42' | grep -c '+refspec')" 1
check "push-gate: --delete denied" "$(pg 'git push origin --delete feat/atl-42' | grep -c 'uses --delete')" 1
check "push-gate: --tags denied" "$(pg 'git push --tags' | grep -c 'uses --tags')" 1
check "push-gate: a push inside bash -c is read" "$(pg "bash -c 'git push --force'" | grep -c 'PUSH FLAG GATE')" 1
check "push-gate: gh pr create without --draft denied" "$(pg 'gh pr create --title x --body y' | grep -c 'DRAFT GATE')" 1
check "push-gate: gh pr create --draft from main denied" "$(pg 'gh pr create --draft --head main' | grep -c 'BRANCH GATE: this pull request targets main')" 1
check "push-gate: gh pr merge denied" "$(pg 'gh pr merge 88 --squash' | grep -c 'MERGE GATE')" 1
check "push-gate: gh pr ready with no owner line on the newest DR denied" "$(pg 'gh pr ready 88' | grep -c 'READY GATE: the newest DR entry .*(ATL-42 DR1')" 1
printf '\nATL-42 DR2 · ready · 2026-10-13 11:00 · test-ic\n  plan        6 "the owner marks ready"\n  decided     mark PR 88 ready for review\n  owner       "ATL-42 ready ok" typed in the test-ic pane, 10:58\n  undo        gh pr ready 88 --undo\n' >> "$R/decision-record.md"; dr "$I" "$R/decision-record.md" "$T/stub-pg.json" >/dev/null   # continue, max yes 0.02, receipt written
check "push-gate: gh pr ready with the word on the newest DR allowed" "$(pg 'gh pr ready 88')" allow
check "push-gate: lead role allowed" "$(pg 'git push --force origin main' "$L")" allow
check "push-gate: solo allowed" "$(pg 'gh pr merge 88' "$T/solo")" allow
check "push-gate: a non-push command allowed" "$(pg 'git status && echo "git push --force origin main" && grep -n push README.md')" allow
n=0; while IFS= read -r c; do [ "$(pg "$c")" = allow ] || n=$((n+1)); done <<'EOF'
if true; then git push -f origin main; fi
for x in 1; do git push -f origin main; done
{ git push -f origin main; }
! git push -f origin main
timeout 60 git push -f origin main
nice git push -f origin main
xargs git push -f origin <<< main
eval git push -f origin main
bash -lc 'git push -f origin main'
echo `git push -f origin main`
echo "$(git push -f origin main)"
cat <(git push -f origin main)
EOF
check "push-gate: 12 hidden forms of a force push to main all denied" "$n" 12
check "push-gate: HEAD:heads/main is main" "$(pg 'git push origin HEAD:heads/main' | grep -c 'BRANCH GATE: this push targets main')" 1
check "push-gate: a glob refspec denied" "$(pg "git push origin 'refs/heads/*:refs/heads/*'" | grep -c 'glob refspec')" 1
check "push-gate: --prune denied" "$(pg 'git push --prune origin feat/atl-42' | grep -c 'uses --prune')" 1
check "push-gate: gh -R before pr merge denied" "$(pg 'gh -R o/r pr merge 88' | grep -c 'MERGE GATE')" 1
check "push-gate: gh pr -R before merge denied" "$(pg 'gh pr -R o/r merge 88' | grep -c 'MERGE GATE')" 1
check "push-gate: gh -R pr create without --draft denied" "$(pg 'gh -R o/r pr create --title x' | grep -c 'DRAFT GATE')" 1
check "push-gate: a merge through gh api denied" "$(pg 'gh api -X PUT repos/o/r/pulls/88/merge' | grep -c 'MERGE GATE')" 1
check "push-gate: a branch that is not the handoff's BRANCH denied" "$(pg 'git push origin someone-else' | grep -c "not the rung's branch feat/atl-42")" 1
check "push-gate: a draft PR from another branch denied" "$(pg 'gh pr create --draft --head someone-else' | grep -c "not the rung's branch feat/atl-42")" 1
check "push-gate: a source that is not HEAD denied" "$(pg 'git push origin main~0:feat/atl-42' | grep -c 'SOURCE GATE: this push sends main~0')" 1
git -C "$I" update-ref refs/remotes/origin/feat/atl-42 "$(git -C "$I" -c user.name=o -c user.email=other@x commit-tree 'HEAD^{tree}' -p HEAD -m other)"
check "push-gate: origin/<branch> with another author's commit denied" "$(pg 'git push origin feat/atl-42' | grep -c 'origin/feat/atl-42 holds commits by other@x')" 1
git -C "$I" update-ref refs/remotes/origin/feat/atl-42 "$(git -C "$I" -c user.name=t commit-tree 'HEAD^{tree}' -p HEAD -m mine)"
check "push-gate: origin/<branch> with only this worktree's commits allowed" "$(pg 'git push origin feat/atl-42')" allow
git -C "$I" update-ref -d refs/remotes/origin/feat/atl-42
# LEAK GATE: the added lines of the commits a push or a draft PR sends
printf 'retry three times\n' > "$I/notes.md"; git -C "$I" add notes.md; git -C "$I" -c user.name=t commit -qm clean; green "$(git -C "$I" rev-parse HEAD)"
check "push-gate: a push whose diff is clean allowed" "$(pg 'git push origin feat/atl-42')" allow
printf 'see /Use''rs/robin/x\nby test-ic\n' >> "$I/notes.md"; git -C "$I" -c user.name=t commit -qam leak; green "$(git -C "$I" rev-parse HEAD)"
check "push-gate: a push whose diff adds a /Use""rs/ path denied, file and line named" "$(pg 'git push origin feat/atl-42' | grep -c 'LEAK GATE: .* notes.md:2: /Use''rs/: see /Use''rs/robin/x; notes.md:3: test-ic (roster name): by test-ic;')" 1
check "push-gate: gh pr create --draft with the same diff denied" "$(pg 'gh pr create --draft' | grep -c 'LEAK GATE')" 1
git -C "$I" reset -q --hard "$H"; git -C "$I" -c user.name=t commit -q --allow-empty -m 'retry, notes in /Use''rs/robin/x'; green "$(git -C "$I" rev-parse HEAD)"
check "push-gate: a commit message holding a /Use""rs/ path denied" "$(pg 'git push origin feat/atl-42' | grep -c 'LEAK GATE: .*commit [0-9a-f]\{7\} message:1: /Use''rs/: retry, notes in /Use''rs/robin/x;')" 1
# leak tokens (FLEET_HOME/leak-tokens.txt) are for this repo's own clone only: a product repo may use a ticket key
git -C "$I" reset -q --hard "$H"; git -C "$I" -c user.name=t commit -q --allow-empty -m 'feat(ATL-123): x'; green "$(git -C "$I" rev-parse HEAD)"
check "leak_tokens_product_repo: a product repo's commit message with a ticket key passes with the token file present" "$(FLEET_HOME="$LTH" pg 'git push origin feat/atl-42')" allow
# the same text in a repo that is FLEET_REPO (a copy of the hooks tree inside it) is a hit
mkdir -p "$I/shared"; cp -R "$HERE" "$I/shared/hooks"; cp -R "$HERE/../lib" "$I/shared/lib"; cp -R "$HERE/../records" "$I/shared/records"; cp "$HERE/../frozen.py" "$I/shared/"
echo shared >> "$I/.git/info/exclude"
check "leak_tokens_fleet_repo: the same message in the fleet clone is a hit" "$(jq -n --arg c 'git push origin feat/atl-42' --arg d "$I" --arg s "$S" '{cwd:$d,session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' | FLEET_HOME="$LTH" "$I/shared/hooks/push-gate.sh" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -c 'LEAK GATE: .*ATL-<digits> (leak token): feat(ATL-123): x')" 1
# the same from a worktree of the fleet clone: the token list still applies
git -C "$I" worktree add -q -b wt-leak "$T/wt-leak" HEAD
printf '```fleet\nlead-1\t%s\ntest-ic\t%s\n```\n' "$T/lead" "$T/wt-leak" > "$T/roster-wt.md"   # the IC works in the worktree
check "leak_tokens_worktree: the same message pushed from a worktree of the fleet clone is a hit" "$(jq -n --arg c 'git push origin wt-leak' --arg d "$T/wt-leak" --arg s "$S" '{cwd:$d,session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' | FLEET_ROSTER="$T/roster-wt.md" FLEET_HOME="$LTH" "$I/shared/hooks/push-gate.sh" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -c 'LEAK GATE: .*ATL-<digits> (leak token): feat(ATL-123): x')" 1
check "leak_tokens_worktree: a worktree of another repo does not get the token list" "$(P2="$(mktemp -d)"; git -C "$P2" init -q -b main; git -C "$P2" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base; git -C "$P2" update-ref refs/remotes/origin/main HEAD; git -C "$P2" -c user.name=t -c user.email=t@t commit -q --allow-empty -m 'feat(ATL-123): x'; git -C "$P2" worktree add -q -b wt2 "$P2/wt2" HEAD; printf '```fleet\nlead-1\t%s\ntest-ic\t%s\n```\n' "$T/lead" "$P2/wt2" > "$P2/roster.md"; jq -n --arg c 'git push origin wt2' --arg d "$P2/wt2" --arg s "$S" '{cwd:$d,session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' | FLEET_ROSTER="$P2/roster.md" FLEET_HOME="$LTH" "$I/shared/hooks/push-gate.sh" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' | grep -c 'ATL-<digits> (leak token)'; rm -rf "$P2")" 0
git -C "$I" worktree remove --force "$T/wt-leak"; git -C "$I" branch -q -D wt-leak
rm -rf "$I/shared"
git -C "$I" update-ref refs/remotes/origin/feat/atl-42 HEAD
check "push-gate: a commit message a remote already holds is not read again" "$(pg 'git push origin feat/atl-42')" allow
git -C "$I" update-ref -d refs/remotes/origin/feat/atl-42
git -C "$I" reset -q --hard "$H"; green
check "push-gate: gh pr create --body holding a roster name denied" "$(pg 'gh pr create --draft --title "ATL-42 retry" --body "written by test-ic"' | grep -c 'LEAK GATE: the pull request.*PR body:1: test-ic (roster name): written by test-ic;')" 1
printf 'Retry the nightly import.\nSee /Use''rs/robin/notes.\n' > "$T/body.md"
check "push-gate: gh pr create --body-file holding a /Use""rs/ path denied" "$(pg "gh pr create --draft --title x --body-file $T/body.md" | grep -c 'PR body file .*:2: /Use''rs/:')" 1
check "push-gate: gh pr create with a clean title and body allowed" "$(pg 'gh pr create --draft --title "ATL-42 retry" --body "Retry the nightly import (ATL-42)."')" allow
git -C "$I" reset -q --hard "$H"; green
printf 'receipt · atl-42-r1 · 2026-10-13 10:05 · HEAD %s · dirty 0 · %s\nverdict  red: 1 of 2\ngate     sha256 %s\n  1  green  exit 0  make test\n     pass   exit 0\n  2  red    exit 1  make lint\n     pass   exit 0\n' "$H" "$I" "$GH" > "$R/receipts/2026-10-13-1005-gate.md"
check "push-gate: red receipt denied, the red line named" "$(pg 'git push origin feat/atl-42' | grep -c 'has red lines: line 2 (exit 1): make lint;')" 1
check "push-gate: red receipt denies gh pr create too" "$(pg 'gh pr create --draft' | grep -c 'RECEIPT GATE')" 1
# the owner's override: typed by a person in the IC's pane (session log origin.kind human), noted in an owner line
OL="$T/logs/ic"; mkdir -p "$OL"; OD="$(cp "$R/decision-record.md" "$T/dr-before-override.md"; echo "$T/dr-before-override.md")"
ul(){ jq -nc --arg k "$1" --arg t "$2" '{type:"user",origin:{kind:$k},timestamp:"2026-10-13T10:10:00Z",message:{role:"user",content:$t}}' >> "$OL/s.jsonl"; }
pgl(){ o="$(jq -n --arg c "$1" --arg d "$I" --arg s "$S" --arg p "$OL/s.jsonl" '{cwd:$d,session_id:$s,transcript_path:$p,tool_name:"Bash",tool_input:{command:$c}}' | "$HERE/push-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
ul peer 'ATL-42 r1 override lint: relayed by lead-1'
check "override: a relayed override does not count" "$(pgl 'git push origin feat/atl-42' | grep -c 'Override state: line 2 open (make lint);')" 1
check "override: the deny names the words to type" "$(pgl 'git push origin feat/atl-42' | grep -c '"atl-42 r1 override <line numbers or check names>: <reason>"')" 1
ul human 'ATL-42 r1 override test: a word in another line'
check "override: an override naming another line leaves the red one open" "$(pgl 'git push origin feat/atl-42' | grep -c 'line 2 open')" 1
ul human 'ATL-42 r1 override make: names two lines'
check "override: a word in two commands names neither" "$(pgl 'git push origin feat/atl-42' | grep -c 'line 2 open')" 1
ul human 'ATL-42 r2 override lint: another rung'
check "override: another rung's override does not count" "$(pgl 'git push origin feat/atl-42' | grep -c 'line 2 open')" 1
ul human 'atl-42 r1 override lint, 9: the linter config lands next week'
check "override: typed but not noted in an owner line, still denied" "$(pgl 'git push origin feat/atl-42' | grep -c 'line 2 unnoted ("atl-42 r1 override lint, 9: the linter config lands next week" typed 2026-10-13T10:10:00Z)')" 1
printf '  owner       "atl-42 r1 override lint, 9: the linter config lands next week" typed in the test-ic pane, 10:10\n' >> "$R/decision-record.md"
check "override: typed and noted, the push allowed" "$(pgl 'git push origin feat/atl-42' | grep -c 'RECEIPT GATE')" 0
check "override: without this session's log folder, still denied" "$(pg 'git push origin feat/atl-42' | grep -c 'RECEIPT GATE')" 1
check "override: the receipt stays red" "$(grep -c '^  2  red ' "$R/receipts/2026-10-13-1005-gate.md")" 1
check "override: owner_override.py names the line covered" "$(python3 "$HERE/owner_override.py" "$R" "$R/receipts/2026-10-13-1005-gate.md" "$OL" | cut -f1,2)" "2	covered"
cp "$OD" "$R/decision-record.md"
green 0000000000000000000000000000000000000000
check "push-gate: receipt at an old HEAD denied" "$(pg 'git push origin feat/atl-42' | grep -c 'is at HEAD 0000000')" 1
rm -f "$R"/receipts/*-gate.md
check "push-gate: no receipt denied" "$(pg 'git push origin feat/atl-42' | grep -c 'no gate receipt')" 1
green; printf '  jev         continue, max yes 0.01 · jev-stub\n' >> "$R/decision-record.md"
check "push-gate: a hand-written jev line denied" "$(pg 'git push origin feat/atl-42' | grep -c 'JEV RECEIPT GATE: ATL-42 DR2')" 1
# JEV VERDICT GATE: the newest entry's jev line, its receipt present, says stop and ask or rework
jr(){ printf '{"entry": "%s", "verdict": "%s"}\n' "$1" "$2" > "$R/receipts/2026-10-13-1100-jev-${1##* }.json"; }
jr "ATL-42 DR2" "continue, max yes 0.01 · jev-stub"
check "push-gate: a continue jev line its receipt backs allowed" "$(pg 'git push origin feat/atl-42')" allow
V='stop and ask, standing-2 0.91 (writes where others read) · jev-stub'
printf '\nATL-42 DR3 · push · 2026-10-13 12:00 · test-ic\n  plan        6 "push the branch"\n  decided     push feat/atl-42\n  owner       -\n  undo        git push origin --delete feat/atl-42\n  jev         %s\n' "$V" >> "$R/decision-record.md"; jr "ATL-42 DR3" "$V"
check "push-gate: newest jev line stop and ask denies the push, audit clean" "$(o="$(pg 'git push origin feat/atl-42')"; printf '%s' "$o" | grep -c 'JEV VERDICT GATE: the newest entry .*(ATL-42 DR3) has jev "stop and ask, standing-2 0.91'; printf '%s' "$o" | grep -c 'JEV RECEIPT GATE')" "1
0"
check "push-gate: newest jev line stop and ask denies gh pr create --draft" "$(pg 'gh pr create --draft' | grep -c 'JEV VERDICT GATE: .*(ATL-42 DR3)')" 1
V='rework, decided-28 0.91 (run it from cron) · jev-stub'
printf '\nATL-42 DR4 · push · 2026-10-13 12:10 · test-ic\n  plan        6 "push the branch"\n  decided     push feat/atl-42\n  owner       -\n  undo        git push origin --delete feat/atl-42\n  jev         %s\n' "$V" >> "$R/decision-record.md"; jr "ATL-42 DR4" "$V"
check "push-gate: newest jev line rework denies the push" "$(pg 'git push origin feat/atl-42' | grep -c 'JEV VERDICT GATE: .*(ATL-42 DR4) has jev "rework, decided-28')" 1
V='continue, standing-2 with the owner'"'"'s word (writes where others read) · jev-stub'
printf '\nATL-42 DR5 · push · 2026-10-13 12:20 · test-ic\n  plan        6 "push the branch"\n  decided     push feat/atl-42\n  owner       "ATL-42 push ok" typed in the test-ic pane, 12:19\n  undo        git push origin --delete feat/atl-42\n  jev         %s\n' "$V" >> "$R/decision-record.md"; jr "ATL-42 DR5" "$V"
check "push-gate: a stop and ask followed by an entry with the owner's word allowed" "$(pg 'git push origin feat/atl-42')" allow
rm -rf "$T/records"
check "push-gate: no record folder denied" "$(pg 'git push origin feat/atl-42' | grep -c 'RECORD GATE: no record folder')" 1
check "push-gate: installed for ICs on Bash" "$(jq -r '[.hooks.PreToolUse[]|select(.matcher=="Bash")|.hooks[].command]|join(" ")' "$HERE/../launch/ic-settings.json")" '"$FLEET_REPO/shared/hooks/push-gate.sh"'
# the freeze holes: one check per hole closed, named by its id (ATL-42 hole hunt)
export FLEET_RECORDS="$T/records"; R="$T/records/atlas/atl-42-r1"; mkdir -p "$R/receipts"
S=holes; mkdir -p "$T/checks/test-ic/skills/$S"
mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null; mark "$I" Skill '{"skill":"writing-a-design-spec"}' >/dev/null
printf '# ATL-42 rung 1 · decision record · test-ic\n' > "$R/decision-record.md"
printf '# ATL-42 · atlas · rung 1\nBRANCH  feat/atl-42   the rung'"'"'s own\n' > "$R/handoff.md"
cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RF/stop1.log" "$R/"; GH="$(hx "$R/gate.md")"
git -C "$I" checkout -q feat/atl-42; git -C "$I" reset -q --hard "$H"; green
dc(){ git -C "$I" -c user.name=t commit -qam "$1"; green "$(git -C "$I" rev-parse HEAD)"; }
st(){ send "$I" "$(printf '"atlas · ATL-42 r1 · STOP %s\\n  files record %s/"' "$1" "$R")"; }
check "process-2: frozen files, the receipt's gate hash and the spec at HEAD agree: push allowed" "$(pg 'git push origin feat/atl-42')" allow
perl -pi -e 's/\| 2 \| nightly imports only/| 2 | weekly imports only/' "$I/docs/atl-42-spec.md"; dc drift
check "process-2: a Decided row changed at HEAD after the freeze: push denied, the row named" "$(pg 'git push origin feat/atl-42' | grep -c 'FROZEN GATE: spec drift: docs/atl-42-spec.md at HEAD: .*weekly imports only')" 1
check "drift-2: the same drift denies gh pr create" "$(pg 'gh pr create --draft' | grep -c 'FROZEN GATE: spec drift')" 1
check "process-2: the same drift denies the ready for push report" "$(st '3 · ready for push' | grep -c 'FROZEN GATE: spec drift')" 1
check "process-2: a STOP that is not ready for push does not read the spec" "$(st '2 · y')" allow
git -C "$I" reset -q --hard "$H"
python3 - "$I/docs/atl-42-spec.md" <<'EOF'
import re, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
u = re.sub(r"## One-way\n\n(\|.*\n)+\n", "", t, count=1)
assert u != t; open(p, "w", encoding="utf-8").write(u)
EOF
dc drop
check "drift-3: the One-way block dropped at HEAD: push denied" "$(pg 'git push origin feat/atl-42' | grep -c 'FROZEN GATE: spec drift: .*One-way')" 1
git -C "$I" reset -q --hard "$H"; green
mv "$R/frozen.sha256" "$T/frozen.keep"
check "process-3: no frozen.sha256: push denied" "$(pg 'git push origin feat/atl-42' | grep -c 'FROZEN GATE: no frozen.sha256')" 1
check "process-3: no frozen.sha256: a STOP after STOP 1 denied" "$(st '2 · y' | grep -c 'FROZEN GATE: no frozen.sha256')" 1
mv "$T/frozen.keep" "$R/frozen.sha256"
rm -f "$R"/receipts/*; printf 'receipt · atl-42-r1 · 2026-10-13 10:00 · HEAD %s · dirty 0 · %s\nverdict  green\n  1  green  exit 0  make test\n' "$H" "$I" > "$R/receipts/2026-10-13-1000-gate.md"
check "process-3: a receipt naming no gate.md sha256 denied" "$(pg 'git push origin feat/atl-42' | grep -c 'names no gate.md sha256')" 1
green
RG="$T/records/atlas/atl-42-r8"; mkdir -p "$RG"; cp "$R/rules.md" "$RG/"; grep -v ' gate.md$' "$R/frozen.sha256" > "$RG/frozen.sha256"
check "process-3: a frozen.sha256 with no gate.md refused: rules.md and gate.md are both required" "$(python3 "$HERE/../frozen.py" verify "$RG" | grep -c 'names no gate.md'; echo "rc=${PIPESTATUS[0]}")" "1
rc=2"
mkdir -p "$T/audit/x"; printf '# ATL-42 rung 1 · decision record · someone\n\nATL-42 DR1 · task 1 · 2026-10-08 11:00 · someone\n  plan        1 "x"\n  decided     x\n  undo        -\n  jev         no rules.md\n' > "$T/audit/x/decision-record.md"
check "process-3: --audit names a jev line reading no rules.md, exit 1" "$(python3 "$HERE/dr_check.py" "$T/audit/x/decision-record.md" --audit | grep -c '^ATL-42 DR1: jev'; echo "rc=${PIPESTATUS[0]}")" "1
rc=1"
fg(){ gate0 "$I" "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason' | cut -c1-7; }
check "process-5: an IC write to gate.md denied" "$(fg "$R/gate.md")" "FROZEN:"
check "process-5: an IC write to a gate-pre copy denied" "$(fg "$R/gate-pre-2026-10-14-1000.md")" "FROZEN:"
check "process-6: an IC write to rules.md denied" "$(fg "$R/rules.md")" "FROZEN:"
check "process-6: an IC write to frozen.sha256 denied" "$(fg "$R/frozen.sha256")" "FROZEN:"
cp "$R/gate.md" "$T/gate.keep"; printf '  # one more line\n' >> "$R/gate.md"; rm -f "$R"/receipts/*
r="$(cd "$I" && "$HERE/../records/gate-run.sh" "$R" 2>&1; echo "rc=$?")"
check "process-5: gate-run refuses a gate.md changed after the freeze, exit 2, no receipt" "$(printf '%s' "$r" | grep -c 'gate.md does not match frozen.sha256'):$(printf '%s' "$r" | tail -1):$(ls "$R/receipts" | wc -l | tr -d ' ')" "1:rc=2:0"
SH="$T/sh"; mkdir -p "$SH/skills/foundations" "$SH/records"; cp -R "$HERE/../lib" "$SH/lib"; cp "$HERE"/../{frozen.py,amend-frozen.sh} "$SH/"; cp "$HERE"/../records/{freeze_rules.py,gate_run.py,legacy-records.txt} "$SH/records/"; cp "$HERE/../skills/foundations/one-way.md" "$SH/skills/foundations/"; mkdir -p "$SH/home" && cp "$T/roster.md" "$SH/home/roster.md"; printf '{"env":{"FLEET_HOME":"%s"}}\n' "$SH/home" > "$SH/user-settings.json"
am(){ (cd "${3:-$L}" && "$SH/amend-frozen.sh" "$R" "$1" "$2" 2>&1; echo "rc=$?"); }
# the owner's amend word is read from session logs at fixed paths; this copy of freeze_rules.py gets a test root and lead-1's folder
AO="$T/amend-logs"; sed -i '' -e "s|^SESSION_LOGS = .*|SESSION_LOGS = \"$AO\"|" -e "s|^LEAD_CWD = .*|LEAD_CWD = \"$L\"|" -e "s|^USER_SETTINGS = .*|USER_SETTINGS = \"$SH/user-settings.json\"|" "$SH/records/freeze_rules.py"
check "amend: the copy reads its session logs from the test root" "$(grep -c -e "^SESSION_LOGS = \"$AO\"" -e "^LEAD_CWD = \"$L\"" "$SH/records/freeze_rules.py")" 2
ao(){ rm -rf "$AO"; mkdir -p "$AO"; }; xl(){ OLR="$AO" olog "$@"; }   # xl <pane cwd> human|peer <local time> <text>
check "process-5: amend-frozen with no gate-pre copy refused" "$(am gate 'line 1 kind a' | grep -c 'no gate-pre-')" 1
cp "$T/gate.keep" "$R/gate-pre-2026-10-14-1000.md"
check "process-5: amend-frozen with no # Amended line refused, nothing re-hashed" "$(am gate 'line 1 kind a' | grep -c 'no new `# Amended'):$(grep -c '^history' "$R/frozen.sha256")" "1:0"
python3 - "$T/gate.keep" "$R/gate.md" <<'EOF'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write(t.replace("GATE BLOCK", "# Amended 2026-10-14 10:00 by lead-1 (C3): line 1, kind a, ATL-42 C3\nGATE BLOCK", 1))
EOF
check "process-5: amend-frozen refused from an IC worktree" "$(am gate 'line 1 kind a' "$I" | grep -c "is test-ic's worktree")" 1
green
check "process-5: a # Amended line above GATE BLOCK is re-hashed, history appended, verify passes" "$(am gate 'line 1 kind a' | tail -1):$(grep -c '^history .* · gate · line 1 kind a · was [0-9a-f]\{64\} · copy gate-pre-2026-10-14-1000.md$' "$R/frozen.sha256"):$(python3 "$HERE/../frozen.py" verify "$R"; echo "rc=$?")" "rc=0:1:rc=0"
check "process-5: a receipt from the gate.md before the amendment denied" "$(pg 'git push origin feat/atl-42' | grep -c 'ran a gate.md with sha256')" 1
GH="$(hx "$R/gate.md")"; green
check "process-5: a receipt from the amended gate.md allowed" "$(pg 'git push origin feat/atl-42')" allow
# STOP 1: before the freeze, so no receipt; the spec at the reviewed sha, and main's runs in evidence.md
git -C "$I" update-ref refs/remotes/origin/main "$H"; HS="$(git -C "$I" rev-parse --short HEAD)"; rm -f "$R"/receipts/*
s1(){ send "$I" "$(printf '"atlas · ATL-42 r1 · STOP 1 · 10:00 · holding on lead-1\\n  spec       %s\\n  files record %s/"' "$1" "$R")"; }
ev(){ printf '# ATL-42 rung 1 · evidence · test-ic\n\n## E1 make test on origin/main · 2026-10-14 10:00\n  ran       make test\n  where     %s · %s · HEAD %s\n  exit      0\n\n## E2 the dry run on origin/main · 2026-10-14 10:05\n  ran       make import-dry-run FILE=tests/fixtures/bad.csv\n  where     %s · origin/main · HEAD %s\n  exit      2\n' "$I" "${1:-origin/main}" "${2:-$HS}" "$I" "$HS" > "$R/evidence.md"; }
check "process-10: STOP 1 with no evidence.md denied" "$(s1 "docs/atl-42-spec.md @ $HS" | grep -c 'STOP 1 GATE: no evidence.md')" 1
check "process-10: STOP 1 with no spec line denied" "$(st '1 · 10:00' | grep -c 'STOP 1 GATE: no spec line')" 1
ev feat/atl-42
check "process-10: an evidence entry not run at origin/main denied" "$(s1 "docs/atl-42-spec.md @ $HS" | grep -c 'E1 did not run at origin/main')" 1
X="$(git -C "$I" -c user.name=t commit-tree 'HEAD^{tree}' -p HEAD -m off-main)"; ev origin/main "${X:0:7}"
check "process-10: an evidence entry whose HEAD is not on origin/main denied" "$(s1 "docs/atl-42-spec.md @ $HS" | grep -c "E1 HEAD ${X:0:7} is not a commit on origin/main")" 1
ev
check "process-10: STOP 1 with each Checks command run at origin/main allowed" "$(s1 "docs/atl-42-spec.md @ $HS")" allow
check "process-4: a STOP 1 report has no receipt and is not receipt-gated" "$(ls "$R/receipts" | wc -l | tr -d ' '):$(s1 "docs/atl-42-spec.md @ $HS" | grep -c 'RECEIPT GATE')" "0:0"
sendto(){ printf '{"cwd":"%s","session_id":"%s","tool_name":"SendMessage","tool_input":{"to":"%s","message":%s}}' "$I" "$S" "$1" "$(printf '"atlas · ATL-42 r1 · STOP 1 · 10:00 · holding on lead-1\\n  spec       docs/atl-42-spec.md @ %s\\n  files record %s/"' "$HS" "$R")" | "$HERE/message-gate.sh" 2>/dev/null; }
n0="$(wc -l < "$R/stop1.log")"; s1n(){ echo $(( $(wc -l < "$R/stop1.log") - n0 )); }
check "stop1-log: a STOP 1 sent to another IC is allowed, writes no stop1.log line, and says so" "$(sendto dbx-ic-1 | jq -r '.hookSpecificOutput | (.permissionDecision // "none") + " " + (.additionalContext | test("^STOP 1 LOG: this STOP 1 is not sent to lead-1") | tostring)'):$(s1n)" "none true:0"
(cd "$T" && exec sleep 60) & opid=$!; (cd "$L" && exec sleep 60) & lpid=$!; sleep 0.3 2>/dev/null || true
check "stop1-log: a STOP 1 to the socket of a process outside lead-1's folder writes no line" "$(sendto "uds:/tmp/cc-socks/$opid.sock" | grep -c 'STOP 1 LOG'):$(s1n)" "1:0"
check "stop1-log: a STOP 1 to the socket of the process in lead-1's folder writes its line" "$(sendto "uds:/tmp/cc-socks/$lpid.sock" | wc -c | tr -d ' '):$(s1n)" "0:1"
kill "$opid" "$lpid" 2>/dev/null; wait "$opid" "$lpid" 2>/dev/null
check "stop1-log: a STOP 1 to lead-1 by name writes its line" "$(sendto lead-1 | wc -c | tr -d ' '):$(s1n)" "0:2"
# a STOP 1 header with text after the number, up to the next "·", is still STOP 1; STOP 10 is not
s1h(){ send "$I" "$(printf '"atlas · ATL-42 r1 · %s · 10:00 · holding on lead-1\\n%s  files record %s/"' "$1" "${2:+  spec       docs/atl-42-spec.md @ $HS\\n}" "$R")"; }
check "stop1-suffix: the plain STOP 1 header with no spec line meets the STOP 1 gate" "$(s1h 'STOP 1' | grep -c 'STOP 1 GATE: no spec line')" 1
check "stop1-suffix: STOP 1 (re-send) with no spec line meets the STOP 1 gate" "$(s1h 'STOP 1 (re-send)' | grep -c 'STOP 1 GATE: no spec line')" 1
check "stop1-suffix: STOP 1 (re-sent, after fix) with no spec line meets the STOP 1 gate" "$(s1h 'STOP 1 (re-sent, after fix)' | grep -c 'STOP 1 GATE: no spec line')" 1
check "stop1-suffix: STOP 1 (re-send) to lead-1 that passes writes its stop1.log line" "$(s1h 'STOP 1 (re-send)' spec):$(s1n)" "allow:3"
check "stop1-suffix: STOP 10 is a STOP but not STOP 1: receipt-gated, not STOP 1-gated, no stop1.log line" "$(s1h 'STOP 10' spec | grep -c -e 'STOP 1 GATE' -e 'STOP 1 LOG'):$(s1h 'STOP 10' spec | grep -c 'no gate receipt'):$(s1n)" "0:1:3"
perl -pi -e 's/\| exit 0, "212 passed, 0 failed" \|/| TODO |/' "$I/docs/atl-42-spec.md"; git -C "$I" -c user.name=t commit -qam placeholder
check "process-10: a placeholder on main cell denied" "$(s1 "docs/atl-42-spec.md @ $(git -C "$I" rev-parse --short HEAD)" | grep -c 'on main is `TODO`, a placeholder')" 1
git -C "$I" reset -q --hard "$H"
# SPEC SHAPE at each spec write
NOONE="$(printf '%s' "$CLEAN" | sed '13,18d')"
check "process-8: a spec write with no One-way block denied by SPEC SHAPE" "$(aw "$I" /repo/docs/specs/atl-42-other.md "$NOONE" | grep -c -e '^SPEC SHAPE: ' -e 'no `## One-way` block')" 2
mkdir -p "$F/repo/docs/specs"; cp "$F/repo/docs/atl-42-spec.md" "$F/repo/docs/specs/atl-42.md"; git -C "$F/repo" add docs/specs/atl-42.md; git -C "$F/repo" -c user.name=t -c user.email=t@t commit -qm r13; A13="$(git -C "$F/repo" rev-parse HEAD)"; git -C "$I" fetch -q "$F/repo" HEAD
R13="$T/records/atlas/atl-42-r13"; mkdir -p "$R13"; cp "$RF/rules.md" "$RF/gate.md" "$R13/"; sed -e 's|^spec .*|spec      docs/specs/atl-42.md|' -e "s|^approved .*|approved  $A13|" "$RF/frozen.sha256" > "$R13/frozen.sha256"; lg "$R13" docs/specs/atl-42.md "$A13"
printf '# ATL-42 rung 13 · decision record · test-ic\n' > "$R13/decision-record.md"; touch -t 203001010000 "$R13/decision-record.md"
check "process-8: a write of the frozen spec with a row rules.md does not hold denied" "$(aw "$I" /repo/docs/specs/atl-42.md "$(sed 's/| 2 | nightly imports only/| 2 | weekly imports only/' "$F/repo/docs/atl-42-spec.md")" | grep -c 'not in rules.md: .*weekly imports only')" 1
check "process-8: the frozen spec written as it froze allowed" "$(aw "$I" /repo/docs/specs/atl-42.md "$(cat "$F/repo/docs/atl-42-spec.md")")" allow
rm -rf "$R13"
RL="$T/records/orbit/orb-42-r1"; mkdir -p "$RL/receipts"
printf '# ORB-42 rung 1 · decision record · test-ic\n' > "$RL/decision-record.md"; touch -t 203001010000 "$RL/decision-record.md"
check "process-8: a legacy rung's spec write is not shape-checked" "$(aw "$I" /repo/docs/specs/x.md "$NOONE")" allow
printf 'receipt · orb-42-r1 · 2026-10-14 10:00 · HEAD %s · dirty 0 · %s\nverdict  green\n  1  green  exit 0  make test\n' "$H" "$I" > "$RL/receipts/2026-10-14-1000-gate.md"
touch "$R/close.md"   # the live rung closed: the legacy folder is this IC's only open one
check "legacy: orb-42-r1 has no frozen.sha256 and its STOP is not frozen-gated" "$(send "$I" "$(printf '"x · STOP 2 · y\\n  files record %s/"' "$RL")")" allow
rm -f "$R/close.md"
check "legacy: frozen.py check passes a listed folder, exit 0" "$(python3 "$HERE/../frozen.py" check "$RL" --worktree "$I" 2>/dev/null; echo "rc=$?")" rc=0
printf 'GATE BLOCK\n  proves done   true\n  pass          exit 0\n' > "$RL/gate.md"
check "legacy: gate-run runs a listed folder's gate.md with no frozen.sha256" "$(cd "$I" && "$HERE/../records/gate-run.sh" "$RL" >/dev/null 2>&1; echo "rc=$?")" rc=0
rm -rf "$RL"
# dr-check reads rules.md only as frozen
cp "$R/rules.md" "$T/rules.keep"; printf '  one more rule\n' >> "$R/rules.md"; entry "wrap scheduler.nightly()"
check "process-6: dr-check on a rules.md changed after the freeze is stop and ask, with a receipt" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         stop and ask, no check (rules.md or gate.md does not match frozen.sha256)' "$R/decision-record.md"; python3 "$HERE/dr_check.py" "$R/decision-record.md" --audit >/dev/null; echo "rc=$?")" "1
rc=0"
cp "$T/rules.keep" "$R/rules.md"
RS="$T/records/atlas/atl-42-r12"; mkdir -p "$RS"; printf 'rules · ATL-42 r12 · frozen at 9b2e7c1\n\nDECIDED  never change:\n  1  retry 3 times   [ATL-42]\n' > "$RS/rules.md"; seal "$RS"; cp "$R/decision-record.md" "$RS/"; sed -i '' '/^  jev/d' "$RS/decision-record.md"
check "process-6: dr-check on a rules.md with no [standing] lines is stop and ask" "$(dr "$I" "$RS/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         stop and ask, no check (no \[standing\] lines in rules.md)' "$RS/decision-record.md")" 1
rm -rf "$RS"
cp "$R/rules.md" "$R/rules-pre-2026-10-14-1100.md"; perl -pi -e 's/nightly imports only/nightly and weekly imports/' "$R/rules.md"
check "process-6: amend-frozen refuses a changed rules.md row" "$(am rules 'card ATL-42 C2' | grep -c 'rules.md line [0-9]* changed'):$(am rules 'card ATL-42 C2' | tail -1)" "1:rc=2"
cp "$R/rules-pre-2026-10-14-1100.md" "$R/rules.md"
python3 - "$R/rules.md" <<'EOF'
import sys
p = sys.argv[1]; l = open(p, encoding="utf-8").read().rstrip("\n").split("\n"); n = len(l)
i = next(k for k, x in enumerate(l) if "nightly imports only" in x)
l[i] += f" [retired 2026-10-14 by {n + 2}]"
open(p, "w", encoding="utf-8").write("\n".join(l + ["DECIDED  amended 2026-10-14:", "  3  weekly imports only   [card ATL-42 C2]"]) + "\n")
EOF
# the owner's word for a rules.md amendment: "<lane> r<n> amend ok <card id>", typed by a person after the last amendment
RH0="$(grep -c '^history' "$R/frozen.sha256")"; rh(){ echo "rc=$(am rules "$1" | tail -1 | sed 's/^rc=//'):$(grep -c '^history' "$R/frozen.sha256")"; }
ao
hasall(){ local o="$1" n=0 x; shift; for x in "$@"; do printf '%s' "$o" | grep -qF -e "$x" && n=$((n+1)); done; echo "$n"; }
check "amend-ok: a rules.md amendment with no session log folder refused, the phrase, the panes and no-relay named, nothing re-hashed" "$(hasall "$(am rules 'card ATL-42 C2')" "a rules.md amendment needs the owner's typed approval" 'no session log folder' '"ATL-42 r1 amend ok <card id>" in lead-1'"'"'s pane or the IC'"'"'s pane' 'relayed by lead-1 or any other session does not count' 'Hold and ask the owner' 'rc=2'):$(grep -c '^history' "$R/frozen.sha256")" "6:$RH0"
ao; xl "$L" peer "2030-01-01 10:00" "ATL-42 r1 amend ok ATL-42 C2"; xl "$L" human "2030-01-01 10:01" "go on"
check "amend-ok: only a relay from lead-1 (origin peer) refused" "$(rh 'card ATL-42 C2'):$(am rules 'card ATL-42 C2' | grep -c 'was not found in the session logs')" "rc=2:$RH0:1"
ao; xl "$L" human "2026-10-14 12:00" "ATL-42 r1 amend ok ATL-42 C2"
check "amend-ok: typed after the freeze but before the last amendment's history line refused" "$(rh 'card ATL-42 C2'):$(am rules 'card ATL-42 C2' | grep -c 'was not found in the session logs after 20')" "rc=2:$RH0:1"
ao; xl "$L" human "2030-01-01 10:00" "ATL-42 r1 amend ok ATL-42 C9"
check "amend-ok: the card id typed is not in the reason refused" "$(rh 'card ATL-42 C2'):$(am rules 'card ATL-42 C2' | grep -c 'names none of them')" "rc=2:$RH0:1"
ao; xl "$L" human "2030-01-01 10:00" "ATL-42 r1 amend ok ATL-42 C2"
check "amend-ok: a longer card id (C21) does not satisfy a typed C2" "$(rh 'card ATL-42 C21')" "rc=2:$RH0"
ao; xl "$L" human "2030-01-01 10:00" "ATL-43 r1 amend ok ATL-42 C2"; xl "$L" human "2030-01-01 10:01" "ATL-42 r2 amend ok ATL-42 C2"; xl "$L" human "2030-01-01 10:02" "ATL-42 r1 spec ok"
check "amend-ok: another lane or another rung (or a spec ok) refused" "$(rh 'card ATL-42 C2')" "rc=2:$RH0"
ao; xl "$I" human "2030-01-01 10:00" "  atl-42 R1 AMEND OK atl-42 c2  "   # in the IC's pane, any case, the card id in the reason: the check below re-hashes
check "process-6: a retired tag and an appended amended row re-hash rules.md; the spec at HEAD still matches" "$(am rules 'card ATL-42 C2' | tail -1):$(python3 "$HERE/../frozen.py" check "$R" --worktree "$I"; echo "rc=$?")" "rc=0:rc=0"
check "process-6: dr-check reads the amendment: the old row retired, the new row asked" "$(dump | jq -r '[(.lines_retired[0].ignored // "retired"), (.request.body.questions | keys | map(select(startswith("decided"))) | length | tostring)] | join(" ")')" "retired 2"
# gate.md: a changed pass line (kind a) or command (kind b) needs no word; an added proves done line needs it, whatever its label
RG="$T/records/atlas/atl-42-r31"; mkdir -p "$RG"; printf '# ATL-42 rung 31 · decision record · test-ic\n' > "$RG/decision-record.md"; cp "$R/stop1.log" "$RG/"
GHEAD='gate · ATL-42 r31 · frozen at 9b2e7c1\n\n'; GA1='# Amended 2026-10-15 10:00 by lead-1 (C3): line 1, kind a, ATL-42 C3\n'; GA2='# Amended 2026-10-15 10:05 by lead-1 (C3): line 1, kind b, ATL-42 C3\n'; GA3='# Amended 2026-10-15 10:10 by lead-1 (C3): line 2, kind a, ATL-42 C3\n'
PM='exit 0 and "3 passed" in the summary line'
gw(){ printf "$1" > "$RG/gate.md"; }   # gate.md's text; gp saves the frozen text beside it first
gp(){ cp "$RG/gate.md" "$RG/gate-pre-$1.md"; }
amg(){ (cd "$L" && "$SH/amend-frozen.sh" "$RG" gate "$1" 2>&1; echo "rc=$?"); }
gw "${GHEAD}GATE BLOCK\n  proves done   make test\n  pass          exit 0\n"
printf 'frozen · ATL-42 r31 · 2026-10-08 09:00\nspec      docs/specs/atl-42.md\napproved  %s\nsha256    %s  rules.md\nsha256    %s  gate.md\n' "$(git -C "$I" rev-parse HEAD)" "$(hx "$R/rules.md")" "$(hx "$RG/gate.md")" > "$RG/frozen.sha256"; cp "$R/rules.md" "$RG/"
ao; gp 1
gw "${GHEAD}${GA1}GATE BLOCK\n  proves done   make test\n  pass          $PM\n"
check "amend-ok: a gate.md pass line changed, kind a, no word and no session logs: re-hashed" "$(amg 'line 1 kind a, card ATL-42 C3' | tail -1):$(grep -c '^history' "$RG/frozen.sha256")" "rc=0:1"
gp 2; gw "${GHEAD}${GA1}${GA2}GATE BLOCK\n  proves done   make test-ci\n  pass          $PM\n"
check "amend-ok: a gate.md command changed, kind b, no word: re-hashed" "$(amg 'line 1 kind b, card ATL-42 C3' | tail -1)" "rc=0"
gp 3; gw "${GHEAD}${GA1}${GA2}${GA3}GATE BLOCK\n  proves done   make check\n  pass          $PM\n"
check "amend-ok: a command changed under a new kind a line only refused (the label must fit the change)" "$(amg 'line 2 kind a, card ATL-42 C3' | grep -c 'changes a command with no `kind b`')" 1
gw "${GHEAD}${GA1}${GA2}${GA3}GATE BLOCK\n  proves done   make test-ci\n                make lint\n  pass          $PM\n                exit 0\n"
check "amend-ok: a gate.md that adds a proves done line, labelled kind a, with no word refused, nothing re-hashed" "$(amg 'line 2 kind a, card ATL-42 C3' | grep -c 'a gate.md amendment that adds a proves done line needs the owner'):$(grep -c '^history' "$RG/frozen.sha256")" "1:2"
ao; xl "$L" human "2030-01-01 10:00" "ATL-42 r31 amend ok ATL-42 C3"
check "amend-ok: the same gate.md with the word typed in lead-1's pane and the card id in the reason: re-hashed" "$(amg 'line 2 kind a, card ATL-42 C3' | tail -1):$(grep -c '^history' "$RG/frozen.sha256")" "rc=0:3"
ao
# the freeze: the approved sha, and only the freeze writes gate.md
check "process-4: gate-run with no gate.md says the freeze has not run" "$(mkdir -p "$T/records/atlas/atl-42-r10"; cd "$I" && "$HERE/../records/gate-run.sh" "$T/records/atlas/atl-42-r10" 2>&1 | grep -c 'the freeze has not run')" 1
RH="$F/records/atlas/atl-42-r11"; mkdir -p "$RH"; printf 'GATE BLOCK\n  proves done   make test\n  pass          exit 0\n' > "$RH/gate.md"
check "process-4: the freeze refuses a gate.md it did not write, nothing written" "$(fz docs/atl-42-spec.md "$RH" --approved "$(ap atl-42-spec.md)" | grep -c 'never copied by hand'; [ -e "$RH/rules.md" ] && echo written || echo none)" "1
none"
cp "$F/repo/docs/atl-42-spec.md" "$F/repo/docs/p1.md"; git -C "$F/repo" add docs/p1.md; git -C "$F/repo" -c user.name=t -c user.email=t@t commit -qm p1; A1="$(ap p1.md)"; R20="$F/records/atlas/atl-42-r20"
check "process-1: the freeze of a new-shape spec with no --approved refused" "$(fz docs/p1.md "$R20" | grep -c -- '--approved <sha> is required')" 1
check "process-1: an --approved that is not a commit refused" "$(fz docs/p1.md "$R20" --approved 1234567 | grep -c 'is not a commit in this repo')" 1
perl -pi -e 's/\| 2 \| nightly imports only/| 2 | weekly imports only/' "$F/repo/docs/p1.md"; git -C "$F/repo" -c user.name=t -c user.email=t@t commit -qam above
check "process-1: screen one changed after the approved sha refused, the line named, nothing written" "$(fz docs/p1.md "$R20" --approved "$A1" | grep -c "screen one changed after $A1.*weekly imports only"; [ -e "$R20/rules.md" ] && echo written || echo none)" "1
none"
git -C "$F/repo" checkout -q "$A1" -- docs/p1.md; printf '\nOne more appendix line.\n' >> "$F/repo/docs/p1.md"; git -C "$F/repo" -c user.name=t -c user.email=t@t commit -qam below
check "drift-5: an edit below the fold after the approved sha is free, the freeze runs" "$(fz docs/p1.md "$R20" --approved "$A1" | tail -1)" rc=0
check "drift-5: frozen.sha256 names the spec, the approved sha and both hashes; verify passes" "$(grep -c -e '^spec      docs/p1.md$' -e "^approved  $A1\$" -e '^sha256    [0-9a-f]\{64\}  rules.md$' -e '^sha256    [0-9a-f]\{64\}  gate.md$' "$R20/frozen.sha256"):$(python3 "$HERE/../frozen.py" verify "$R20"; echo "rc=$?")" "4:rc=0"
check "process-9: a new-shape spec with no Checks block refused by --check" "$(ck "$F/v-p7s.md" 'no `## Checks` block')" "1:rc=2"
cp "$F/v-p7s.md" "$F/repo/docs/p9.md"; git -C "$F/repo" add docs/p9.md; git -C "$F/repo" -c user.name=t -c user.email=t@t commit -qm p9
check "process-9: the freeze refuses it too, nothing written" "$(fz docs/p9.md "$F/records/atlas/atl-42-r21" --approved "$(ap p9.md)" | tail -1; [ -e "$F/records/atlas/atl-42-r21/rules.md" ] && echo written || echo none)" "rc=2
none"
# the freeze fixes: one check per hole closed, named by its id
FR="$HERE/../frozen.py"; SPI="$I/docs/atl-42-spec.md"
sp(){ python3 "$FR" spec "$R" --repo "$I" < "$1" 2>&1; echo "rc=$?"; }   # what the spec write gate runs on the frozen spec
cp "$SPI" "$T/s-sub.md"; python3 - "$T/s-sub.md" <<'EOF'
import re, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
u = re.sub(r"## Subtleties\n.*?(?=\n## )", "", t, count=1, flags=re.S); assert u != t; open(p, "w", encoding="utf-8").write(u)
EOF
check "drift-6: Subtleties removed from the frozen spec refused, screen one named" "$(sp "$T/s-sub.md" | grep -c 'screen one changed after'):$(sp "$T/s-sub.md" | tail -1)" "1:rc=2"
sed 's/^## Building$/## Build/' "$SPI" > "$T/s-bld.md"
check "drift-6: Building renamed in the frozen spec refused" "$(sp "$T/s-bld.md" | grep -c 'screen one changed after')" 1
sed 's/^## Amendments$/## Changes/' "$SPI" > "$T/s-am1.md"
check "drift-6: Amendments renamed refused" "$(sp "$T/s-am1.md" | grep -c 'not `## Amendments`')" 1
python3 -c "import sys; t=open(sys.argv[1]).read(); i=t.rindex('none'); open(sys.argv[2],'w').write(t[:i]+'retry count raised to 4, ATL-42 comment'+t[i+4:]); open(sys.argv[3],'w').write(t[:i]+'2026-10-20 retry count raised to 4, ATL-42 comment'+t[i+4:])" "$SPI" "$T/s-am2.md" "$T/s-am3.md"
check "drift-6: an undated line under Amendments refused" "$(sp "$T/s-am2.md" | grep -c 'is not a dated line')" 1
check "drift-6: a dated line under Amendments allowed" "$(sp "$T/s-am3.md")" "rc=0"
mkdir -p "$F/repo/docs/specs"; R14="$T/records/atlas/atl-42-r14"; mkdir -p "$R14"; cp "$RF/rules.md" "$RF/gate.md" "$R14/"; sed -e 's|^spec .*|spec      docs/specs/atl-42.md|' -e "s|^approved .*|approved  $A13|" "$RF/frozen.sha256" > "$R14/frozen.sha256"; lg "$R14" docs/specs/atl-42.md "$A13"
printf '# ATL-42 rung 14 · decision record · test-ic\n' > "$R14/decision-record.md"; touch -t 203001010000 "$R14/decision-record.md"
check "drift-6: the spec write gate refuses Subtleties removed from the frozen spec" "$(aw "$I" /repo/docs/specs/atl-42.md "$(cat "$T/s-sub.md")" | grep -c 'screen one changed after')" 1
rm -rf "$R14"
entry "wrap scheduler.nightly()"; perl -pi -e 's/\| 2 \| nightly imports only/| 2 | weekly imports only/' "$SPI"
check "drift-4: a Decided row changed in the spec on disk after the freeze: dr-check is stop and ask, the row in the receipt" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         stop and ask, no check (the spec or a frozen file moved after the freeze)' "$R/decision-record.md"; grep -c 'weekly imports only' "$(ls -t "$R"/receipts/*-jev-*.json | head -1)")" "1
1"
git -C "$I" checkout -q docs/atl-42-spec.md; entry "wrap scheduler.nightly()"
check "drift-4: the spec as frozen: dr-check asks Jev" "$(dr "$I" "$R/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c 'moved after the freeze' "$R/decision-record.md")" 0
check "N5: a numbered rule starting with a number keeps it (the row number is cut once)" "$(cd "$HERE" && python3 -c "import dr_check as d; print('|'.join(r.text for r in d.read_rules('DECIDED  never change:\n  1.  2 retries then alert   [ATL-42]\n  2.  use the queue   [ATL-42]\n')))")" "2 retries then alert|use the queue"
check "drift-5: the freeze with no STOP 1 line in stop1.log refused" "$(NOLOG=1 fz docs/p1.md "$F/records/atlas/atl-42-r22" --approved "$A1" | grep -c 'no STOP 1 for docs/p1.md')" 1
R23="$F/records/atlas/atl-42-r23"; lg "$R23" docs/p1.md "$A1"; lg "$R23" docs/p1.md "$(ap p1.md)"
check "process-1: an --approved that is not the newest STOP 1 refused" "$(NOLOG=1 fz docs/p1.md "$R23" --approved "$A1" | grep -c 'is not the sha of the newest STOP 1')" 1
check "N3: an old-shape spec with no --approved refused" "$(fz docs/atl-42-old.md | grep -c -- '--approved <sha> is required')" 1
# the owner's word: the spec freeze needs "<lane> r<n> spec ok" or "<lane> spec ok" typed by a person (origin.kind
# human) in lead-1's pane or the IC's, after the newest STOP 1, read from Claude Code's session logs
OW="$T/own"; RO="$F/records/atlas"
ow(){ python3 - "$HERE/../records" "$1" "$OW/$2" "$F/repo" "$L" <<'EOF'
import os, sys
shared, rec, root, ic, lead = sys.argv[1:6]
sys.path.insert(0, shared); import freeze_rules as f
try:
    r = f.owner_ok(rec, "docs/p1.md", ic, root=root, lead_cwd=lead, lead_old_cwd=os.environ.get("OLDLEAD") or None); print("ok", r["text"])
except f.Refused as e:
    print("refused", e.reasons[0])
EOF
}
o1(){ OLR="$OW/$1" olog "$2" "$3" "$4" "$5"; }   # <case root> <pane cwd> human|peer <local time> <text>
sl(){ python3 -c 'import os, sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.log_slug(os.path.realpath(sys.argv[2])))' "$HERE/../records" "$1"; }
NOOWN=1 lg "$RO/atl-77-r2" docs/p1.md "$A1"
check "owner-ok: the session-log folder name is the cwd with every / and . turned into -" "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.log_slug("/home/robin/Projects/atlas/src/github.com/example/atlas/.claude/worktrees/atlas-ic-2"))' "$HERE/../records")" "-home-robin-Projects-atlas-src-github-com-example-atlas--claude-worktrees-atlas-ic-2"
o1 a "$F/repo" human "2026-10-14 10:05" "ATL-77 r2 spec ok"
check "owner-ok: typed in the IC's pane after the newest STOP 1 found" "$(ow "$RO/atl-77-r2" a)" "ok ATL-77 r2 spec ok"
o1 b "$L" peer "2026-10-14 10:05" "ATL-77 r2 spec ok"; o1 b "$L" human "2026-10-14 10:06" "go on"
check "owner-ok: a relay from lead-1 (origin peer) only refused, hold and ask named" "$(ow "$RO/atl-77-r2" b | grep -c '^refused the owner.s "ATL-77 r2 spec ok" typed in this pane or lead-1.s pane after the newest STOP 1 .*was not found.*Hold and ask the owner.*never relay it, write it or forge it')" 1
o1 c "$L" human "2026-10-14 09:59" "ATL-77 r2 spec ok"; o1 c "$L" human "2026-10-14 10:00" "ATL-77 r2 spec ok"
check "owner-ok: typed before the newest STOP 1, or in its minute, refused" "$(ow "$RO/atl-77-r2" c | grep -c '^refused .*after the newest STOP 1 (2026-10-14 10:00')" 1
o1 d "$L" human "2026-10-14 10:05" "ATL-78 r2 spec ok"; o1 d "$L" human "2026-10-14 10:05" "ATL-77 r3 spec ok"
check "owner-ok: another lane or another rung refused" "$(ow "$RO/atl-77-r2" d | cut -c1-7)" refused
o1 e "$L" human "2026-10-14 10:05" "ATL-77 r2 spec back: line 3"
check "owner-ok: spec back refused" "$(ow "$RO/atl-77-r2" e | cut -c1-7)" refused
o1 f "$L" human "2026-10-14 10:05" "  atl-77 spec ok  "
check "owner-ok: the bare lane form typed in lead-1's pane, any case, found" "$(ow "$RO/atl-77-r2" f)" "ok atl-77 spec ok"
o1 g "$L" human "2026-10-14 10:05" "$(printf 'ATL-77 D1 a\nATL-77 r2 spec ok')"
check "owner-ok: the r<n> form on its own line of a longer message found" "$(ow "$RO/atl-77-r2" g | head -1)" "ok ATL-77 D1 a"
check "owner-ok: no session log folder refused" "$(ow "$RO/atl-77-r2" none | grep -c '^refused .*cannot be read: no session log folder')" 1
mkdir -p "$OW/h/$(sl "$L")"; printf '{"type":"user","message":{"role":"user","content":"ATL-77 r2 spec ok"},"origin":{"kind":"peer"},"timestamp":"2030-01-01T00:00:00.000Z"}\n{not json "human"\n' > "$OW/h/$(sl "$L")/t.jsonl"
check "owner-ok: a folder with no entry typed by a person refused, a bad JSON line skipped" "$(ow "$RO/atl-77-r2" h | grep -c '^refused .*no entry typed by a person')" 1
o1 i "$L" human "2026-10-14 10:05" "go on"; printf '{"type":"user","isCompactSummary":true,"origin":{"kind":"human"},"message":{"content":"ATL-77 r2 spec ok"},"timestamp":"2030-01-01T00:00:00.000Z"}\n' >> "$OW/i/$(sl "$L")/t.jsonl"
check "owner-ok: a compact summary quoting the words does not count" "$(ow "$RO/atl-77-r2" i | cut -c1-7)" refused
# the owner answering a card by quoting its line and adding the option: surrounding quotes and one trailing "(a)" are
# dropped before the match; any other word, and a relay of the same text, are still refused
o1 q1 "$L" human "2026-10-14 10:05" '"ATL-77 r2 spec ok"'
check "owner-ok: the word in straight quotes found" "$(ow "$RO/atl-77-r2" q1)" 'ok "ATL-77 r2 spec ok"'
o1 q2 "$L" human "2026-10-14 10:05" '“ATL-77 r2 spec ok”'
check "owner-ok: the word in curly quotes found" "$(ow "$RO/atl-77-r2" q2)" 'ok “ATL-77 r2 spec ok”'
o1 q3 "$L" human "2026-10-14 10:05" 'ATL-77 r2 spec ok (a)'
check "owner-ok: the word with a trailing (a) found" "$(ow "$RO/atl-77-r2" q3)" 'ok ATL-77 r2 spec ok (a)'
o1 q4 "$L" human "2026-10-14 10:05" '"ATL-77 r2 spec ok" (a)'
check "owner-ok: the word quoted with a trailing (a) found" "$(ow "$RO/atl-77-r2" q4)" 'ok "ATL-77 r2 spec ok" (a)'
o1 q5 "$L" human "2026-10-14 10:05" '"ATL-77 r2 spec ok, thanks" (a)'; o1 q5 "$L" human "2026-10-14 10:06" '"ATL-77 r2 spec ok" (a) (b)'
check "owner-ok: quoted with (a) and an extra word, or a second tag, refused" "$(ow "$RO/atl-77-r2" q5 | cut -c1-7)" refused
o1 q6 "$L" peer "2026-10-14 10:05" '"ATL-77 r2 spec ok" (a)'; o1 q6 "$L" human "2026-10-14 10:06" "go on"
check "owner-ok: the quoted word with (a) relayed by lead-1 (origin peer) refused" "$(ow "$RO/atl-77-r2" q6 | cut -c1-7)" refused
ak(){ python3 - "$HERE/../records" "$RO/atl-77-r2" "$OW/$1" "$L" <<'EOF'
import os, sys, time
shared, rec, root, lead = sys.argv[1:5]
sys.path.insert(0, shared); import freeze_rules as f
anchor = (time.mktime(time.strptime("2026-10-14 10:00", "%Y-%m-%d %H:%M")), "2026-10-14 10:00", "test")
try:
    r = f.amend_ok(rec, anchor, "a rules.md amendment", "card ATL-77 D3", [], root=root, lead_cwd=lead, lead_old_cwd=os.environ.get("OLDLEAD") or None); print("ok", r["card"])
except f.Refused as e:
    print("refused", e.reasons[0])
EOF
}
o1 m1 "$L" human "2026-10-14 10:05" '"ATL-77 r2 amend ok ATL-77 D3"'
check "amend-ok: the word in straight quotes found" "$(ak m1)" "ok ATL-77 D3"
o1 m2 "$L" human "2026-10-14 10:05" '“ATL-77 r2 amend ok ATL-77 D3”'
check "amend-ok: the word in curly quotes found" "$(ak m2)" "ok ATL-77 D3"
o1 m3 "$L" human "2026-10-14 10:05" 'ATL-77 r2 amend ok ATL-77 D3 (a)'
check "amend-ok: the word with a trailing (a) found, the tag not part of the card id" "$(ak m3)" "ok ATL-77 D3"
o1 m4 "$L" human "2026-10-14 10:05" '"ATL-77 r2 amend ok ATL-77 D3" (a)'
check "amend-ok: the word quoted with a trailing (a) found" "$(ak m4)" "ok ATL-77 D3"
o1 m5 "$L" human "2026-10-14 10:05" '"ATL-77 r2 amend ok ATL-77 D3 please" (a)'; o1 m5 "$L" human "2026-10-14 10:06" '"ok ATL-77 r2 amend ok ATL-77 D3" (a)'
check "amend-ok: quoted with (a) and an extra word refused" "$(ak m5 | cut -c1-7)" refused
o1 m6 "$L" peer "2026-10-14 10:05" '"ATL-77 r2 amend ok ATL-77 D3" (a)'; o1 m6 "$L" human "2026-10-14 10:06" "go on"
check "amend-ok: the quoted word with (a) relayed by lead-1 (origin peer) refused" "$(ak m6 | grep -c '^refused .*was not found in the session logs')" 1
check "owner-ok: the freeze with no owner's word refused, the reason printed, nothing written" "$(NOOWN=1 fz docs/p1.md "$RO/atl-77-r5" --approved "$A1" | grep -c -e 'freeze-rules: the owner.s "ATL-77 r5 spec ok" typed in this pane' -e '^rc=2$'):$(ls "$RO/atl-77-r5" | grep -c -e rules.md -e gate.md -e frozen.sha256)" "2:0"
# lead-1's folder before the move (migrate/agentmgmt-path): its log is read too, only when the caller names it
OLD="$T/oldam/Leads/lead-1"; mkdir -p "$OLD"
o1 n1 "$OLD" human "2026-10-14 10:05" "ATL-77 r2 spec ok"
check "N6 owner-ok: a human spec ok only in the old-folder log found" "$(OLDLEAD="$OLD" ow "$RO/atl-77-r2" n1)" "ok ATL-77 r2 spec ok"
check "N6 owner-ok: the same log with no old folder named is not read (unchanged)" "$(ow "$RO/atl-77-r2" n1 | cut -c1-7)" refused
o1 n2 "$OLD" peer "2026-10-14 10:05" "ATL-77 r2 spec ok"; o1 n2 "$OLD" human "2026-10-14 10:06" "go on"
check "N6 owner-ok: the same text with origin peer in the old folder refused" "$(OLDLEAD="$OLD" ow "$RO/atl-77-r2" n2 | grep -c '^refused .*was not found in the session logs')" 1
o1 n3 "$OLD" human "2026-10-14 10:05" "ATL-77 r2 amend ok ATL-77 D3"
check "N6 amend-ok: an amend ok only in the old-folder log found" "$(OLDLEAD="$OLD" ak n3)" "ok ATL-77 D3"
o1 n4 "$OLD" peer "2026-10-14 10:05" "ATL-77 r2 amend ok ATL-77 D3"; o1 n4 "$OLD" human "2026-10-14 10:06" "go on"
check "N6 amend-ok: the same text with origin peer in the old folder refused" "$(OLDLEAD="$OLD" ak n4 | grep -c '^refused .*was not found in the session logs')" 1
mkdir -p "$T/oh/migrate" "$T/oh2/migrate" "$T/oh3"; printf '%s\n' "$T/oldam" > "$T/oh/migrate/agentmgmt-path"; printf 'relative/path\n' > "$T/oh2/migrate/agentmgmt-path"
check "N6: agentmgmt-path gives <P>/Leads/lead-1; relative, missing or empty file gives None" "$(python3 -c 'import os, sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f
h = sys.argv[2]; print(f.old_lead_cwd(h + "/oh") == os.path.realpath(sys.argv[2] + "/oldam/Leads/lead-1"), f.old_lead_cwd(h + "/oh2"), f.old_lead_cwd(h + "/oh3"), f.old_lead_cwd(h + "/nope"))' "$HERE/../records" "$T")" "True None None None"
olog "$L" human "2026-10-14 10:03" "ATL-77 r5 spec ok"
check "owner-ok: the same freeze once the owner typed it in lead-1's pane writes" "$(NOLOG=1 fz docs/p1.md "$RO/atl-77-r5" --approved "$A1" | tail -1):$(ls "$RO/atl-77-r5" | grep -c -x -e rules.md -e gate.md -e frozen.sha256)" "rc=0:3"
check "owner-ok: the log root is not read from HOME" "$(HOME="$T/fh" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.SESSION_LOGS)' "$HERE/../records")" "$(python3 -c 'import os, pwd; print(os.path.join(pwd.getpwuid(os.getuid()).pw_dir, ".claude", "projects"))')"
mkdir -p "$T/records/orbit/orb-42-r1"
check "owner-ok: FLEET_RECORDS cannot make a folder legacy for the owner's word" "$(FLEET_RECORDS="$T/records" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.legacy(sys.argv[2]), f.owner_exempt(sys.argv[2]))' "$HERE/../records" "$T/records/orbit/orb-42-r1")" "True False"
rm -rf "$T/records/orbit/orb-42-r1"
RX="$T/records/atlas/atl-42-r30"; mkdir -p "$RX"; cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RF/stop1.log" "$RX/"
check "drift-5: the freeze's own files chain to the approved STOP 1 commit" "$(python3 "$FR" check "$RX" --repo "$I"; echo "rc=$?")" "rc=0"
sed -i '' "s|^approved .*|approved  $H|" "$RX/frozen.sha256"
check "drift-5: frozen.sha256 rewritten to a commit with no STOP 1 refused" "$(python3 "$FR" check "$RX" --repo "$I" | grep -c 'is not a STOP 1 sha')" 1
cp "$RF/frozen.sha256" "$RX/"
rehash(){ python3 - "$RX" "$1" <<'EOF'
import hashlib, re, sys
r, kind = sys.argv[1], sys.argv[2]
h = hashlib.sha256(open(f"{r}/{kind}.md", "rb").read()).hexdigest()
p = f"{r}/frozen.sha256"; t = open(p).read()
open(p, "w").write(re.sub(rf"^sha256 +[0-9a-f]{{64}}  {kind}\.md$", f"sha256    {h}  {kind}.md", t, flags=re.M))
EOF
}
perl -0pi -e 's/GATE BLOCK/# Amended 2026-10-14 10:00 by lead-1 (C3): line 1, kind a, ATL-42 C3\nGATE BLOCK/' "$RX/gate.md"; rehash gate
check "N1: a # Amended line and a Bash re-hash pass verify" "$(python3 "$FR" verify "$RX"; echo "rc=$?")" "rc=0"
check "N1: the same are refused by the chain: no history line" "$(python3 "$FR" check "$RX" --repo "$I" | grep -c 'has a `# Amended` line and frozen.sha256 has no gate history line')" 1
cp "$RF/gate.md" "$RF/frozen.sha256" "$RX/"; perl -pi -e 's/exit 0, "0 failed" in the summary line/exit 0/' "$RX/gate.md"   # a pass line weakened
cp "$RX/gate.md" "$RX/gate-pre-2026-10-14-1200.md"; perl -0pi -e 's/GATE BLOCK/# Amended 2026-10-14 12:00 by lead-1 (C4): line 1, kind a, ATL-42 C4\nGATE BLOCK/' "$RX/gate.md"; rehash gate
printf 'history   2026-10-14 12:00 · gate · forged · was %s · copy gate-pre-2026-10-14-1200.md\n' "$(hx "$RX/gate-pre-2026-10-14-1200.md")" >> "$RX/frozen.sha256"
check "process-5: a forged history copy with a weakened pass line refused: gate.md as frozen is not the approved Checks" "$(python3 "$FR" verify "$RX"; echo "rc=$?"; python3 "$FR" check "$RX" --repo "$I" | grep -c "gate.md as frozen is not the approved spec's Checks")" "rc=0
1"
rm -f "$RX"/gate-pre-*; cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RX/"
python3 -c "import sys; p=sys.argv[1]; open(p+'.n','w').write(''.join(l for l in open(p) if 'nightly imports only' not in l))" "$RX/rules.md"; mv "$RX/rules.md.n" "$RX/rules.md"; rehash rules
check "N2: a Decided row dropped from rules.md with a Bash re-hash refused against the approved spec" "$(python3 "$FR" verify "$RX"; echo "rc=$?"; python3 "$FR" check "$RX" --repo "$I" | grep -c 'has a DECIDED row rules.md as frozen does not: .*nightly imports only')" "rc=0
1"
rm -rf "$RX"
RP="$T/records/orbit/orb-42-r2"; mkdir -p "$RP"; cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RP/"; sed -i '' "s|^approved .*|approved  $H|" "$RP/frozen.sha256"
# the list is the test's own copy beside $SH/frozen.py: the real one loses a folder when its rung closes
: > "$SH/frozen-before-stop1-log.txt"
check "pre-log: a folder frozen before stop1.log, not listed, fails the chain" "$(python3 "$SH/frozen.py" check "$RP" --repo "$I" | grep -c 'is not a STOP 1 sha')" 1
printf 'orbit/orb-42-r2\n' > "$SH/frozen-before-stop1-log.txt"
check "pre-log: the same folder listed skips the chain" "$(python3 "$SH/frozen.py" check "$RP" --repo "$I"; echo "rc=$?")" "rc=0"
printf '  one more rule\n' >> "$RP/rules.md"
check "pre-log: a listed folder is still hash-checked" "$(python3 "$SH/frozen.py" check "$RP" --repo "$I" | grep -c 'rules.md does not match')" 1
rm -rf "$RP" "$SH/frozen-before-stop1-log.txt"
check "stop1-log: a STOP 1 that passes leaves its line in stop1.log" "$(grep -c "· STOP 1 · spec docs/atl-42-spec.md @ $(git -C "$I" rev-parse "$HS") · test-ic · session holes$" "$R/stop1.log" | awk '{print ($1 > 0) ? "yes" : "no"}')" yes
mv "$R/evidence.md" "$T/ev.keep"
s1m(){ send "$I" "$(printf '"atlas · ATL-42 r1 · STOP 1 · 10:00 · holding on lead-1\\n  spec       docs/atl-42-spec.md @ %s%s"' "$HS" "$1")"; }
check "process-10: a STOP 1 naming the folder as ~/.fleet-agent-mgmt/records/... is gated" "$(s1m '\n  files record ~/.fleet-agent-mgmt/records/atlas/atl-42-r1/' | grep -c 'STOP 1 GATE: no evidence.md')" 1
check "N4: a STOP 1 with the record folder left out denied" "$(s1m '' | grep -c 'does not name it')" 1
RL="$T/records/orbit/orb-42-r1"; mkdir -p "$RL"; printf '# ORB-42 rung 1 · decision record · test-ic\n' > "$RL/decision-record.md"
check "process-10: a legacy folder named first does not skip the live folder's STOP 1 gate" "$(s1m "$(printf '\\n  files record %s/ record %s/' "$RL" "$R")" | grep -c 'STOP 1 GATE: no evidence.md')" 1
check "process-10: a STOP naming only the legacy folder while the live one is open denied" "$(send "$I" "$(printf '"x · STOP 2 · y\\n  files record %s/"' "$RL")" | grep -c 'does not name it')" 1
mkdir -p "$F/records/orbit/orb-42-r1"
check "legacy: the same two names under another folder are not legacy" "$(python3 -c "import sys; sys.path.insert(0, '$HERE/../records'); import freeze_rules as f; print(f.legacy('$RL'), f.legacy('$F/records/orbit/orb-42-r1'))")" "True False"
rm -rf "$RL"; mv "$T/ev.keep" "$R/evidence.md"
mkdir -p "$I/docs/specs"; printf '# X\n\nsome text\n---\n' > "$I/docs/specs/x.md"
git -C "$I" add docs/specs/x.md; git -C "$I" -c user.name=t commit -qm doc; green "$(git -C "$I" rev-parse HEAD)"
check "process-7: the push reads a committed spec whole: a render fault denied" "$(pg 'git push origin feat/atl-42' | grep -c 'LEAK GATE: .*text above ---')" 1
git -C "$I" reset -q --hard "$H"; green
check "rule-under-table: --- right under a table row is not a heading underline" "$(printf '# T\n\n| a |\n|---|\n| 1 |\n---\n' | python3 "$HERE/leak_check.py" --doc - --path docs/specs/x.md; echo "rc=$?")" "rc=0"
check "rule-under-table: --- under a text line still refused" "$(printf '# T\n\ntext\n---\n' | python3 "$HERE/leak_check.py" --doc - --path docs/specs/x.md | grep -c 'text above ---')" 1
tspec '```\n  proves done   make test\n  pass          exit 0\n  on main       exit 0\n    ```' t-f4.md
check "fence-4: a fence whose closing line is indented 4 spaces is not closed, as on GitHub: the fold falls inside it" "$(ck "$F/repo/docs/t-f4.md" 'no `---` fold')" "1:rc=2"
tspec '~~~\n  proves done   make test\n  pass          exit 0\n  on main       exit 0\n~~~' t-tilde.md
check "fence-4: a ~~~ fence freezes" "$(ck "$F/repo/docs/t-tilde.md" x)" "0:rc=0"
tspec '```\n  proves done   make test\n  pass          exit 0\n  on main       exit 0\n~~~' t-mixed.md
check "fence-4: a backtick fence is not closed by ~~~" "$(ck "$F/repo/docs/t-mixed.md" 'no `---` fold')" "1:rc=2"
vr bq "## Decided\n" "> ## Decided\n"
check "container: a Decided heading in a block quote refused, not left out" "$(ck "$F/v-bq.md" 'inside a block quote or a list')" "1:rc=2"
vr li "## Decided\n" "- ## Decided\n"
check "container: a Decided heading in a list item refused" "$(ck "$F/v-li.md" 'inside a block quote or a list')" "1:rc=2"
vr se "## Decided\n" "Decided\n-------\n"
check "setext: an underlined Decided heading refused, not left out" "$(ck "$F/v-se.md" 'an underlined heading')" "1:rc=2"
vr ch "## Terms\n" "## Terms ##\n"
check "heading: ## Terms ## refused for its closing # marks" "$(ck "$F/v-ch.md" 'it ends in closing `#` marks')" "1:rc=2"
vr so "| ATL-42, definition of done |" "| standing order 7 |"
check "source: a source cell that only starts with standing freezes" "$(ck "$F/v-so.md" x)" "0:rc=0"
vr so2 "| ATL-42, definition of done |" "| standing |"
check "source: a source cell reading standing still refused" "$(ck "$F/v-so2.md" 'reads as a rules.md tag')" "1:rc=2"
check "template: the # cell is named: 1, 1., ✔ 1 or D1, never Q1" "$(grep -c 'never Q1' "$HERE/../skills/writing-a-design-spec/templates/design-spec.md")" 1
check "amend: refused from a folder that is not lead-1's" "$(am gate 'line 1 kind a' "$T" | grep -c "not lead-1's folder in FLEET_HOME/roster.md")" 1
mkdir -p "$T/fake"; printf '```fleet\nlead-1\t%s\n```\n' "$T/fake" > "$T/fake/roster.md"
check "amend: FLEET_ROSTER naming another lead-1 folder is not read" "$(FLEET_ROSTER="$T/fake/roster.md" am gate 'line 1 kind a' "$T/fake" | grep -c "not lead-1's folder in FLEET_HOME/roster.md")" 1
check "amend: FLEET_HOME in the environment naming a fake lead-1 row is not read (settings home decides)" "$(FLEET_HOME="$T/fake" am gate 'line 1 kind a' "$T/fake" | grep -c "not lead-1's folder in FLEET_HOME/roster.md")" 1
check "bash-write: a redirect into frozen.sha256 denied" "$(pg "echo x > $R/frozen.sha256" | grep -c 'FROZEN WRITE GATE')" 1
check "bash-write: a python write to stop1.log denied" "$(pg "python3 -c 'open(\"$R/stop1.log\",\"a\").write(\"x\")'" | grep -c 'FROZEN WRITE GATE')" 1
check "bash-write: sed -i on the record's rules.md denied" "$(pg "sed -i '' s/a/b/ $R/rules.md" | grep -c 'FROZEN WRITE GATE')" 1
check "bash-write: amend-frozen run by an IC denied" "$(pg "bash $HERE/../amend-frozen.sh $R gate x" | grep -c 'FROZEN WRITE GATE: this command runs an amendment')" 1
check "bash-write: reading frozen.sha256 allowed" "$(pg "cat $R/frozen.sha256")" allow
check "bash-write: a repo file named rules.md is not a record file" "$(pg 'cp a docs/rules.md')" allow
check "bash-write: an IC Write to stop1.log denied" "$(fg "$R/stop1.log")" "FROZEN:"
check "bash-write: a redirect into a session log under ~/.claude/projects denied" "$(pg "echo '{}' >> ~/.claude/projects/-home-robin-Projects-fleet-Leads-lead-1/x.jsonl" | grep -c "^FROZEN WRITE GATE: this command names Claude Code's session logs")" 1
check "bash-write: a python write into a session log denied" "$(pg "python3 -c 'open(\"\$HOME/.claude/projects/a/b.jsonl\",\"a\").write(\"x\")'" | grep -c 'session logs')" 1
check "bash-write: a cd into the session logs, then a redirect, denied" "$(pg 'cd ~/.claude/projects/-home-x && echo hi > z.jsonl' | grep -c 'session logs')" 1
check "bash-write: cp and tee into the session logs denied" "$(pg 'cp /tmp/f.jsonl $HOME/.claude/projects/a/' | grep -c 'session logs'):$(pg 'cd ~/.claude && printf x | tee projects/a/b.jsonl' | grep -c 'session logs')" "1:1"
check "bash-write: reading the session logs allowed" "$(pg 'grep -c ok ~/.claude/projects/a/*.jsonl 2>/dev/null')" allow
mkdir -p "$T/c/.claude/projects/x"; ln -s "$T/c/.claude/projects/x" "$T/lnk"
check "session-logs: an IC Write or Edit under ~/.claude/projects denied, through a link too" "$(fg "$HOME/.claude/projects/x/y.jsonl"):$(fg "$T/lnk/y.jsonl")" "SESSION:SESSION"
check "session-logs: an IC Write to its memory folder under ~/.claude/projects allowed" "$(fg "$HOME/.claude/projects/x/memory/note.md")" ""
# append-only records (ATL-42 S2): an IC's Edit adding DR3 anchored on UAT1's undo line, so DR3 landed above
# UAT1's jev line; the hook re-checked UAT1, DR3 was never checked, the audit failed at the push.
S=append; mkdir -p "$T/checks/test-ic/skills/$S"
mark "$I" Skill '{"skill":"recording-a-decision"}' >/dev/null; mark "$I" Skill '{"skill":"recording-evidence"}' >/dev/null
R9="$T/records/atlas/atl-42-r9"; mkdir -p "$R9"
printf 'rules · ATL-42 r9 · frozen at 9b2e7c1\n\nONE-WAY  stop and ask before:\n  force-push to any remote branch   [standing]\n  any run against the shared dev database   [gate block]\n\nDECIDED  never change:\n  ✔ 1  the retry wraps the scheduler call, never importer.run()   retry.py, new   [brief 3]\n\nREJECTED  do not come back to:\n  retry forever   [brief]\n' > "$R9/rules.md"; seal "$R9"
D9="$R9/decision-record.md"; E9="$R9/evidence.md"
printf '# ATL-42 rung 9 · decision record · test-ic\ngoal: x\nrules: 9b2e7c1\nplan: p\n\nATL-42 DR1 · task 2 · 2026-10-14 11:00 · test-ic\n  plan        2 "x"\n  decided     wrap scheduler.nightly()\n  undo        git revert a\n\nATL-42 UAT1 · 2026-10-14 11:10 · test-ic\n  words       "name the file" (test-ic pane, 11:09)\n  done        the alert names the file\n  commit      c3d4e5f\n  undo        git revert c3d4e5f\n' > "$D9"
check "append: the hook checks DR1 and UAT1 and audits after the write" "$(dr "$I" "$D9" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | tail -1)" "jev audit: exit 0, 2 jev lines, each with its receipt."
NEW='\n\nATL-42 DR2 · task 5 · 2026-10-14 11:20 · test-ic\n  plan        5 "push"\n  decided     push feat/atl-42\n  undo        git push --delete origin feat/atl-42'
ed(){ jq -n --arg o "$1" --arg n "$2" '{old_string:$o,new_string:$n}'; }
check "append: the incident, an Edit anchored on UAT1's undo line above its jev line, denied" "$(ae Edit "$D9" "$(ed '  undo        git revert c3d4e5f' "$(printf "  undo        git revert c3d4e5f$NEW")")" | grep -c '^APPEND ONLY: this Edit on .* anchors on text that is not the end of the file (old_string ends at line 16 of 18).*record-add.sh')" 1
last="$(tail -2 "$D9")"
check "append: an Edit appending after the file's last line allowed" "$(ae Edit "$D9" "$(ed "$last" "$(printf "%s$NEW" "$last")")")" allow
check "append: an Edit rewriting the last line denied" "$(ae Edit "$D9" "$(ed "$last" '  jev         continue, max yes 0.00 · jev-stub')" | grep -c 'changes the file.s last line')" 1
check "append: a MultiEdit whose second edit is mid-file denied" "$(ae MultiEdit "$D9" "$(jq -n --arg l "$last" --arg n "$(printf "%s$NEW" "$last")" '{edits:[{old_string:$l,new_string:$n},{old_string:"  commit      c3d4e5f",new_string:"  commit      0000000"}]}')" | grep -c '^APPEND ONLY: edit 2 of 2')" 1
check "append: an old_string matching two places (two jev lines read the same) denied" "$(ae Edit "$D9" "$(ed "$(tail -1 "$D9")" "$(printf "%s$NEW" "$(tail -1 "$D9")")")" | grep -c '^APPEND ONLY: this Edit on .*: old_string matches 2 places')" 1
check "append: a replace_all over two matches denied" "$(ae Edit "$D9" "$(jq -n '{old_string:"test-ic",new_string:"test-ic x",replace_all:true}')" | grep -c '^APPEND ONLY')" 1
check "append: a Write over the existing record denied, naming record-add.sh" "$(ae Write "$D9" "$(jq -n '{content:"# ATL-42 rung 9 · decision record · test-ic\n"}')" | grep -c '^APPEND ONLY: .* exists; a Write replaces the whole file.*record-add.sh')" 1
check "append: a Write creating the record with its header allowed" "$(ae Write "$T/records/atlas/atl-42-r10/decision-record.md" "$(jq -n '{content:"# ATL-42 rung 10 · decision record · test-ic\ngoal: x\n"}')")" allow
check "append: a Write creating the record with an entry before the header denied" "$(ae Write "$T/records/atlas/atl-42-r10/decision-record.md" "$(jq -n '{content:"ATL-42 DR1 · task 1 · 2026-10-14 11:00 · test-ic\n  decided     x\n"}')" | grep -c '^HEADER FIRST')" 1
printf '# ATL-42 rung 9 · evidence · test-ic\n\n## E1 make test on origin/main · 2026-10-14 10:00\n  ran       make test\n  exit      0\n\n## E2 probe · 2026-10-14 10:05\n  ran       x\n  exit      0\n' > "$E9"
check "append: evidence.md, a mid-file Edit denied" "$(ae Edit "$E9" "$(ed '  exit      0
' '  exit      0

## E3 inserted · 2026-10-14 10:06
  ran       y
  exit      0
')" | grep -c '^APPEND ONLY')" 1
check "append: evidence.md, an end-of-file Edit allowed" "$(ae Edit "$E9" "$(ed '  ran       x
  exit      0' '  ran       x
  exit      0

## E3 rerun · 2026-10-14 10:06
  ran       y
  exit      0')")" allow
check "append: evidence.md, a Write over it denied" "$(ae Write "$E9" '{"content":"x"}' | grep -c '^APPEND ONLY')" 1
la(){ o="$(jq -n --arg d "$L" --arg s "$S" --arg t "$1" --arg p "$2" --argjson e "$3" '{cwd:$d,session_id:$s,tool_name:$t,tool_input:({file_path:$p}+$e)}' | "$HERE/artefact-gate.sh" 2>/dev/null)"; [ -n "$o" ] && printf '%s' "$o" | jq -r ".hookSpecificOutput.permissionDecisionReason" || echo allow; }
check "append: lead-1 is not guarded: a review line written mid-file allowed" "$(la Edit "$D9" "$(ed '  undo        git revert a' '  undo        git revert a
  review      ok')")" allow
# record-add.sh: numbered from the file, checked, audited
ra(){ (cd "$I" && JEV_ENV="$T/nokey" JEV_URL="http://127.0.0.1:9/" JEV_STUB="$T/stub-ok.json" "$HERE/../records/record-add.sh" "$@" 2>&1); }
o="$(printf 'task 5\n  plan        5 "push"\n  decided     push feat/atl-42\n  undo        git push --delete origin feat/atl-42\n' | ra "$R9" dr)"
check "record-add: numbers the next DR from the file" "$(printf '%s\n' "$o" | head -1)" "record-add: ATL-42 DR2 appended to $D9"
check "record-add: the jev line lands under the new entry, each under its own" "$(awk '/^ATL-42 (DR|UAT)[0-9]+ ·/{e=$2} /^  jev/{print e}' "$D9" | tr '\n' ' ')" "DR1 UAT1 DR2 "
check "record-add: prints the audit" "$(printf '%s\n' "$o" | tail -1)" "audit: exit 0, every jev line in decision-record.md has its receipt"
check "record-add: evidence numbered E3" "$(printf 'rerun\n  ran       y\n  exit      0\n' | ra "$R9" e | head -1)" "record-add: E3 appended to $E9"
# audit after every write: the incident's file shape, written past the guard, shows at the write
printf '\nATL-42 DR3 · task 6 · 2026-10-14 12:00 · test-ic\n  decided     open PR 88 as a draft\n  undo        gh pr close 88\n' > "$T/dr3"
python3 - "$D9" "$T/dr3" <<'PY'
import sys
p, add = sys.argv[1], open(sys.argv[2]).read()
t = open(p).read(); k = t.index("  undo        git revert c3d4e5f\n") + len("  undo        git revert c3d4e5f\n")
open(p, "w").write(t[:k] + add.lstrip("\n") + t[k:])
PY
ctx="$(dr "$I" "$D9" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext')"
check "audit-after: DR3 written above UAT1's jev line: the audit fails at the write, naming DR3" "$(printf '%s\n' "$ctx" | grep -c '^jev audit: exit 1. ATL-42 DR3: jev "continue, max yes 0.08 · jev-stub" has no receipt.*tell lead-1')" 1
check "audit-after: the hook re-checked UAT1, never DR3 (what the audit catches)" "$(printf '%s\n' "$ctx" | grep -o '^jev · ATL-42 [A-Z]*[0-9]' | tr '\n' ' ')" "jev · ATL-42 UAT1 "
# Bash: record writes outside record-add.sh
check "record-bash: sed -i on the decision record denied" "$(pg "sed -i '' s/a/b/ $D9" | grep -c '^RECORD WRITE GATE')" 1
check "record-bash: an append with >> to evidence.md denied" "$(pg "printf x >> $E9" | grep -c '^RECORD WRITE GATE')" 1
check "record-bash: a python write denied" "$(pg "python3 -c 'open(\"$D9\",\"a\").write(\"x\")'" | grep -c '^RECORD WRITE GATE')" 1
check "record-bash: reading with tail allowed" "$(pg "tail -5 $D9")" allow
check "record-bash: dr_check.py --audit allowed" "$(pg "python3 $HERE/dr_check.py $D9 --audit")" allow
RA="$(printf '%s/../records/record-add.sh %s dr <<'"'"'EOF'"'"'\ntask 5\n  decided     push feat/atl-42; cp a b > %s\n  undo        git push --delete origin feat/atl-42\nEOF' "$HERE" "$R9" "$D9")"
check "record-bash: record-add.sh allowed, its body (git push --delete, a redirect) read as data" "$(pg "$RA")" allow
S=append-cold; mkdir -p "$T/checks/test-ic/skills/$S"
check "record-bash: record-add.sh before the skill denied (SKILL GATE)" "$(pg "$RA" | grep -c '^SKILL GATE: record-add.sh dr writes the record with the recording-a-decision skill')" 1
check "record-bash: record-add.sh --dump before the skill allowed" "$(pg "$HERE/../records/record-add.sh --dump $R9 dr < /dev/null")" allow
check "record-bash: lead-1 not gated" "$(o="$(jq -n --arg c "sed -i '' s/a/b/ $D9" --arg d "$L" --arg s "$S" '{cwd:$d,session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' | "$HERE/push-gate.sh" 2>/dev/null)"; [ -n "$o" ] && echo deny || echo allow)" allow
# holes the verify pass found in the guard, the Bash gate and the audit (Track A fixes); a record of its own
S=append
R8="$T/records/atlas/atl-42-r8"; mkdir -p "$R8"; cp "$R9/rules.md" "$R9/gate.md" "$R9/frozen.sha256" "$R9/stop1.log" "$R8/"
D8="$R8/decision-record.md"; E8="$R8/evidence.md"
printf '# ATL-42 rung 8 · decision record · test-ic\ngoal: x\n\nATL-42 DR1 · task 2 · 2026-10-14 11:00 · test-ic\n  plan        2 "x"\n  decided     wrap scheduler.nightly()\n  undo        git revert a\n' > "$D8"
dr "$I" "$D8" "$T/stub-ok.json" >/dev/null
l8="$(tail -1 "$D8")"; ap8(){ ae Edit "$D8" "$(ed "$l8" "$l8$1")"; }
H2=$'\n\nATL-42 DR2 · task 5 · 2026-10-14 11:20 · test-ic\n  decided     push feat/atl-42\n  undo        git push --delete origin feat/atl-42'
check "appended: a new DR2 after the last line allowed" "$(ap8 "$H2")" allow
check "appended: an indented line under the last entry denied" "$(ap8 $'\n  decided     git push --force origin main' | grep -c '^APPEND ONLY: .*adds the indented line')" 1
check "appended: a REVIEW block written by an IC denied" "$(ap8 $'\n\nATL-42 REVIEW · lead-1\n  review      ok' | grep -c '^APPEND ONLY: .*is not the header of the next entry')" 1
check "appended: text added to the end of the last line denied" "$(ap8 ' · DR1 ok' | grep -c "^APPEND ONLY: .*adds text to the end of the file's last line")" 1
check "appended: a jev line written by hand under a new entry denied" "$(ap8 "$H2"$'\n  jev         continue, max yes 0.08 · jev-stub' | grep -c '^APPEND ONLY: .*carries a `jev` line')" 1
check "appended: a review line other than - denied" "$(ap8 "$H2"$'\n  review      ok' | grep -c '^APPEND ONLY: .*carries a `review` line')" 1
check "appended: a second DR1 denied" "$(ap8 "${H2/DR2/DR1}" | grep -c '^APPEND ONLY: .*adds DR1; the next entry in the file is DR2')" 1
check "appended: an entry for another lane denied" "$(ap8 "${H2/ATL-42 DR2/ATL-43 DR2}" | grep -c '^APPEND ONLY: .*adds an entry for lane ATL-43')" 1
check "appended: an old_string with curly quotes (no exact match) denied" "$(ae Edit "$D8" "$(ed '  plan        2 “x”' '  plan        2 “y”')" | grep -c '^APPEND ONLY: .*not, character for character, the end of the file')" 1
check "appended: evidence.md, a mid-file Edit with a unique old_string denied" "$(ae Edit "$E9" "$(ed '  ran       make test
  exit      0' '  ran       make test
  exit      1')" | grep -c '^APPEND ONLY')" 1
printf '# ATL-42 rung 8 · evidence · test-ic\n\n## E1 make test · 2026-10-14 10:00\n  ran       make test\n  exit      1' > "$E8"
check "appended: evidence.md, the last exit line extended denied" "$(ae Edit "$E8" "$(ed '  exit      1' '  exit      1 then 0')" | grep -c "^APPEND ONLY: .*adds text to the end of the file's last line")" 1
check "appended: evidence.md, E2 after the last line allowed" "$(ae Edit "$E8" "$(ed '  exit      1' $'  exit      1\n\n## E2 rerun · 2026-10-14 10:05\n  ran       make test\n  exit      0')")" allow
# receipts: only the Jev check writes one
check "receipts: an IC Write to receipts/*-jev-*.json denied" "$(ae Write "$R8/receipts/2026-10-14-1100-jev-DR2.json" '{"content":"{}"}' | grep -c '^RECEIPTS: ')" 1
check "receipts: a Bash cp into a -jev- receipt denied" "$(pg "cp $T/stub-ok.json $R8/receipts/2026-10-14-1100-jev-DR2.json" | grep -c '^RECORD WRITE GATE')" 1
# receipt trust: a receipt made with JEV_STUB, another JEV_URL or DR_STANDING does not count
au(){ python3 "$HERE/dr_check.py" "$1" --audit 2>&1; echo "rc=$?"; }
check "receipt-trust: a stubbed receipt counts only under JEV_STUB_OK=1 (tests)" "$(au "$D8" | tail -1)" "rc=0"
check "receipt-trust: a stubbed receipt does not count in the hook's env" "$(env -u JEV_STUB_OK python3 "$HERE/dr_check.py" "$D8" --audit 2>&1 | grep -c '^ATL-42 DR1: .*has only a receipt made with JEV_STUB, another JEV_URL or DR_STANDING')" 1
check "receipt-trust: a receipt asked with another DR_STANDING does not count" "$(DR_STANDING=split au "$D8" | grep -c 'has only a receipt made with')" 1
R7="$T/records/atlas/atl-42-r7"; mkdir -p "$R7"; cp -R "$D8" "$R8/receipts" "$R7/"
for f in "$R7"/receipts/*.json; do python3 -c 'import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["stub"]=None; r["request"]["url"]="http://127.0.0.1:9/"; json.dump(r,open(p,"w"))' "$f"; done
check "receipt-trust: a receipt from another JEV_URL (a local server) does not count" "$(au "$R7/decision-record.md" | grep -c '^ATL-42 DR1: .*has only a receipt made with')" 1
check "receipt-trust: record-add.sh names the vars set in its shell" "$(printf 'task 6\n  decided     x\n  undo        y\n' | ra "$R7" dr | grep -c '^record-add: .*JEV_STUB.* set in this shell: the receipt records it, and the audit at ready for push and at the push does not count it')" 1
# the audit: an entry with no jev line, an id written twice
printf '# ATL-42 rung 7 · decision record · test-ic\n\nATL-42 DR1 · task 2 · 2026-10-14 11:00 · test-ic\n  decided     x\n  undo        y\n' > "$T/unchecked.md"
check "audit: an entry with no jev line fails, named" "$(au "$T/unchecked.md" | grep -c '^ATL-42 DR1: has no jev line\|^rc=1')" 2
R6="$T/records/atlas/atl-42-r6"; mkdir -p "$R6"; cp "$R9/rules.md" "$R9/gate.md" "$R9/frozen.sha256" "$R9/stop1.log" "$R6/"
printf '# ATL-42 rung 6 · decision record · test-ic\n' > "$R6/decision-record.md"
printf 'task 2\n  decided     x\n  undo        y\n' | (cd "$I" && JEV_ENV="$T/nokey" JEV_STUB=/nonexistent "$HERE/../records/record-add.sh" "$R6" dr >/dev/null 2>&1)
check "audit: record-add.sh with JEV_STUB naming no file fails its audit" "$(env -u JEV_STUB_OK python3 "$HERE/dr_check.py" "$R6/decision-record.md" --audit >/dev/null 2>&1; echo "rc=$?")" "rc=1"
cp "$D8" "$T/twice.md"; mkdir -p "$T/receipts"; cp "$R8"/receipts/*.json "$T/receipts/"; sed -n '4,$p' "$D8" | sed '1s/^/\n/' >> "$T/twice.md"
check "audit: an id written twice fails, named" "$(au "$T/twice.md" | grep -c '^ATL-42 DR1: written twice')" 1
# any spelling of the path is the file: case, /./, //, a link to the folder
check "spelling: an Edit on DECISION-RECORD.MD mid-file denied" "$(ae Edit "$R8/DECISION-RECORD.MD" "$(ed '  plan        2 "x"' '  plan        2 "y"')" | grep -c '^APPEND ONLY')" 1
check "spelling: a Write over Decision-Record.md denied" "$(ae Write "$R8/Decision-Record.md" '{"content":"x"}' | grep -c '^APPEND ONLY')" 1
check "spelling: a Write to RULES.md denied as frozen" "$(fg "$R8/RULES.md")" "FROZEN:"
check "spelling: Bash sed -i on DECISION-RECORD.md denied" "$(pg "sed -i '' s/a/b/ $R8/DECISION-RECORD.md" | grep -c '^RECORD WRITE GATE')" 1
check "spelling: an Edit through /./ mid-file denied" "$(ae Edit "$T/records/atlas/./atl-42-r8/decision-record.md" "$(ed '  plan        2 "x"' '  plan        2 "y"')" | grep -c '^APPEND ONLY')" 1
check "spelling: an Edit through // mid-file denied" "$(ae Edit "$T/records//atlas/atl-42-r8/decision-record.md" "$(ed '  plan        2 "x"' '  plan        2 "y"')" | grep -c '^APPEND ONLY')" 1
ln -s "$R8" "$I/rec-link"
check "spelling: an Edit through a link to the folder, in the worktree, denied" "$(ae Edit "$I/rec-link/decision-record.md" "$(ed '  plan        2 "x"' '  plan        2 "y"')" | grep -c '^APPEND ONLY')" 1
check "spelling: Bash sed -i through the link, by a relative name, denied" "$(pg "sed -i '' s/a/b/ rec-link/decision-record.md" | grep -c '^RECORD WRITE GATE')" 1
printf '%s\n' "${H2#$'\n'}" >> "$D8"
check "spelling: the dr-check hook runs on DECISION-RECORD.md" "$(dr "$I" "$R8/DECISION-RECORD.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c '^jev · ATL-42 DR2')" 1
printf '\nATL-42 DR3 · task 6 · 2026-10-14 11:30 · test-ic\n  decided     x\n  undo        y\n' >> "$D8"
check "spelling: the dr-check hook runs through the link" "$(dr "$I" "$I/rec-link/decision-record.md" "$T/stub-ok.json" | jq -r '.hookSpecificOutput.additionalContext' | grep -c '^jev · ATL-42 DR3')" 1
rm "$I/rec-link"
# Bash write forms the first gate missed
n=0; while IFS= read -r c; do case "$(pg "${c//@D/$D8}")" in "RECORD WRITE GATE"*) n=$((n+1));; *) printf 'not denied: %s\n' "$c";; esac; done <<'FORMS'
sed -E -i '' s/a/b/ @D
sed -e s/a/b/ -i '' @D
echo x >> "@D"
cd "$(dirname @D)" && sed -i '' s/a/b/ decision-record.md
/usr/bin/tee -a @D < /dev/null
awk -i inplace 1 @D
vim -es -c '%s/a/b/' -c wq @D
patch @D < /dev/null
FORMS
check "record-bash: each of the 8 write forms denied (sed flags, quoted name, cd, /usr/bin/tee, awk, vim, patch)" "$n" 8
# heredocs: only a quoted one read by record-add.sh itself is data
check "heredoc: X=record-add.sh bash <<EOF2 is read as a command" "$(pg "X=record-add.sh bash <<'EOF2'
git push --force origin main
EOF2" | grep -c 'PUSH FLAG GATE')" 1
check "heredoc: bash <<EOF2; : record-add.sh is read as a command" "$(pg "bash <<'EOF2'; : record-add.sh
git push --force origin main
EOF2" | grep -c 'PUSH FLAG GATE')" 1
check "heredoc: bash -s record-add.sh <<EOF2 is read as a command" "$(pg "bash -s record-add.sh <<'EOF2'
git push --force origin main
EOF2" | grep -c 'PUSH FLAG GATE')" 1
check "heredoc: bash <<EOF with record-add.sh in a comment is read as a command" "$(pg "bash <<EOF # record-add.sh
sed -i '' s/a/b/ $R8/rules.md
EOF" | grep -c 'FROZEN WRITE GATE')" 1
check "heredoc: record-add.sh with an unquoted delimiter denied" "$(pg "$HERE/../records/record-add.sh $R8 dr <<EOF
task 7
  decided     \$(git push --force origin main)
EOF" | grep -c '^RECORD WRITE GATE: record-add.sh reads its entry from a heredoc whose delimiter is not quoted')" 1
S=append-cold2; mkdir -p "$T/checks/test-ic/skills/$S"
check "skill-gate: a quoted \"dr\" kind before the skill denied" "$(pg "$HERE/../records/record-add.sh $R8 \"dr\" <<'EOF2'
task 7
  decided     x
EOF2" | grep -c '^SKILL GATE: record-add.sh dr')" 1
check "skill-gate: a --dump first does not pass a second call before the skill" "$(pg "$HERE/../records/record-add.sh --dump $R8 dr </dev/null; $HERE/../records/record-add.sh $R8 dr <<'EOF2'
task 7
  decided     x
EOF2" | grep -c '^SKILL GATE: record-add.sh dr')" 1
check "skill-gate: bash record-add.sh 'e' before the skill denied" "$(pg "bash $HERE/../records/record-add.sh \"$R8\" 'e' <<'EOF2'
x
  ran       y
  exit      0
EOF2" | grep -c '^SKILL GATE: record-add.sh e')" 1
# a chore (ATL-42 CH2 a): no spec, no STOP 1. lead-1 freezes the handoff's `## Checks` before launch with
# freeze-rules.sh --chore: rules.md the standing block only, gate.md the Checks, frozen.sha256 a chore line
cp "$HERE"/../frozen.py "$SH/"; cp "$HERE"/../records/{freeze_rules.py,gate_run.py,freeze-rules.sh} "$SH/records/"; sed -i '' -e "s|^USER_SETTINGS = .*|USER_SETTINGS = \"$SH/user-settings.json\"|" "$SH/records/freeze_rules.py"
S=chore; mkdir -p "$T/checks/test-ic/skills/$S"; mark "$I" Skill '{"skill":"reporting-a-rung"}' >/dev/null
CT='## Checks

| command | pass | on main |
|---|---|---|
| `echo "3 passed"` | exit 0, "3 passed" | exit 0, "3 passed" |'
ho(){   # $1 record folder, $2 the Checks block (default $CT), $3 CHAIN step 1 (default a build step)
  mkdir -p "$1"
  { printf '# ATL-50 · atlas · chore, spec cleanup · test-ic · 2026-10-14 10:00\n\n## 0. Gate, on this screen, read before anything\nGATE BLOCK\n  proves done   the suite passes\n  pass          exit 0\n\nTASK    tidy the public spec\nRECORD  %s/\nMODE    autonomous: STOP 2 is a report, no hold\nBRANCH  chore/atl-50   the chore branch\n\nCHAIN  (in order, each a Skill call, none skipped)\n  %s\n  2  ready   shared/records/gate-run.sh, then STOP 2 "ready for push" report to lead-1   no hold\n\n' "$1" "${3:-1  build   recording-evidence on every run   no hold}"
    printf '%s\n' "${2:-$CT}"; printf '\n## 1. Read first\n  none\n'; } > "$1/handoff.md"; }
cz(){ (cd "${2:-$L}" && "$SH/records/freeze-rules.sh" --chore "$1/handoff.md" 2>&1; echo "rc=$?"); }
RC="$T/records/atlas/atl-50-c1"; ho "$RC"
printf '# ATL-50 chore · decision record · test-ic\ngoal: the public spec reads clean\nrules: -\nplan: -\n' > "$RC/decision-record.md"; touch -t 203101010000 "$RC/decision-record.md"
check "chore-1: lead-1's chore freeze writes rules.md, gate.md and frozen.sha256" "$(cz "$RC" | tail -1):$(ls "$RC" | grep -c -x -e rules.md -e gate.md -e frozen.sha256)" "rc=0:3"
RY="$T/records/atlas/atl-50-c3"; ho "$RY"
check "owner-ok: the chore freeze reads no session log: written with a log root that does not exist" "$( (cd "$L" && python3 "$T/fzh.py" "$SH/records" "$T/no-such-logs" "$L" --chore "$RY/handoff.md" >/dev/null 2>&1; echo "rc=$?")):$(ls "$RY" | grep -c -x -e rules.md -e gate.md -e frozen.sha256)" "rc=0:3"
rm -rf "$RY"
check "chore-1: rules.md is the standing block only, under a chore header" "$(grep -q '\[standing\]' "$RC/rules.md" && echo standing):$(grep -c -e '^TERMS' -e '^DECIDED' -e '^REJECTED' "$RC/rules.md"):$(head -1 "$RC/rules.md" | grep -c '^rules · ATL-50 chore · frozen at handoff.md · ')" "standing:0:1"
check "chore-1: gate.md holds the handoff's command and pass line, no on main line" "$(grep -c -e '^  proves done   echo "3 passed"$' -e '^  pass          exit 0, "3 passed"$' "$RC/gate.md"):$(grep -c 'on main' "$RC/gate.md")" "2:0"
check "chore-1: frozen.sha256 has a chore line and both hashes, no spec line; verify passes" "$(grep -c -e '^chore     handoff.md$' -e '^sha256    [0-9a-f]\{64\}  rules.md$' -e '^sha256    [0-9a-f]\{64\}  gate.md$' "$RC/frozen.sha256"):$(grep -c -e '^spec' -e '^approved' "$RC/frozen.sha256"):$(python3 "$FR" verify "$RC"; echo "rc=$?")" "3:0:rc=0"
check "chore-1: the record header's rules line names the chore freeze" "$(grep -c '^rules: chore  (rules.md, the standing block; gate.md from handoff.md, frozen 20' "$RC/decision-record.md")" 1
check "chore-1: the chain back to the handoff holds" "$(python3 "$FR" check "$RC" --repo "$I" --worktree "$I"; echo "rc=$?")" rc=0
RB="$T/records/atlas/atl-50-c2"; ho "$RB"
check "chore-1: --dump prints the gate from any folder and writes nothing" "$( (cd "$I" && "$SH/records/freeze-rules.sh" --chore "$RB/handoff.md" --dump 2>&1) | grep -c '^  proves done   echo "3 passed"$'):$(ls "$RB" | grep -c rules.md)" "1:0"
rm -rf "$RB"; mkdir -p "$RB"; awk -v r="RECORD  $RB/" '/^# ATL-50 · /{f=1; print; print r; next} f' "$HERE/../skills/writing-a-rung-handoff/templates/handoff.md" > "$RB/handoff.md"
check "chore-1: the handoff template's chore variant reads as a chore's handoff and freezes" "$( (cd "$I" && "$SH/records/freeze-rules.sh" --chore "$RB/handoff.md" --dump 2>&1; echo "rc=$?") | grep -c -e '^  proves done   make docs-lint$' -e '^rc=0$')" 2
# the chore runs as a rung does after the freeze: dr-check, gate-run, push, draft PR, STOP 2
printf '\nATL-50 DR1 · task 1 · 2026-10-14 11:00 · test-ic\n  plan        1 "tidy the spec"\n  question    which section first?\n  decided     the Terms table first\n  instead of  -\n  because     x\n  undo        git revert abc\n  evidence    -\n  review      -\n' >> "$RC/decision-record.md"
check "chore-3: dr-check on a chore's entry checks it against the standing block, jev line and receipt written" "$(dr "$I" "$RC/decision-record.md" "$T/stub-ok.json" >/dev/null; grep -c '^  jev         continue' "$RC/decision-record.md"):$(ls "$RC"/receipts/*-jev-DR1*.json | wc -l | tr -d ' ')" "1:1"
touch -t 203101010000 "$RC/decision-record.md"
git -C "$I" checkout -q -b chore/atl-50
check "chore-2: gate-run runs a chore's frozen gate, green" "$(cd "$I" && "$HERE/../records/gate-run.sh" "$RC" >/dev/null 2>&1; echo "rc=$?"):$(grep -c '^verdict  green' "$RC"/receipts/*-gate.md)" "rc=0:1"
OT="$(git -C "$I" rev-parse refs/remotes/origin/trunk)"; git -C "$I" update-ref refs/remotes/origin/trunk HEAD   # nothing to send: the leak gate reads no diff
check "chore-2: push-gate allows the chore's branch at its green receipt" "$(pg 'git push -u origin chore/atl-50')" allow
check "chore-2: push-gate allows its draft PR" "$(pg 'gh pr create --draft --title "ATL-50 spec cleanup" --body "Tidy the spec."')" allow
check "chore-2: the STOP 2 ready for push report on a chore allowed" "$(send "$I" "$(printf '"atlas · ATL-50 chore · STOP 2 · ready for push\\n  files record %s/"' "$RC")")" allow
check "chore-2: an IC write to a chore's gate.md denied" "$(fg "$RC/gate.md")" "FROZEN:"
# no bypass: --chore never writes over a rung, a STOP 1, or a freeze
rm -rf "$RB"; ho "$RB"; cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RF/stop1.log" "$RB/"; FH="$(hx "$RB/frozen.sha256")"
check "chore-4: --chore on a spec-frozen record refused, nothing changed" "$(cz "$RB" | grep -c -e 'has a spec line: this record froze from a design spec' -e '^rc=2$'):$(hx "$RB/frozen.sha256" | grep -c "$FH")" "2:1"
rm -rf "$RB"; ho "$RB"; cp "$RF/stop1.log" "$RB/"
check "chore-4: --chore on a record with a stop1.log refused, nothing written" "$(cz "$RB" | grep -c 'stop1.log exists: a STOP 1 was logged'):$(ls "$RB" | grep -c -e rules.md -e gate.md -e frozen.sha256)" "1:0"
check "chore-4: --chore run again on the frozen chore refused" "$(cz "$RC" | grep -c 'rules.md exists; this record is frozen')" 1
rm -rf "$RB"; ho "$RB" "$CT" '1  design spec   writing-a-design-spec   -> STOP 1, hold'
check "chore-4: --chore on a rung's handoff (a CHAIN with the spec step) refused, nothing written" "$(cz "$RB" | grep -c 'CHAIN line [0-9]* .* names `writing-a-design-spec`: a chore has no design spec'):$(ls "$RB" | grep -c rules.md)" "1:0"
rm -rf "$RB"; ho "$RB"
check "chore-5: --chore from the IC's worktree refused, nothing written" "$(cz "$RB" "$I" | grep -c "is test-ic's worktree: the chore freeze is lead-1's act"):$(ls "$RB" | grep -c rules.md)" "1:0"
check "chore-5: an IC Bash freeze-rules.sh --chore denied by the FROZEN WRITE GATE" "$(pg "$HERE/../records/freeze-rules.sh --chore $RB/handoff.md" | grep -c '^FROZEN WRITE GATE: this command runs the chore freeze')" 1
check "chore-5: an IC python3 freeze_rules.py --dump --chore denied too" "$(pg "cd /tmp; python3 $HERE/../records/freeze_rules.py --dump --chore $RB/handoff.md" | grep -c '^FROZEN WRITE GATE: this command runs the chore freeze')" 1
check "chore-5: lead-1's Bash freeze-rules.sh --chore not gated" "$(pg "$HERE/../records/freeze-rules.sh --chore $RB/handoff.md" "$L")" allow
check "chore-6: the spec freeze on a chore's record (no frozen files yet) refused, nothing written" "$(NOLOG=1 fz docs/atl-42-spec.md "$RB" --approved "$(ap atl-42-spec.md)" | grep -c "is a chore's record"):$(ls "$RB" | grep -c rules.md)" "1:0"
rm -rf "$RB"; mkdir -p "$RB"; cp "$RC/frozen.sha256" "$RB/"
check "chore-6: the spec freeze on a record whose frozen.sha256 has a chore line refused" "$(NOLOG=1 fz docs/atl-42-spec.md "$RB" --approved "$(ap atl-42-spec.md)" | grep -c "is a chore's record")" 1
rm -rf "$RB"; cp -R "$RC" "$RB"; perl -pi -e "s|^RECORD .*|RECORD  $RB/|" "$RB/handoff.md"; cp "$RF/stop1.log" "$RB/"
check "chore-7: a chore's record holding a stop1.log fails verify" "$(python3 "$FR" verify "$RB" | grep -c "is a chore's record and holds stop1.log"; echo "rc=${PIPESTATUS[0]}")" "1
rc=2"
rm "$RB/stop1.log"; printf 'spec      docs/atl-42-spec.md\napproved  %s\n' "$(ap atl-42-spec.md)" >> "$RB/frozen.sha256"
check "chore-7: a spec line added beside the chore line fails verify" "$(python3 "$FR" verify "$RB" | grep -c 'has a spec line and a chore line')" 1
perl -ni -e 'print unless /^chore /' "$RB/frozen.sha256"
check "chore-7: the chore line swapped for a spec line fails verify, the handoff's Checks still there" "$(python3 "$FR" verify "$RB" | grep -c 'has a spec line, and handoff.md has a `## Checks` table')" 1
check "chore-8: STOP 1 on a chore's record denied, no stop1.log written" "$(send "$I" "$(printf '"atlas · ATL-50 chore · STOP 1 · 10:00 · holding on lead-1\\n  spec       docs/atl-42-spec.md @ %s\\n  files record %s/"' "$(git -C "$I" rev-parse --short HEAD)" "$RC")" | grep -c "STOP 1 GATE: .* is a chore's record"):$([ -e "$RC/stop1.log" ] && echo logged || echo none)" "1:none"
cp "$RC/gate.md" "$T/cgate.keep"; printf '  # one more line\n' >> "$RC/gate.md"
check "chore-9: gate-run refuses a chore's gate.md changed after the freeze" "$(cd "$I" && "$HERE/../records/gate-run.sh" "$RC" 2>&1 | grep -c 'gate.md does not match frozen.sha256')" 1
cp "$T/cgate.keep" "$RC/gate.md"
cp "$RC/handoff.md" "$T/chand.keep"; perl -pi -e 's/\| exit 0, "3 passed" \| exit 0, "3 passed" \|/| exit 0 | exit 0, "3 passed" |/' "$RC/handoff.md"
check "chore-10: a handoff Checks pass line weakened after the freeze: the chain names it" "$(python3 "$FR" check "$RC" --repo "$I" | grep -c "gate.md as frozen is not the handoff's \`## Checks\`")" 1
check "chore-10: the same change denies the push" "$(pg 'git push origin chore/atl-50' | grep -c 'FROZEN GATE: gate.md as frozen is not the handoff')" 1
cp "$T/chand.keep" "$RC/handoff.md"; perl -pi -e 's/^  2  ready /  2  ready   STOP 1, hold; then /' "$RC/handoff.md"
check "chore-10: a STOP 1 added to the chore's CHAIN after the freeze: the chain names it" "$(python3 "$FR" check "$RC" --repo "$I" | grep -c 'no longer reads as it froze: CHAIN line .* names `STOP 1`')" 1
cp "$T/chand.keep" "$RC/handoff.md"
# the handoff's Checks are read as strictly as a spec's
cr(){ rm -rf "$RB"; ho "$RB" "$1"; cz "$RB"; }
check "chore-11: a pass line with words and no quoted string refused" "$(cr "$(printf '## Checks\n\n| command | pass | on main |\n|---|---|---|\n| `make test` | exit 0, 3 passed | exit 0, "3 passed" |')" | grep -c 'pass line `exit 0, 3 passed`: words with no "quoted string"')" 1
check "chore-11: a placeholder on main cell refused" "$(cr "$(printf '## Checks\n\n| command | pass | on main |\n|---|---|---|\n| `make test` | exit 0 | TODO |')" | grep -c 'on main is `TODO`, a placeholder')" 1
check "chore-11: a handoff with no ## Checks refused" "$(cr '## Notes' | grep -c 'no `## Checks` table')" 1
check "chore-11: a Checks heading with more words refused" "$(cr "$(printf '## Checks run on main\n\n| command | pass | on main |\n|---|---|---|\n| `make test` | exit 0 | exit 0 |')" | grep -c 'is not read as `## Checks`')" 1
check "chore-11: a fence under ## Checks refused" "$(cr "$(printf '## Checks\n\n```\n  proves done   make test\n  pass          exit 0\n  on main       exit 0\n```')" | grep -c 'one table (command, pass, on main), not a fence')" 1
check "chore-11: nothing written on a refusal" "$(ls "$RB" | grep -c -e rules.md -e gate.md -e frozen.sha256)" 0
rm -rf "$RB"; ho "$RB"; perl -pi -e "s|^RECORD .*|RECORD  $RC/|" "$RB/handoff.md"
check "chore-11: a RECORD line naming another folder refused" "$(cz "$RB" | grep -c "RECORD line names $RC/, not $RB")" 1
rm -rf "$RB"
# a chore's gate.md is amended only through amend-frozen.sh, lead-1's act
cp "$RC/gate.md" "$RC/gate-pre-2026-10-14-1200.md"
python3 - "$RC/gate.md" <<'EOF'
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace("GATE BLOCK", "# Amended 2026-10-14 12:00 by lead-1 (C3): line 1, kind a, ATL-50 C1\nGATE BLOCK", 1))
EOF
check "chore-12: amend-frozen on a chore refused from the IC's worktree" "$( (cd "$I" && "$SH/amend-frozen.sh" "$RC" gate 'line 1 kind a' 2>&1) | grep -c "is test-ic's worktree")" 1
check "chore-12: lead-1's amendment of a chore's gate.md re-hashes it; verify and the chain pass" "$( (cd "$L" && "$SH/amend-frozen.sh" "$RC" gate 'line 1 kind a' >/dev/null 2>&1); echo "rc=$?"):$(python3 "$FR" check "$RC" --repo "$I"; echo "rc=$?")" "rc=0:rc=0"
# a rung is unaffected
RN="$T/records/atlas/atl-42-r30"; mkdir -p "$RN"; cp "$RF/rules.md" "$RF/gate.md" "$RN/"; grep -v -e '^spec' -e '^approved' "$RF/frozen.sha256" > "$RN/frozen.sha256"
check "chore-13: a rung's frozen.sha256 with no spec and no chore line still fails verify" "$(python3 "$FR" verify "$RN" | grep -c 'has no spec line')" 1
check "chore-13: a rung's record is not read as a chore's" "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.chore_record(sys.argv[2]), f.chore_record(sys.argv[3]))' "$HERE/../records" "$RF" "$RC")" "False True"
rm -rf "$RN"
# an IC never turns its own rung into a chore: its hooks stamp ic-sessions.log in its open, unfrozen record, and the
# chore freeze refuses a record that has one, whoever runs it and from wherever (verify F1: a quoted --chore, a
# variable, python -c, a cd to lead-1's folder all got past the FROZEN WRITE GATE and the cwd check)
RA="$T/records/atlas/atl-60-r1"; ho "$RA" '## Notes' '1  design spec   writing-a-design-spec   -> STOP 1, hold'
printf '# ATL-60 r1 · decision record · test-ic\ngoal: x\nrules: -\nplan: -\n' > "$RA/decision-record.md"
check "chore-14: an IC Bash command stamps ic-sessions.log in its open, unfrozen rung" "$(pg 'ls' >/dev/null; grep -c ' · Bash · test-ic · session chore$' "$RA/ic-sessions.log")" 1
check "chore-14: a second command in the same session adds no line" "$(pg 'ls' >/dev/null; wc -l < "$RA/ic-sessions.log" | tr -d ' ')" 1
check "chore-14: a frozen record (the chore frozen before launch) is not stamped" "$([ -e "$RC/ic-sessions.log" ] && echo stamped || echo none)" none
check "chore-14: an IC Write to its record's handoff.md denied" "$(fg "$RA/handoff.md")" HANDOFF
check "chore-14: an IC Write to ic-sessions.log denied" "$(fg "$RA/ic-sessions.log")" HANDOFF
check "chore-14: an IC perl -0pi edit of its handoff.md denied" "$(pg "perl -0pi -e 's/a/b/' $RA/handoff.md" | grep -c '^FROZEN WRITE GATE: this command names a frozen file.*handoff.md')" 1
check "chore-14: an IC rm of ic-sessions.log denied" "$(pg "rm $RA/ic-sessions.log" | grep -c '^FROZEN WRITE GATE: this command names a frozen file')" 1
n=0; while IFS= read -r c; do case "$(pg "$c")" in "FROZEN WRITE GATE: this command runs the chore freeze"*) n=$((n+1));; *) printf 'not denied: %s\n' "$c";; esac; done <<EOF
cd $L && $SH/records/freeze-rules.sh "--chore" $RA/handoff.md
cd $L && $SH/records/freeze-rules.sh '--chore' $RA/handoff.md
cd $L && $SH/records/freeze-rules.sh \--chore $RA/handoff.md
C=--chore; cd $L && $SH/records/freeze-rules.sh \$C $RA/handoff.md
cd $L && python3 -c "import sys; sys.path.insert(0, '$SH/records'); import freeze_rules as f; f.main(['f', '--chore', '$RA/handoff.md'])"
python3 -c "import os, sys; os.chdir('$L'); sys.path.insert(0, '$SH/records'); import freeze_rules as f; f.chore_freeze('$RA/handoff.md', False)"
bash -c "cd $L && $SH/records/freeze-rules.sh \"--chore\" $RA/handoff.md"
EOF
check "chore-14: seven disguised IC runs of the chore freeze denied (quoted, escaped, a variable, python -c main, python -c chdir, bash -c)" "$n" 7
ho "$RA"   # the handoff edited into a chore's by a write no hook saw
check "chore-14: a form push-gate misses (C=--cho D=re, \$C\$D) is allowed by the hook" "$(pg "C=--cho; D=re; cd $L && $SH/records/freeze-rules.sh \$C\$D $RA/handoff.md")" allow
check "chore-14: that freeze, run from lead-1's folder, refused on ic-sessions.log; nothing written" "$( (cd "$L" && C=--cho; D=re; "$SH/records/freeze-rules.sh" $C$D "$RA/handoff.md" 2>&1; echo "rc=$?") | grep -c -e 'ic-sessions.log exists (.* · Bash · test-ic · session chore): an IC has worked on this record' -e '^rc=2$'):$(ls "$RA" | grep -c -e rules.md -e gate.md -e frozen.sha256):$(grep -c '^rules: -$' "$RA/decision-record.md")" "2:0:1"
check "chore-14: the python -c chore_freeze form refused the same way" "$(python3 -c 'import os, sys; os.chdir(sys.argv[2]); sys.path.insert(0, sys.argv[1]); import freeze_rules as f
try: f.chore_freeze(sys.argv[3], False)
except f.Refused as e: print("\n".join(e.reasons))' "$SH/records" "$L" "$RA/handoff.md" | grep -c 'ic-sessions.log exists'):$(ls "$RA" | grep -c rules.md)" "1:0"
RE="$T/records/atlas/atl-51-c1"; ho "$RE"
check "chore-14: push-gate leaves a chore's unfrozen record unstamped; lead-1's freeze of it passes" "$(pg 'ls' >/dev/null; [ -e "$RE/ic-sessions.log" ] && echo stamped || echo none):$(cz "$RE" | tail -1)" "none:rc=0"
RD="$T/records/atlas/atl-52-c1"; ho "$RD"
check "chore-14: an IC session started on an unfrozen chore stamps it, and lead-1's late freeze is refused" "$(boot "$I" >/dev/null; grep -c ' · session startup · test-ic · session chore$' "$RD/ic-sessions.log"):$(cz "$RD" | grep -c 'ic-sessions.log exists')" "1:1"
check "chore-14: the IC's own record folders are the only ones stamped" "$(python3 "$SH/frozen.py" stamp "$T/records" other-ic s9 x | wc -l | tr -d ' ')" 0
rm -rf "$RA" "$RD" "$RE"
# the stamp never writes into a record folder git tracks in the records repo: a closed record stays as it was committed
# (a session start appended to the ic-sessions.log of a record already committed, with no close.md in it)
G="$T/grecords"; mkdir -p "$G/atlas/atl-70-r1" "$G/atlas/atl-71-r1"
for d in atl-70-r1 atl-71-r1; do printf '# ATL-70 r1 · decision record · test-ic\ngoal: x\nrules: -\nplan: -\n' > "$G/atlas/$d/decision-record.md"; done
printf '2026-01-05 10:00 · Bash · test-ic · session s0\n' > "$G/atlas/atl-70-r1/ic-sessions.log"
git -C "$G" init -q; git -C "$G" add atlas/atl-70-r1; git -C "$G" -c user.name=t -c user.email=t@t commit -qm 'ATL-70 r1 close'
check "stamp-1: a session start leaves a record folder committed in the records repo unchanged" "$(export FLEET_RECORDS="$G"; printf '{"cwd":"%s","session_id":"s-git","source":"startup"}' "$I" | "$HERE/skill-boot.sh" >/dev/null 2>&1; git -C "$G" status --short -- atlas/atl-70-r1 | wc -l | tr -d ' ')" 0
check "stamp-1: an uncommitted record folder in the same repo still gets its line" "$(grep -c ' · session startup · test-ic · session s-git$' "$G/atlas/atl-71-r1/ic-sessions.log" 2>/dev/null)" 1
check "stamp-1: an IC Bash command leaves the committed folder unchanged too" "$(export FLEET_RECORDS="$G"; pg 'ls' >/dev/null; git -C "$G" status --short -- atlas/atl-70-r1 | wc -l | tr -d ' ')" 0
check "stamp-1: frozen.py stamp names only the uncommitted folder" "$(python3 "$SH/frozen.py" stamp "$G" test-ic s-git2 x | sed "s|^$G/||")" atlas/atl-71-r1
rm -rf "$G"
# the whole handoff is read for a spec step or STOP 1, not the CHAIN up to its first blank or tab line (verify F2)
ho "$RB" "$CT" "$(printf '0  read    the brief\n\n  1  design spec   writing-a-design-spec   -> STOP 1, hold')"
check "chore-15: a spec step after a blank line in the CHAIN refused, nothing written" "$(cz "$RB" | grep -c 'CHAIN line [0-9]* `1  design spec .*` names `writing-a-design-spec`'):$(ls "$RB" | grep -c rules.md)" "1:0"
rm -rf "$RB"; ho "$RB" "$CT" "$(printf '1  build   x\n\t2  design spec   writing-a-design-spec -> STOP 1')"
check "chore-15: a tab-indented spec step refused, --dump too" "$( (cd "$I" && "$SH/records/freeze-rules.sh" --chore "$RB/handoff.md" --dump 2>&1; echo "rc=$?") | grep -c -e 'names `writing-a-design-spec`' -e '^rc=2$')" 2
rm -rf "$RB"; ho "$RB"; perl -pi -e 's/^MODE .*/MODE    autonomous: STOP 1 holds; STOP 2 is a report/' "$RB/handoff.md"
check "chore-15: a MODE line saying STOP 1 holds refused" "$(cz "$RB" | grep -c '^freeze-rules --chore: line [0-9]* `MODE .*` names `STOP 1`')" 1
rm -rf "$RB"; ho "$RB"; printf '\n## 6. Report shape\n  stop  1 is the spec screen\n' >> "$RB/handoff.md"
check "chore-15: a report shape naming stop 1 in another case and spacing refused" "$(cz "$RB" | grep -c 'line [0-9]* `stop  1 is the spec screen` names `stop  1`')" 1
cp "$RC/handoff.md" "$T/chand.keep"; printf '\n## 6. Report shape\nSTOP 1 is the spec screen one; hold.\n' >> "$RC/handoff.md"
check "chore-15: a STOP 1 added below the CHAIN after the freeze: the chain names it" "$(python3 "$FR" check "$RC" --repo "$I" | grep -c 'no longer reads as it froze: line [0-9]* `STOP 1 is the spec screen one; hold.` names `STOP 1`')" 1
check "chore-15: the same change denies the push" "$(pg 'git push origin chore/atl-50' | grep -c 'FROZEN GATE: .*no longer reads as it froze')" 1
cp "$T/chand.keep" "$RC/handoff.md"
# a chore's handoff built from the template's rung keeps no rung line that says STOP 1 holds (verify F3)
rm -rf "$RB"; python3 - "$HERE/../skills/writing-a-rung-handoff/templates/handoff.md" "$RB" <<'EOF'
import os, re, sys
src, rec = sys.argv[1:3]
t = open(src, encoding="utf-8").read()
rung, chore = t.split("# Chore variant", 1)
rung = rung[rung.index("# ATL-42 · "):]
chain, checks = chore[chore.index("CHAIN "):chore.index("## Checks")], chore[chore.index("## Checks"):]
out = rung[:rung.index("CHAIN ")] + chain + checks.rstrip("\n") + "\n\n" + rung[rung.index("## 1. Read first"):]
os.makedirs(rec, exist_ok=True)
open(os.path.join(rec, "handoff.md"), "w", encoding="utf-8").write(re.sub(r"^RECORD .*$", f"RECORD  {rec}/", out, flags=re.M))
EOF
check "chore-16: the rung template with only the CHAIN and Checks changed refused on its MODE, OPEN and report shape lines" "$( (cd "$I" && "$SH/records/freeze-rules.sh" --chore "$RB/handoff.md" --dump 2>&1) | grep -c -e 'line [0-9]* `MODE ' -e 'line [0-9]* `OPEN ' -e 'line [0-9]* `STOP 1 is the spec')" 3
rm -rf "$RB"
# only an exact `## Checks` heading makes a record a chore's; a rung's `### Checks lead-1 ran` does not (verify F4)
RN="$T/records/atlas/atl-42-r40"
for h in '### Checks lead-1 ran before launch' '## Checks and balances' '#### checks'; do
  rm -rf "$RN"; ho "$RN" "$h" '1  design spec   writing-a-design-spec   -> STOP 1, hold'; cp "$RF/rules.md" "$RF/gate.md" "$RF/frozen.sha256" "$RF/stop1.log" "$RN/"
  check "chore-17: a spec-frozen rung whose handoff has \`$h\` passes verify and is not a chore's" "$(python3 "$FR" verify "$RN"; echo "rc=$?"):$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f; print(f.chore_record(sys.argv[2]))' "$HERE/../records" "$RN")" "rc=0:False"
done
rm -rf "$RN"
git -C "$I" update-ref refs/remotes/origin/trunk "$OT"
# freeze_rules: LEAD_CWD and LIVE_RECORDS never follow the process env; they follow the user-level settings' env.FLEET_HOME
FRH="$T/fr-env-home"; mkdir -p "$FRH"; printf '{"env":{"FLEET_HOME":"%s/named"}}' "$T" > "$T/fr-settings.json"
check "freeze_rules: LEAD_CWD does not follow FLEET_HOME in the process env" "$(FLEET_HOME="$FRH" python3 -I -c '
import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f
print(f.LEAD_CWD.startswith(sys.argv[2]), f.LIVE_RECORDS.startswith(sys.argv[2]))' "$HERE/../records" "$FRH")" "False False"
check "freeze_rules: settings_fleet_home reads the settings file's env.FLEET_HOME (patched constant), else <home>/.fleet-agent-mgmt" "$(python3 -I -c '
import sys; sys.path.insert(0, sys.argv[1]); import freeze_rules as f
f.USER_SETTINGS = sys.argv[2]; a = f.settings_fleet_home()
f.USER_SETTINGS = sys.argv[3]; b = f.settings_fleet_home()
print(a == sys.argv[4] + "/named", b == f.USER_HOME + "/.fleet-agent-mgmt")' "$HERE/../records" "$T/fr-settings.json" "$T/none.json" "$T")" "True True"
rm -rf "$T/records"
printf 'skill hooks: %d pass, %d fail\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
