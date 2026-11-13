#!/bin/bash
# PreToolUse hook, matcher "Bash". IC only. The IC pushes its own feature
# branch and opens a draft pull request without the owner's word, but only on
# a green gate receipt at HEAD and a clean jev audit; this hook checks that at
# the push itself, so the rule does not rest on the IC's reading of it.
# Acts on `git push` (also `git -C <dir> push`), `gh pr create`, `gh pr ready`
# and `gh pr merge` (also with gh's -R/--repo flag, and a merge or ready
# through `gh api`), in any segment of a compound command, wherever git or gh
# stands in the segment (after `timeout`, `if ... then`, `!`, `xargs`), inside
# `bash|sh|zsh -c` (any short-flag cluster with c), `eval`, `$(...)`, `<(...)`
# and backticks. Denied when:
#   git push       no record folder for this IC (a decision-record.md whose
#                  header ends "· <name>"); the newest receipts/*-gate.md is
#                  not at the worktree's HEAD or has a red line the owner has
#                  not overridden (owner_override.py: "<lane> r<n> override
#                  <checks>: <reason>" typed by a person in this IC's pane, and
#                  an `owner` line in decision-record.md quoting it); the jev audit
#                  (dr_check.py --audit) exits non-zero; the newest DR or UAT entry's
#                  jev line says "stop and ask" or "rework"; the target branch is
#                  main, master or the remote's default branch; the target is
#                  not the BRANCH line of <record>/handoff.md (when it has one);
#                  origin/<target> holds a commit by an author other than the
#                  worktree's user.email; the pushed source is not HEAD (the
#                  commit the receipt covers); or the push uses --force, -f,
#                  --force-with-lease, a +refspec, a glob refspec, --delete,
#                  --prune, --mirror, --all or --tags.
#                  FROZEN GATE: rules.md or gate.md differs from <record>/frozen.sha256;
#                  the receipt names no gate.md sha256 or another one; the spec
#                  named in frozen.sha256 is gone from HEAD, would not freeze, or
#                  has a row rules.md or gate.md does not; for a chore's record (a
#                  chore line, no spec), gate.md as frozen is not the handoff's
#                  `## Checks` (a record folder in shared/records/legacy-records.txt is not
#                  checked).
#   gh pr create   the same receipt, audit, jev verdict and frozen checks; the head branch is main,
#                  master, the default or not the handoff's BRANCH; no --draft.
#   either act     LEAK GATE: the added lines of git diff <merge-base with
#                  origin's default branch, else origin/main or origin/master>..HEAD
#                  in the act's dir, or the message of a commit in that range that
#                  no remote holds yet, name a fleet path or name (a home path,
#                  .fleet-agent-mgmt, .claude/checks, lead-1, a roster IC name;
#                  leak_check.py --diff and --text). Each specs/, plans/, adr/ or
#                  analysis/ *.md the range adds or changes is also read whole at HEAD
#                  (leak_check.py --doc: the full doc list, and the render check for a
#                  spec). It catches a doc written through Bash, not the Write tool.
#                  No base on origin: not checked.
#   gh pr create   LEAK GATE also on the --title/-t, --body/-b and --body-file/-F
#                  text (a body file is read from the act's dir; `-` is not read).
#   gh pr merge    always: the owner merges.
#   gh pr ready    the newest DR entry has no `owner` line quoting the word.
# message-gate.sh (c) and (d) run the same receipt and audit checks on the
# "ready for push" report; this hook repeats them at the act.
# Solo and lead: exit 0.
set -u
. "$(dirname "$0")/skill-lib.sh"
[ "$ROLE" = "ic" ] || exit 0
cmd="$(j '.tool_input.command')"; [ -n "$cmd" ] || exit 0
RECORDS="${FLEET_RECORDS:-$FLEET_HOME/records}"
tp="$(j '.transcript_path')"; LOGS="${tp:+$(dirname "$tp")}"   # this session's log folder: the owner's override is read there
# RECORD WRITE GATE, any IC command: decision-record.md and evidence.md take an entry only through
# shared/records/record-add.sh, which appends at the end, numbers it and runs the Jev check (the Edit tool is
# guarded by artefact-gate.sh). shared/records/record_add.py --bash first takes out the body of each quoted
# heredoc that record-add.sh itself reads (the entry is data: a DR whose undo reads `git push --delete
# ...` is not a push); a heredoc that feeds bash, python or anything else stays, and an unquoted one
# sent to record-add.sh is denied (the shell runs $(...) in it). Then it denies a command naming either
# file or a receipts/*-jev-*.json, in any case and any folder, with a write form (a > or >> into it,
# tee, cp, mv, rm, ln, truncate, dd, install, rsync, chmod, patch, an editor, sed -i with -i among any
# of its flags, awk -i inplace, or a python, perl, ruby or node run other than dr_check.py), and a
# record-add.sh run before its skill was invoked this session (dr and uat: recording-a-decision; e:
# recording-evidence), as the Write tool's SKILL GATE would. Best effort: a write the command line
# hides is not seen; the audit after each write and at the push reads what landed in decision-record.md.
flat="${cmd//[\"\'\\]/}"
shopt -s nocasematch
case "$flat" in
  *record-add*|*decision-record*|*evidence*|*-jev-*)
    shopt -u nocasematch
    rw="$(printf '%s' "$cmd" | python3 "$(dirname "$0")/../records/record_add.py" --bash "$RECORDS" 2>/dev/null)" || rw=""
    if [ -n "$rw" ]; then
      rv="${rw%%$'\n'*}"; [ "$rw" = "$rv" ] && cmd="" || cmd="${rw#*$'\n'}"
      case "$rv" in
        write) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"RECORD WRITE GATE: this command names decision-record.md, evidence.md or a receipts/*-jev-*.json with a write form (a > or >> into it, tee, cp, mv, rm, ln, patch, an editor, sed -i, awk -i inplace, or a python, perl, ruby or node run other than dr_check.py). An entry is added only with shared/records/record-add.sh <record folder> dr|uat|e <<'"'"'EOF'"'"' ... EOF, run from the worktree: it appends at the end, numbers the entry and, for a DR or UAT, runs the Jev check and the audit. A receipt is written only by the check. Read the files with cat, grep or tail."}}'; exit 0 ;;
        unquoted) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"RECORD WRITE GATE: record-add.sh reads its entry from a heredoc whose delimiter is not quoted, so the shell runs any $(...) or backtick in the body before the entry is written. Quote it: shared/records/record-add.sh <record folder> dr|uat|e <<'"'"'EOF'"'"' ... EOF."}}'; exit 0 ;;
        "add "*)
          for k in ${rv#add }; do
            need=recording-a-decision; [ "$k" = e ] && need=recording-evidence
            if ! has "$need"; then
              jq -n --arg r "SKILL GATE: record-add.sh $k writes the record with the $need skill, $(why "$need"). Invoke it now with the Skill tool ($SKILLS_ROOT/$need/SKILL.md), follow its steps, then run record-add.sh again." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0
            fi
          done ;;
      esac
    fi ;;
esac
shopt -u nocasematch
# FROZEN WRITE GATE, any IC command: the frozen files are the freeze's, the amendment is lead-1's, and
# stop1.log is this hook set's. Denied: a command naming amend-frozen, `frozen.py ... amend|stop1-log` or
# frozen.amend / frozen.stop1_log / frozen.write_frozen; and a command that names frozen.sha256,
# stop1.log or a *-pre-*.md copy (or rules.md or gate.md beside a record folder path) with a write
# form (a > or >> into it, tee, cp, mv, rm, ln, truncate, dd, install, rsync, chmod, sed -i,
# perl -i, or python, perl, ruby or node; shared/frozen.py bash-write). The same for the record's
# handoff.md (lead-1's) and ic-sessions.log (these hooks'). The same for Claude Code's session logs
# (~/.claude/projects/, or .claude and projects/ apart as after a cd; a redirect into a .claude path or a
# .jsonl, any redirect after a cd there): the freeze reads the owner's "spec ok" there, so an IC never
# writes them. Also denied: the chore freeze (freeze-rules
# with --chore anywhere in the command once quotes and backslashes are taken out, or chore_freeze),
# lead-1's act at a chore's launch. Before that, bash-write --name stamps
# ic-sessions.log in each open, unfrozen record folder of this IC's that is not a chore's: the chore
# freeze refuses a folder holding it, so an IC's run of the freeze this hook does not see (a variable,
# python -c, a cd to lead-1's folder) is refused by the freeze itself. Best effort: the hashes and the
# chain to the approved STOP 1 commit, or to a chore's handoff (shared/frozen.py), catch what a
# command line hides.
fw="$(printf '%s' "$cmd" | python3 "$(dirname "$0")/../frozen.py" bash-write "$RECORDS" --name "$NAME" --session "$SID" 2>/dev/null)"
case "$fw" in
  chore) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"FROZEN WRITE GATE: this command runs the chore freeze (freeze-rules --chore). A chore'"'"'s rules.md, gate.md and frozen.sha256 are written by lead-1 from the handoff before launch, never by the IC. A check that must change is a card to lead-1 (decision-card.md)."}}'; exit 0 ;;
  act) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"FROZEN WRITE GATE: this command runs an amendment or writes stop1.log (amend-frozen, frozen.py amend or stop1-log). An amendment is lead-1'"'"'s act after a card to the owner, and stop1.log is written by the message gate when STOP 1 passes. Raise a card to lead-1 (decision-card.md)."}}'; exit 0 ;;
  logs) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"FROZEN WRITE GATE: this command names Claude Code'"'"'s session logs (~/.claude/projects/) with a write form (a redirect into them, tee, cp, mv, rm, ln, sed -i, or a python, perl, ruby or node run). The freeze reads the owner'"'"'s spec ok there; an IC never writes, copies or moves them. If the freeze cannot find the owner'"'"'s word, hold and ask the owner to type it in this pane or lead-1'"'"'s."}}'; exit 0 ;;
  write) jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"FROZEN WRITE GATE: this command names a frozen file (rules.md, gate.md, frozen.sha256, stop1.log or a *-pre-*.md copy in a record folder), the record'"'"'s handoff.md or ic-sessions.log with a write form (a redirect into it, tee, cp, mv, rm, ln, sed -i, or a python, perl, ruby or node run). The IC never writes them: the handoff is lead-1'"'"'s, ic-sessions.log is the hooks'"'"'. Read them with cat or grep. A rule or gate line that must change is a card to lead-1 (decision-card.md)."}}'; exit 0 ;;
