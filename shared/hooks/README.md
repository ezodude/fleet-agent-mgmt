# Compaction hooks

Two user-level Claude Code hooks keep every session on this machine resumable
across a context compaction. State is written to disk before it can be lost
and read back first after the compaction. No human in the loop.

```
  turn ends ──▶ Stop hook: state-gate.sh
                  ├─ STATE newer than HEAD ──▶ turn ends
                  └─ STATE older / missing ──▶ exit 2 "update STATE" ──▶ one more turn ──▶ ends
                                                                          (bounces once)
  compaction ──▶ SessionStart(compact) hook: postcompact-boot.sh
                  └─ prints a ~600-token brief into the new context:
                       STATE block · git line · ONE in-flight prompt · FIRST ACTION
```

## Where STATE lives

```
  lead-1     Leads/lead-1/LEDGER.md, a fenced ```state block at the top
  an IC      ~/.fleet-agent-mgmt/checks/<roster name>/STATE.md      (outside the repo), a fenced ```state block, then "## log"
  solo       none: no gate, the brief carries git + the prompt only
```

The role comes from `$FLEET_HOME/roster.md`: the fenced `fleet` block maps a
directory to a name. The lead-1 row is the lead, any other row is an IC,
no row is solo. The 15 keys are in `STATE-schema.md`.

## Files

```
  postcompact-boot.sh   SessionStart hook, matcher "compact". Always exits 0.
  state-gate.sh         Stop hook. bash + git + jq. Exit 2 blocks the turn end.
  prompt-mark.sh        UserPromptSubmit hook, installed per role in shared/launch/ic-settings.json, never at user level.
                        IC only: touches checks/<name>/.last-prompt. Always exits 0, prints nothing.
  STATE-schema.md       the 15 keys, with a real example
  settings-hooks.json   the block installed in ~/.claude/settings.json
  test-settings.json    60k window + both hooks, for a live proof on one session
  test-hooks.sh         the e2e test below
```

## What the gate checks, exactly

```
  lead-1   ✓ HEAD itself touched LEDGER.md          pass (the state rode in that commit)
           ✓ LEDGER.md mtime ≥ HEAD commit time     pass
           ✗ HEAD newer than LEDGER.md              bounce
           ✗ no ```state block                      bounce
  an IC    ✓ STATE.md mtime ≥ HEAD commit time      pass
           ✗ STATE.md missing or older              bounce
           ✗ .last-prompt newer than STATE.md       bounce (a prompt in the pane since the last write)
  any      stop_hook_active = true                  pass (already the bounce turn)