esac
printf '%s' "$cmd" | grep -Eq 'push|gh' || exit 0
GATE_RUN="$FLEET_REPO/shared/records/gate-run.sh"
here="${cwd:-$PWD}"

# The acts in the command, one per line: kind <tab> dir <tab> flags <tab> branches <tab> sources <tab> PR text
# ("-" when empty; the PR text is base64 of a JSON {label: text}).
parse(){ python3 - "$cmd" "$here" <<'PY'
import base64, json, os, re, shlex, sys
cmd, cwd = sys.argv[1], sys.argv[2]
PUNCT = "();<>|&\n`"
WRAP = {"rtk", "command", "env", "time", "nohup", "sudo", "exec"}
BAD = {"--force": "--force", "--force-with-lease": "--force-with-lease", "--delete": "--delete",
       "--mirror": "--mirror", "--all": "--all", "--branches": "--branches", "--tags": "--tags",
       "--prune": "--prune"}
RUNS = {"git", "gh", "bash", "sh", "zsh", "eval"}   # a token that starts an act, wherever it stands in the segment
VALUED = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}

def tokens(s):
    try:
        lx = shlex.shlex(s, posix=True, punctuation_chars=PUNCT)
        lx.whitespace, lx.whitespace_split = " \t\r", True
        return list(lx)
    except ValueError:   # unbalanced quotes: split on separators, never fail open on a plain push
        return [t for t in re.split(r"(\n|;|&&|\|\||\|)|\s+", s) if t]

def where(d, p):
    return os.path.normpath(os.path.join(d, os.path.expanduser(p)))

def walk(toks, d, out):
    seg, i = [], 0
    while i < len(toks):
        t = toks[i]
        if t and set(t) <= set(PUNCT):
            if ("<" in t or ">" in t) and "(" not in t:   # a redirection: drop "2" in "2>&1", skip the target
                if seg and seg[-1].isdigit():
                    seg.pop()
                i += 2
                continue
            if seg:
                d = one(seg, d, out)
            seg = []
        else:
            seg.append(t)
        i += 1
    if seg:
        one(seg, d, out)

def one(seg, d, out):
    i = 0
    while i < len(seg):
        w = seg[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w) or os.path.basename(w) in WRAP or (w == "proxy" and i and seg[i-1] == "rtk"):
            i += 1
            continue
        break
    if i >= len(seg):
        return d
    if os.path.basename(seg[i]) == "cd":
        a = seg[i+1:]
        return where(d, a[0]) if a else os.path.expanduser("~")
    i = next((k for k in range(i, len(seg)) if os.path.basename(seg[k]) in RUNS), None)
    if i is None:
        return d
    w, a = os.path.basename(seg[i]), seg[i+1:]
    if w in ("bash", "sh", "zsh"):
        c = next((k for k, x in enumerate(a) if re.match(r"^-[A-Za-z]*c[A-Za-z]*$", x)), None)
        if c is not None and c + 1 < len(a):
            walk(tokens(a[c + 1]), d, out)
    elif w == "eval":
        walk(tokens(" ".join(a)), d, out)
    elif w == "git":
        git(a, d, out)
    elif w == "gh":
        gh(a, d, out)
    return d