```

The roster row is matched by the cwd, then by the cwd's git top level, so a
sub-folder of an IC's worktree is gated as the IC. The gate sees commits and,
for an IC, prompts. A STOP, a send, a push or an armed notice in a turn with
neither is a rule in the rung handoff, not a bounce. lead-1 writes an IC's
STATE.md only through `shared/ledger/state-set.sh`, which keeps the file's mtime.

## What the brief skips

Compaction summaries, skill bodies, interrupt notices, idle notices, slash
commands such as `/compact`, and the gate's own "Stop hook feedback" rows. A
peer's message arrives wrapped by the harness; the brief keeps the body and
tags it with the sender's name.

## Test

```
  shared/tests/test-hooks.sh          expect: hooks e2e: N pass, 0 fail
  shared/fleet/fleet-audit.sh               runs it too, as one OK/FAIL row "hooks: ..."
  shared/tests/test-state-set.sh            expect: N pass, 0 fail (state-set.sh on a temp STATE.md)
  shared/tests/test-state-regression.sh     expect: N pass, 0 fail (the live STATE.md files, copied to a temp dir, under this tree's gate)
  shared/tests/test-precedents.sh           expect: N pass, 0 fail (precedents-gather.sh and precedents-check.sh on invented close reports in a temp dir)
```

Each suite tests the scripts beside it, so a run from a worktree tests the
worktree. `HOOKS_LIVE` in test-hooks.sh is only the installed path the
settings checks expect; leave it unset. The regression suite compares the
gate with the one at 282b949, the last commit before the prompt marker,
vendored as `shared/tests/fixtures/state-gate.282b949.sh`.

Runs in a throwaway fixture: a lead repo, an IC repo, a solo dir, a synthetic
transcript. Covers the gate matrix above, the brief's skip list, the
cross-session unwrap, and the installed settings. It proves the scripts on
fixtures. It does not prove a live compaction fires the hook; for that, run
one session with `claude --settings shared/tests/test-settings.json` and
read the brief under `~/.claude/handoffs/auto/`.

## Proved live

2026-09-09, a fresh dbx-docs-ic with the 60k window: both bounces fired once
and were obeyed, the brief carried STATE.md byte-identical, the IC continued
with no human. 2026-09-10, lead-1 after a manual `/compact`: the brief
carried the ledger's state block byte-identical.

# Skill hooks ("ICs really need to enforce the skill calls", the owner's words)

Installed per role, never at user level: ICs get them from `ic-settings.json`
on the launch line; lead-1 from `lead-settings.json` the same way (a
`.claude/settings.json` at the repo root is not read by a session whose cwd is
`Leads/lead-1`; proved 2026-09-15). Every
script resolves the role from the roster and exits 0 for a solo session.

```
  SessionStart startup|resume|clear|compact ──▶ skill-boot.sh  clears this session's markers, prints SKILLS IN FORCE;
                                                         IC: a line in ic-sessions.log of each open, unfrozen record of its own
  PostToolUse  Skill|Agent           ──▶ skill-mark.sh     marker per skill invoked; agent-haiku for a haiku Agent
  PreToolUse   Write|Edit|MultiEdit  ──▶ artefact-gate.sh  deny the write until the path's skill has a marker;
                                                         IC: deny a committed doc that names the fleet (leak_check.py);
                                                         IC: deny an Edit or Write to a record file that is not an append
                                                         lead: deny a rung brief until precedents.json beside it passes precedents-check.sh <record dir>
  PostToolUse  Write|Edit|MultiEdit (IC only) ──▶ dr-check.sh  the Jev check on a new DR or UAT entry, then the jev
                                                         audit on decision-record.md, shown to the IC
  Stop                               ──▶ stop-skill-gate.sh bounce once if the message's header has no marker
  PreToolUse   SendMessage (IC only) ──▶ message-gate.sh   deny a STOP message with no marker or over 30 lines
  PreToolUse   Bash (IC only)        ──▶ push-gate.sh      deny a push or a pull request act the IC may not take alone,
                                                         or one whose commits add a fleet path or name (leak_check.py)
                                                         a red receipt line passes only on the owner's override
                                                         typed in the IC's pane and quoted in a DR (owner_override.py)

  markers   ~/.fleet-agent-mgmt/checks/<name>/skills/<session id>/<skill>
  stale     a marker older than any file under shared/skills/<skill>/ or shared/skills/foundations/
            counts as absent: the gate bounces once with "changed since this session read it" and
            the boot line lists it on resume. A skill edit reaches every running session at its
            next gated write or message, no relaunch.
  .bounces  the stop gate's count for the turn, in the marker dir. The gate bounces at most twice
            per turn; a cold turn resets it and compaction wipes it with the markers, so a bounce
            followed by an auto-compaction in one turn still gets gated.

  ROLE   PATH, HEADER OR COMMAND             SKILL OR CHECK REQUIRED
  ic     */analysis/*.md                     writing-an-analysis
  ic     */adr/*.md                          writing-an-adr
  ic     */specs/*.md                        writing-a-design-spec
  ic     */{specs,plans,adr,analysis}/*.md   the text the write leaves has no leak-list pattern (below);
                                             a spec has no text straight above a --- and no open fence
  ic     */specs/*.md                        SPEC SHAPE: the text the write leaves freezes as written
                                             (freeze_rules.py --check -); the rung's frozen spec (the spec
                                             line of <record>/frozen.sha256) also matches rules.md and gate.md
  ic     records/*/*/{rules.md,gate.md,      FROZEN: denied. The freeze writes them; lead-1 amends with
           frozen.sha256,*-pre-*.md}         shared/amend-frozen.sh (a rules.md change or an added
                                             Checks line also needs the owner's typed amend ok)
  ic     ~/.claude/projects/**/*.jsonl       SESSION LOGS: denied (Write, Edit, MultiEdit; the path resolved
                                             first). The freeze reads the owner's spec ok there; memory/ stays writable
  ic     records/*/*/{decision-record.md,   APPEND ONLY: an Edit or MultiEdit whose old_string is the end of
           evidence.md}                      the file (one match, only blank lines after it) and whose
                                             new_string starts with it; a Write only to create the file,
                                             header first. The added text starts on a new line, at the left
                                             edge, with the header of the next entry (next number, the
                                             file's lane), and carries no `jev` line and no `review` line
                                             but `-`. Anything else is denied, naming record-add.sh. The
                                             path is resolved and the name read in any case (/./, //, a
                                             link to the folder, DECISION-RECORD.md are the same file)
  ic     records/*/*/receipts/*-jev-*.json   RECEIPTS: denied. Only the Jev check writes a receipt
  ic     records/*/*/decision-record.md      after every write (dr-check.sh, same path rules): the Jev
                                             check, then dr_check.py --audit, its result in the hook's context
  ic     Bash naming decision-record.md,     RECORD WRITE GATE: a write form on a command naming the file,
           evidence.md or a -jev-*.json      anywhere and in any case: a > >> >| <> or &> into it, tee, cp,
                                             mv, rm, ln, truncate, dd, install, rsync, chmod, patch, ed, ex,
                                             vi, vim, nvim, emacs, osascript, swift, sed with -i, awk -i
                                             inplace, python, perl, ruby or node; reads pass. record-add.sh
                                             with an unquoted heredoc delimiter is denied
  ic     Bash running record-add.sh dr|uat   recording-a-decision (SKILL GATE; a --dump run passes, each
                                             other call in the command is checked)
  ic     Bash running record-add.sh e        recording-evidence (SKILL GATE, as above)
  ic     message with "· STOP n ·"           reporting-a-rung; a SendMessage over 30 lines is denied before it sends
  ic     message with "· STOP 1 ·"           STOP 1 GATE: a `spec <repo path> @ <sha>` line; the spec at <sha>
                                             freezes; no placeholder `on main` cell; evidence.md has one entry
                                             per Checks command, `where <cwd> · origin/main · HEAD <sha>`;
                                             denied on a chore's record (a chore has no STOP 1). Passed and
                                             sent to lead-1 (`to` "lead-1", or the socket of the process in
                                             lead-1's folder): a line in <record>/stop1.log. Sent to anyone
                                             else: allowed, no line, and the IC is told so
  ic     a later STOP                        FROZEN GATE: rules.md and gate.md match frozen.sha256; the
                                             receipt names the frozen gate.md's sha256; a chore's gate.md
                                             as frozen is its handoff's `## Checks`
  ic     "ready for push"                    DRIFT: the frozen spec at HEAD freezes and its rows match
                                             rules.md and gate.md (frozen.py check --worktree)
  ic     */*-close.md                        closing-a-rung
  ic     message opening "close · "         closing-a-rung
  ic     git push, gh pr create              a record folder; the newest gate receipt at HEAD, 0 red; the jev
                                             audit clean; not main, master or the default branch; the BRANCH
                                             line of <record>/handoff.md, when it has one; no commit on
                                             origin/<branch> by an author other than the worktree's
                                             user.email; the pushed source is HEAD; a plain push (no
                                             --force, -f, --force-with-lease, +refspec, glob refspec,
                                             --delete, --prune, --mirror, --all, --tags); gh pr create
                                             with --draft. Read wherever git or gh stands in a segment,
                                             and inside sh -c, eval, $(...), <(...) and backticks;
                                             LEAK GATE: no fleet path or name in the added lines of
                                             merge-base(origin's default, else origin/main)..HEAD, in
                                             the messages of commits no remote holds yet, or in
                                             gh pr create --title, --body and --body-file;
                                             FROZEN GATE: the frozen files, the receipt's gate hash and
                                             the spec at HEAD, as at "ready for push"
  ic     gh pr ready                         the newest DR entry has an `owner` line quoting the word
  ic     Bash naming a frozen file or act    FROZEN WRITE GATE: denied: amend-frozen, frozen.py amend or
                                             stop1-log, the chore freeze (freeze-rules with --chore once
                                             quotes are out, or chore_freeze), and a write form naming
                                             rules.md, gate.md, frozen.sha256, stop1.log, a *-pre-*.md
                                             copy, the record's handoff.md or ic-sessions.log (frozen.py
                                             bash-write); a write form naming the session logs under
                                             ~/.claude/projects/ (a redirect into a .claude path or a
                                             .jsonl, any redirect after a cd there, cp, mv, tee, sed -i,
                                             python and the rest). First, a line in ic-sessions.log of
                                             each open, unfrozen record of its own that is not a chore's
  ic     records/*/handoff.md, ic-sessions.log   HANDOFF: denied (Write, Edit, MultiEdit)
  ic     gh pr merge, gh api merge           denied: the owner merges
  lead   records/*/handoff.md                writing-a-rung-handoff
  lead   records/*/brief.md                  brief-grilling
  lead   records/*/*/precedents.json         sweeping-precedents
  lead   records/<project>/<record>/brief.md PRECEDENTS: the first write (no brief.md there yet) denied
                                             until precedents.json beside it is there and
                                             shared/records/precedents-check.sh <record dir> exits 0; the
                                             deny carries the check's first fault lines. A brief already
                                             there is edited as before. The name read in any case, the
                                             path with /./, // and /../ folded
  lead   Leads/lead-1/handoffs/*-session-handoff.md  drafting-handoff
  lead   Leads/lead-1/{briefs,tickets,handoffs}/*    denied: moved to the record folder
  lead   message with "check ·"              reporting-a-rung + agent-haiku
  lead   message opening "held n since"      holding-rollups
```

The frozen checks live in `shared/frozen.py` (verify, check, stop1, amend) and
read `<record>/frozen.sha256`, which the freeze writes beside rules.md and
gate.md. gate-run.sh and dr-check.sh verify it too. A record folder listed in
`shared/records/legacy-records.txt` was frozen before the file existed and skips every
frozen check. A chore (no spec, no STOP 1) is frozen by lead-1 before launch
with `shared/records/freeze-rules.sh --chore <record>/handoff.md`: rules.md is the
standing block only, gate.md the handoff's `## Checks`, and frozen.sha256 has a
`chore` line in place of the spec and approved lines; its chain leads back to
the handoff, not to a STOP 1 commit. The freeze refuses a handoff with a line
anywhere that names the spec step or STOP 1, and a record holding
ic-sessions.log: an IC's hooks write a line there when its session starts on an
open, unfrozen record of its own and at each Bash command on one that is not a
chore's (never in a folder with a file committed in the records repo), so an IC that runs the freeze in a form the FROZEN WRITE GATE does not
see (a variable, python -c, a cd to lead-1's folder) is still refused. The
spec freeze also needs the owner's word: "<lane> r<n> spec ok" or "<lane> spec
ok", typed by a person after the newest stop1.log line, in lead-1's pane or the
IC's. freeze_rules.py reads it from Claude Code's session logs
(~/.claude/projects/<cwd with / and . turned into ->/*.jsonl, lead-1's folder
and the IC's worktree only), at a fixed path no environment variable or flag can
move; an entry relayed by another session (origin kind peer) does not count, and
no log folder or no entry typed by a person is a refusal. amend-frozen.sh reads a second
word the same way: a rules.md amendment, and a gate.md amendment that adds a proves done
line, are refused unless the owner typed "<lane> r<n> amend ok <card id>" (ATL-42 r1
amend ok ATL-42 D4) in lead-1's pane or the IC's after the record's newest history line
(else its freeze time), and the card id is in the amend-frozen.sh reason. A relay does
not count. A gate.md amendment that only changes existing lines (a pass line under a
`kind a` `# Amended` line, a command under `kind b`) needs no word; an added line needs
it whatever its label says. The limit: artefact-gate.sh sees Write, Edit and MultiEdit, not
a write through Bash. A frozen file changed that way is caught by its hash at
the next gate run, decision-record entry, STOP or push, not at the write.

Decision record and evidence entries are written by `shared/records/record-add.sh
<record folder> dr|uat|e` (logic and the APPEND ONLY guard in
`shared/records/record_add.py`): it numbers the entry, stamps the time, appends it at
the end of the file and, for dr and uat, runs the Jev check and the audit and
prints the id, the `jev` line and the audit's result. It exists because an Edit
that anchored DR3 on UAT1's `undo` line put DR3 above UAT1's `jev` line: the
check re-checked UAT1, never checked DR3, and the audit failed at the push.
The push gate strips the body of a quoted heredoc that record-add.sh itself
reads before it reads a command, so an entry's `undo git push --delete ...` is
not read as a push. A heredoc that feeds bash or anything else stays in the
command, whatever names record-add.sh on the line. An unquoted delimiter is
denied: the shell would run a `$(...)` in the body.

The audit (`dr_check.py --audit`, after every write, at "ready for push" and
at the push) fails when an entry has no `jev` line, when an id is written
twice, or when a `jev` line has no receipt with its verdict that the hook would
have made the same way. A receipt records JEV_STUB, the endpoint (JEV_URL) and
DR_STANDING; one made with a stub, another endpoint or another DR_STANDING
does not count. record-add.sh and dr_check.py run in the IC's shell, which can
set those; the audit runs in the hook's environment, which it cannot.
JEV_STUB_OK=1 makes stubbed receipts count, in the tests only.

The limits: the RECORD WRITE GATE reads the command line. A glob on the file
name itself, a script file, a variable holding the name or `git apply
--directory` is not seen; the audit after the next write and at the push
catches a `jev` line that moved or an entry never checked. A `cp` that names
the record file only as its source, a python read of a receipt and a pipe into
python are denied too. Creating a link to the record folder from Bash is
allowed; an Edit through it is guarded. Receipts written before the stub field
existed count as made by the hook. lead-1 is not gated: it writes `review`
lines mid-file by design.

A committed doc is public: the team reads it on GitHub. `leak_check.py` holds
the leak list in one place and both hooks read it, so the rule does not rest
on the IC reading it.

```
  leak_check.py --doc <file|-> [--path <p>]   every pattern, plus the render faults for */specs/*.md
  leak_check.py --diff                        a unified diff on stdin: added lines, paths and names only
  leak_check.py --text <label>                any text on stdin (a commit message, a PR title or body):
                                              paths and names only
                                              exit 0 clean, 1 with "file:line: pattern: text" hits

  paths and names   a home path  .fleet-agent-mgmt  .claude/checks  lead-1  every roster name
                    (the fleet block of $FLEET_HOME/roster.md, FLEET_ROSTER overrides)
  doc only          ~/  STOP n  screen one  spec ok  ^Reply:  ^style:  ^source:  ^record:
                    DR<n>  UAT<n>  E<n>  "the IC"  decision-record  evidence.md  handoff.md
  spec render       a non-blank line straight above a line that is exactly ---; an odd
                    number of ``` fence lines (front matter at line 1 is skipped)
  not checked       a path under ~/.claude, ~/.fleet-agent-mgmt or /tmp; the lead
```

The content check reads the text the write leaves: Write's content; for Edit,
the file with old_string replaced by new_string (every match with
replace_all); for MultiEdit, each edit in order. The push check catches a doc
written through Bash, which no Write hook sees. It skips DR and E ids, since
code may use them.

A rung brief waits for the precedents sweep (`sweeping-precedents`, brief-grilling
step 0): `shared/records/precedents-gather.sh [--root <records root>] <project>` prints the
CHANGED, LEARNED and OWED rows of the project's earlier close reports, each with
`<record> · <section> · row <n>` (logic in `shared/records/precedents_gather.py`), a haiku
agent gets that output pasted into its prompt and replies with rows as JSON
in the shape of the schema
(`shared/skills/sweeping-precedents/templates/sweep.schema.json`), and the lead
saves the reply as the record's `precedents.json`, then picks.
`shared/records/precedents-check.sh [--schema <path>] <record dir>` (logic in
`shared/records/precedents_check.py`, stdlib only) derives the project from the path,
runs the gatherer itself, and holds the JSON to the schema and to the
gatherer's rows: every printed reference placed exactly once, no invented
one, the counts and records the gatherer's, a "(same text as ...)" row beside
its first, P ids in order, an owner quote verbatim, the none form only with no
row printed. The gate runs the same command before the first write of a brief. It does
not judge whether a rule, `fits` or `status` is right; the owner reads the
carried rows at "brief ok". Only the first write of a brief is checked, so a
rung briefed before the sweep existed keeps its brief editable with no
`precedents.json`.

A new skill a gate names needs its link in `~/.claude/skills/` (for this one,
`ln -s "$FLEET_REPO/shared/skills/sweeping-precedents" ~/.claude/skills/sweeping-precedents`)
in the same step as the merge. Without it the Skill tool cannot load the skill,
skill-mark.sh writes no marker, and the gate denies every write the skill
covers: here `precedents.json`, and so every new rung brief.

A deny is not a loss: the model gets the reason, invokes the skill, and the
retry passes. /tmp and the scratchpad never match. A marker proves the body
was loaded this session, not that it was followed; that stays with lead-1's
review and the haiku check. Test: `shared/tests/test-skill-hooks.sh`.