def gh(a, d, out):
    b, k = [], 0                                  # gh's words, without -R/--repo and its value
    while k < len(a):
        if a[k] in ("-R", "--repo"):
            k += 2; continue
        if a[k].startswith("--repo="):
            k += 1; continue
        b.append(a[k]); k += 1
    if b and b[0] == "api":
        j = " ".join(a)
        if re.search(r"pulls/\d+/merge|mergePullRequest", j):
            out.append(("merge", d, "-", "-", "-", "-"))
        elif re.search(r"markPullRequestReadyForReview", j):
            out.append(("ready", d, "-", "-", "-", "-"))
    elif len(b) > 1 and b[0] == "pr" and b[1] in ("create", "ready", "merge"):
        rest = b[2:]
        draft = any(x in ("--draft", "-d") for x in rest)
        head, text = "-", {}
        for k, x in enumerate(rest):
            nxt = rest[k+1] if k + 1 < len(rest) else None
            if x in ("--head", "-H") and nxt is not None:
                head = nxt
            elif x.startswith("--head="):
                head = x.split("=", 1)[1]
            elif x in ("--title", "-t") and nxt is not None:
                text["PR title"] = nxt
            elif x.startswith("--title="):
                text["PR title"] = x.split("=", 1)[1]
            elif x in ("--body", "-b") and nxt is not None:
                text["PR body"] = nxt
            elif x.startswith("--body="):
                text["PR body"] = x.split("=", 1)[1]
            elif x in ("--body-file", "-F") or x.startswith("--body-file="):
                f = x.split("=", 1)[1] if "=" in x else nxt
                if f and f != "-":
                    try:
                        text["PR body file " + f] = open(where(d, f), encoding="utf-8", errors="replace").read()
                    except OSError:
                        pass
        head = head.split(":", 1)[-1] or "-"
        blob = base64.b64encode(json.dumps(text).encode()).decode() if b[1] == "create" and text else "-"
        out.append((b[1], d, "draft" if draft else "-", head, "-", blob))

def git(a, d, out):
    j = 0
    while j < len(a) and a[j].startswith("-"):
        if a[j] == "-C" and j + 1 < len(a):
            d = where(d, a[j+1]); j += 2
        elif a[j] in ("-c", "--git-dir", "--work-tree", "--namespace"):
            j += 2
        else:
            j += 1
    if j >= len(a) or a[j] != "push":
        return
    args, bad, pos, k = a[j+1:], [], [], 0
    while k < len(args):
        x = args[k]
        if x == "--":
            pos += args[k+1:]
            break
        if x.startswith("--"):
            name = x.split("=", 1)[0]
            if name in BAD:
                bad.append(BAD[name])
            if name in VALUED and "=" not in x:
                k += 1
        elif x.startswith("-") and len(x) > 1:
            if x == "-o":
                k += 1
            else:
                bad += ["-" + c for c in x[1:] if c in "fd"]
        else:
            pos.append(x)
        k += 1
    targets, sources = [], []
    for r in pos[1:]:
        if r.startswith("+"):
            bad.append("+refspec " + r)
            r = r[1:]
        if r.startswith(":"):
            bad.append("delete refspec " + r)
        if "*" in r:
            bad.append("glob refspec " + r)
            continue
        src = r.split(":", 1)[0] or "HEAD"
        dst = r.split(":", 1)[1] if ":" in r else r
        dst = re.sub(r"^(refs/)?heads/", "", dst)
        targets.append("@" if dst in ("", "HEAD", "@") else dst)
        sources.append(src)
    out.append(("push", d, ",".join(bad) or "-", " ".join(targets or ["@"]), " ".join(sources or ["HEAD"]), "-"))

out = []
for m in re.findall(r"[$<>]\(([^()]*)\)|`([^`]*)`", cmd):   # command substitutions, quoted or not
    walk(tokens(m[0] or m[1]), cwd, out)
walk(tokens(cmd), cwd, out)
for row in dict.fromkeys(out):
    print("\t".join(row))
PY
}
acts="$(parse)" || acts="unread"
[ -n "$acts" ] || exit 0

reason=""
add(){ reason="${reason:+$reason }$1"; }
recs="$(grep -ls "· $NAME\$" "$RECORDS"/*/*/decision-record.md 2>/dev/null)"
mine="$([ -n "$recs" ] && printf '%s\n' "$recs" | tr '\n' '\0' | xargs -0 ls -t 2>/dev/null | head -1)"
rec="${mine:+$(dirname "$mine")}"
own="$( [ -n "$rec" ] && sed -n 's/^BRANCH  *\([^ ]*\).*/\1/p' "$rec/handoff.md" 2>/dev/null | head -1)"
no_record="RECORD GATE: no record folder for $NAME under $RECORDS (no decision-record.md whose header ends \"· $NAME\"). A fleet IC always has one: ask lead-1 which rung this is. Nothing is pushed and no pull request is opened without it."

# (c) and (d) at the act: the newest gate receipt is at HEAD with 0 red lines; the jev audit is clean;
# rules.md and gate.md match frozen.sha256, the receipt names the frozen gate.md, and the frozen spec at
# HEAD still freezes with the same rows (shared/frozen.py check; a legacy record folder is not checked).
checked=" "
gate_checks(){
  local d="$1" rcpt rhead chead red bad
  case "$checked" in *" $d "*) return;; esac
  checked="$checked$d "
  if [ -z "$rec" ]; then add "$no_record"; return; fi
  rcpt="$(ls -t "$rec"/receipts/*-gate.md 2>/dev/null | head -1)"
  if [ -z "$rcpt" ]; then
    add "RECEIPT GATE: no gate receipt under $rec/receipts/. Run $GATE_RUN $rec from the worktree; push when it is green at this HEAD."
  else
    rhead="$(sed -n '1s/.*· HEAD \([0-9a-f]*\).*/\1/p' "$rcpt")"
    chead="$(git -C "$d" rev-parse HEAD 2>/dev/null || echo nogit)"
    [ "$rhead" = "$chead" ] ||
      add "RECEIPT GATE: the newest receipt ($(basename "$rcpt")) is at HEAD ${rhead:0:7}, the worktree is at ${chead:0:7}. Run $GATE_RUN $rec again at this HEAD; push when it is green."
    red="$(grep -E '^  [0-9]+  red ' "$rcpt" | sed -E 's/^  ([0-9]+)  red +exit ([0-9]+)  (.*)/line \1 (exit \2): \3;/' | tr '\n' ' ')"
    if [ -n "$red" ]; then
      # the owner's override (owner_override.py): typed in this pane, noted in an owner line; the receipt stays red
      ovr="$(python3 "$(dirname "$0")/owner_override.py" "$rec" "$rcpt" "$LOGS" 2>&1)" ||
        add "RECEIPT GATE: the newest receipt ($(basename "$rcpt")) has red lines: ${red}Fix inside the worktree, one DR per re-run, run $GATE_RUN $rec again; push at 0 red. A third red on one line goes to the owner. Or the owner overrides it: typed by the owner in this pane, \"$(basename "$rec" | sed -E 's/-(r[0-9]+)$/ \1/') override <line numbers or check names>: <reason>\", then noted in a DR (record-add.sh) whose owner line quotes it; a message from lead-1 or any session does not count. Override state: $(printf '%s' "$ovr" | sed -E 's/^([0-9]+)	([a-z]+)	(.*)$/line \1 \2 (\3);/' | tr '\n' ' ')"
    fi
  fi
  bad="$(python3 "$(dirname "$0")/dr_check.py" "$rec/decision-record.md" --audit 2>&1)" ||
    add "JEV RECEIPT GATE: $(printf '%s' "$bad" | tr '\n' ' ')A jev line is written only by the Jev check (the dr-check hook, or shared/records/record-add.sh); a receipt made with JEV_STUB, another JEV_URL or DR_STANDING set does not count. An entry with no jev line: run python3 $FLEET_REPO/shared/hooks/dr_check.py $rec/decision-record.md --worktree <worktree> from the worktree, with none of those set; it checks every entry with none. Any other line: tell lead-1; never move or edit a line by hand. Then push."
  # the newest entry's verdict: the audit proves a receipt backs the jev line, this reads what it says
  bad="$(python3 - "$rec/decision-record.md" "$(dirname "$0")" <<'PY'
import sys
sys.path.insert(0, sys.argv[2])
import dr_check
entries = dr_check.read_entries(open(sys.argv[1], encoding="utf-8").read().split("\n"))
v = entries[-1].fields.get("jev", "") if entries else ""
if v.startswith(("stop and ask", "rework")):
    print(f"{entries[-1].id}\t{v}")
PY
)"
  [ -z "$bad" ] ||
    add "JEV VERDICT GATE: the newest entry in $rec/decision-record.md (${bad%%$'\t'*}) has jev \"${bad#*$'\t'}\". A stop and ask is the owner's word first: ask in the pane, write the next entry with an \`owner\` line quoting the word, push once its jev line says continue. A rework is do not act: write the next entry with a different \`decided\`."
  bad="$(python3 "$(dirname "$0")/../frozen.py" check "$rec" ${rcpt:+--receipt "$rcpt"} --worktree "$d" 2>/dev/null)" ||
    add "FROZEN GATE: $(printf '%s' "$bad" | sed 's/$/;/' | tr '\n' ' ')Nothing is pushed and no pull request is opened while a frozen file or the spec has moved. A frozen rule or gate line changes only through a card to lead-1; a drifted spec is restored to the frozen rows, committed, gated again."
}
# The commits this act sends: no fleet path or name in an added line, or in the
# message of a commit no remote holds yet (one already pushed cannot be reworded
# without a force push). Once per dir.
leaked=" "
leak_report(){  # $1 hits, $2 what holds them
  local n
  [ -n "$1" ] || return 0
  n="$(printf '%s\n' "$1" | wc -l | tr -d ' ')"
  add "LEAK GATE: $2 name the fleet, and the team reads them on GitHub. $n hits (where:line: pattern: text): $(printf '%s\n' "$1" | head -20 | sed 's/$/;/' | tr '\n' ' ')$( [ "$n" -gt 20 ] && printf 'and %s more. ' "$((n-20))")Rewrite each (cite the Jira ticket or a repo file, or drop the line). A file line: commit the fix. A commit message: reword it before the push (git commit --amend, or a rebase of commits no remote holds). Run the gate again at the new HEAD, then retry."
}
leak_gate(){
  local d="$1" ref mb hits c tk top
  case "$leaked" in *" $d "*) return;; esac
  leaked="$leaked$d "
  # The fleet-token list applies only to this repo's own clone, never to a product repo.
  # Compared by the git common dir, so a worktree of the clone counts as the clone.
  top="$(git -C "$d" rev-parse --git-common-dir 2>/dev/null)"; tk=""
  case "$top" in ""|/*) ;; *) top="$d/$top" ;; esac
  [ -n "$top" ] && top="$(cd -P "$top" 2>/dev/null && pwd)" && [ "$top" = "$(cd -P "$FLEET_REPO/.git" 2>/dev/null && pwd)" ] && tk="--tokens"
  for ref in refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/master ""; do
    [ -z "$ref" ] && return 0
    mb="$(git -C "$d" merge-base "$ref" HEAD 2>/dev/null)" && [ -n "$mb" ] && break
  done
  hits="$(git -C "$d" diff --no-color --no-ext-diff -U0 "$mb..HEAD" 2>/dev/null | python3 "$(dirname "$0")/leak_check.py" $tk --diff 2>/dev/null)"
  for c in $(git -C "$d" rev-list "$mb..HEAD" --not --remotes 2>/dev/null); do
    hits="$hits
$(git -C "$d" log -1 --format=%B "$c" 2>/dev/null | python3 "$(dirname "$0")/leak_check.py" $tk --text "commit ${c:0:7} message" 2>/dev/null)"
  done
  # a committed doc (specs, plans, adr, analysis *.md) is read whole at HEAD with the full doc list and,
  # for a spec, the render check: --diff reads added lines with paths and names only
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    hits="$hits
$(git -C "$d" show "HEAD:$f" 2>/dev/null | python3 "$(dirname "$0")/leak_check.py" $tk --doc - --path "$f" 2>/dev/null)"
  done < <(git -C "$d" diff --name-only --diff-filter=AMR "$mb..HEAD" 2>/dev/null | grep -E '(^|/)(specs|plans|adr|analysis)/.*\.md$')
  hits="$(printf '%s\n' "$hits" | sed '/^$/d')"
  leak_report "$hits" "the commits this act sends (${mb:0:7}..HEAD) add lines or carry messages that"
}
pr_text_gate(){  # $1 base64 of a JSON {label: text}: the pull request's title and body
  local hits
  [ "$1" = "-" ] && return 0
  hits="$(python3 -c '
import base64, json, sys
sys.path.insert(0, sys.argv[2])
import leak_check
for label, text in json.loads(base64.b64decode(sys.argv[1])).items():
    for n, pat, line in leak_check.check_text(text):
        print("%s:%d: %s: %s" % (label, n, pat, line))
' "$1" "$(dirname "$0")" 2>/dev/null)"
  leak_report "$hits" "the pull request's title or body, read on GitHub too,"
}
protected(){  # $1 branch, $2 dir: main, master or the remote's default branch
  local def
  case "$1" in main|master) return 0;; esac
  def="$(git -C "$2" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null)"; def="${def#*/}"
  [ -n "$def" ] && [ "$1" = "$def" ]
}
branch_gate(){  # $1 branch, $2 what
  add "BRANCH GATE: $2 targets $1, which is main, master or the repo's default branch. The IC pushes only the rung's own feature branch, named in the handoff; a push to main or the default branch, and a pull request from it, are the owner's word: stop and ask in the pane."
}
current(){ git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null; }
target_gate(){  # $1 branch, $2 dir, $3 what: never main or the default; only the handoff's BRANCH; no other author on origin/<branch>
  local t="$1" d="$2" what="$3" base me others
  if protected "$t" "$d"; then branch_gate "$t" "$what"; return; fi
  if [ -n "$own" ] && [ "$t" != "$own" ]; then
    add "BRANCH GATE: $what targets $t, which is not the rung's branch $own (the BRANCH line of $rec/handoff.md). The IC pushes only that branch and opens its draft PR from it; any other push is the owner's word: stop and ask in the pane."
    return
  fi
  git -C "$d" rev-parse -q --verify "refs/remotes/origin/$t" >/dev/null 2>&1 || return 0
  for base in refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/master ""; do
    [ -z "$base" ] && return 0
    git -C "$d" rev-parse -q --verify "$base" >/dev/null 2>&1 && break
  done
  me="$(git -C "$d" config user.email 2>/dev/null)"
  others="$(git -C "$d" log "refs/remotes/origin/$t" --not "$base" --format=%ae 2>/dev/null | grep -vxF -- "${me:-}" | sort -u | tr '\n' ' ')"
  [ -z "$others" ] ||
    add "BRANCH GATE: origin/$t holds commits by ${others}(this worktree commits as ${me:-no user.email}). A branch another person pushed to is the owner's word: stop and ask in the pane."
}

while IFS=$'\t' read -r kind d flags branches sources prtext; do
  [ -n "$kind" ] || continue
  case "$kind" in
    unread)
      add "PUSH GATE: the command names a push or a pull request act and could not be read. Run the push or the gh pr command on its own line, plainly, then retry."
      ;;
    push)
      gate_checks "$d"
      leak_gate "$d"
      [ "$flags" = "-" ] ||
        add "PUSH FLAG GATE: this push uses ${flags//,/, }. The IC pushes plainly: never --force, -f, --force-with-lease, a +refspec, a glob refspec, --delete, --prune, --mirror, --all or --tags. A push that rewrites or removes what is on the remote is the owner's word: stop and ask in the pane."
      set -f
      for b in $branches; do
        if [ "$b" = "@" ]; then
          cur="$(current "$d")"
          if [ -z "$cur" ]; then
            add "BRANCH GATE: HEAD is detached in $d, so the push target cannot be read. Check out the rung's feature branch and push it by name."
            continue
          fi
          up="$(git -C "$d" rev-parse --abbrev-ref --symbolic-full-name '@{push}' 2>/dev/null)"; up="${up#*/}"
          target_gate "$cur" "$d" "this push"
          [ -n "$up" ] && [ "$up" != "$cur" ] && target_gate "$up" "$d" "this push"
        else
          target_gate "$b" "$d" "this push"
        fi
      done
      hsha="$(git -C "$d" rev-parse -q --verify HEAD 2>/dev/null)"
      for src in ${sources:-HEAD}; do
        ssha="$(git -C "$d" rev-parse -q --verify "$src^{commit}" 2>/dev/null)"
        [ -n "$ssha" ] && [ "$ssha" = "$hsha" ] ||
          add "SOURCE GATE: this push sends $src (${ssha:0:7}), not HEAD (${hsha:0:7}), the commit the gate receipt covers. Push HEAD of the rung's branch, by name while it is checked out."
      done
      set +f
      ;;
    create)
      gate_checks "$d"
      leak_gate "$d"
      pr_text_gate "${prtext:--}"
      [ "$flags" = "draft" ] ||
        add "DRAFT GATE: gh pr create without --draft. The IC opens its pull request as a draft (gh pr create --draft), body from the spec summary; marking it ready for review is the owner's word."
      h="$branches"; [ "$h" = "-" ] && h="$(current "$d")"
      [ -n "$h" ] && target_gate "$h" "$d" "this pull request"
      ;;
    merge)
      add "MERGE GATE: gh pr merge is the owner's act; the IC never merges. Report the pull request to lead-1 and stop."
      ;;
    ready)
      if [ -z "$rec" ]; then add "$no_record"; continue; fi
      last="$(awk '/^[^ ].* DR[0-9]+ ·/{id=$0; inE=1; has=0; next} inE && /^  owner +"/{has=1} inE && !/^  /{inE=0} END{if (id!="") print has "\t" id}' "$rec/decision-record.md")"
      [ -n "$last" ] || last="0"$'\t'"no DR entry yet"
      [ "${last%%$'\t'*}" = "1" ] ||
        add "READY GATE: the newest DR entry in $rec/decision-record.md (${last#*$'\t'}) has no \`owner\` line quoting the owner's word. Marking a pull request ready for review is the owner's word: ask in the pane, write a DR whose \`owner\` line quotes the word, then run gh pr ready."
      ;;
  esac
done <<< "$acts"
[ -n "$reason" ] || exit 0
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
