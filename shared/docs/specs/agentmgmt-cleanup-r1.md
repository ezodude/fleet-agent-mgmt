# agentmgmt-cleanup r1: one reusable repo, the user's data in a state folder

**Problem:** nobody else can clone AgentMgmt: it mixes the agent team's code with one user's data (Leads/, lead-ux/, client names in shared/roster.md and test fixtures; TechLeads/ and archive/ are retired, not copied, and stay only in AgentMgmt, maintainer 2026-11-11), and 45 tracked files outside those folders name the user's home path (agentmgmt-cleanup r1 ticket; `git ls-files | xargs grep -l`, 2026-11-11).

**Verdict:** buildable as drawn. Four open questions change no component: where the clone sits, how the lead session keeps its history, when running worker sessions move, and the token list the clean-clone scan uses.

## Terms

| name | what it is |
|---|---|
| `fleet-agent-mgmt` | the new repo: one commit, code only; "the new repo" in the ticket |
| AgentMgmt | the current repo, kept whole and frozen as an archive after the move; "the old repo" |
| `FLEET_HOME` | the one setting: the state folder holding the roster, ledger, records, checks and the copied Leads/ and lead-ux/ folders |
| lead session | the long-running Claude session that coordinates the others and keeps the ledger |
| worker session | a Claude session agent-up.sh launches from a roster row onto one ticket; "IC" in the ticket |

## Direction

Every script finds the repo from its own location and the user's data from `FLEET_HOME`; one install script writes the machine-local settings and skill links; the data folders are copied, never moved, so AgentMgmt stays whole as the rollback. Because `FLEET_HOME` already exists (shared/shape-up.sh line 15), 40 shared/ files already find their own folder with `dirname "$0"`, and the hard paths left are defaults (shared/hooks/state-gate.sh lines 29-31, shared/ledger-add.sh line 25, shared/hooks/push-gate.sh line 118) and the hook lines of shared/ic-settings.json and shared/lead-settings.json.

## Rejected

| do not come back to | source |
|---|---|
| move the data folders with mv | ticket at-risk: an untracked file lost in a move has no git copy, and a copy leaves the old tree as the rollback |
| copy the lead session's history into the new folder's history store | code.claude.com/docs/en/sessions: with two copies, resume by id reports not found; it is also a write to the history store |
| `$FLEET_REPO` in the user-level hook lines | that Stop hook runs in every session on the machine; a session without the variable gets a broken path |
| a real Claude login in the launch test | code.claude.com/docs/en/authentication: a separate config folder needs its own login; a stub `claude` on PATH proves the launch line |

## Subtleties

- state-gate.sh is a user-level Stop hook, so a wrong path there stops every Claude session on the machine, not only the agent team's.
- A session launched before the cut-over keeps its old paths until relaunched, and keeps working: AgentMgmt is copied from, never emptied.
- "No user data in any commit" covers contents and messages; the commit author name stays the user's (ticket, not in this rung).
- The token list names clients, so it lives in `FLEET_HOME`, never in the repo; a clone without it scans for home paths only.

## One-way

| stop and ask before | source |
|---|---|
| repoint the user-level Claude settings file to fleet-agent-mgmt | agentmgmt-cleanup r1 ticket, the cut-over |
| repoint the 13 user-level skill links to fleet-agent-mgmt | agentmgmt-cleanup r1 ticket, the cut-over |
| repoint the lead session's or the board design session's working folder | agentmgmt-cleanup r1 ticket, the cut-over |
| write to the live lead, board design or worker session folders | agentmgmt-cleanup r1 ticket |
| move any file out of the live Leads/, TechLeads/, lead-ux/ or archive/ folders | agentmgmt-cleanup r1 ticket |
| write to the Claude Code session history store | agentmgmt-cleanup r1 ticket |
| relaunch a running worker session on the new paths | agentmgmt-cleanup r1 ticket |
| freeze the AgentMgmt repo | agentmgmt-cleanup r1 ticket |
| push fleet-agent-mgmt to any remote | agentmgmt-cleanup r1 ticket |
| rewrite any git history | agentmgmt-cleanup r1 ticket |

## Decided

| # | never change | lands in | source |
|---|---|---|---|
| 1 | nothing user-specific in fleet-agent-mgmt, files or history; user state lives under `FLEET_HOME` | fleet-agent-mgmt, new | maintainer, 2026-11-10 17:28Z |
| 2 | the agent team keeps running through the move; the cut-over waits until no brief is mid-flight | shared/docs/migration.md, new | maintainer, 2026-11-10 17:28Z |
| 3 | this rung moves the data, adds the one setting, groups shared/, moves the viewer and cuts over once; the ledger stays markdown | shared/, modify | maintainer, 2026-11-10 17:56Z |
| 4 | the board viewer moves to shared/board/; board.md stays in `FLEET_HOME` | shared/board/, new | agentmgmt-cleanup r1 ticket |
| 5 | a new history-free repo; AgentMgmt frozen as the archive, never rewritten or pushed | fleet-agent-mgmt, new; AgentMgmt, reuse | maintainer, 2026-11-10 18:05Z |
| 6 | the new repo is named fleet-agent-mgmt | fleet-agent-mgmt, new | maintainer, 2026-11-10 18:05Z |
| 7 | the migration ships written down, step by step, rollback included | shared/docs/migration.md, new | maintainer, 2026-11-10 18:05Z |
| 8 | the user's first name and handle, any case, appear in no file; docs and skills name the role, never the person | shared/, modify | maintainer, 2026-11-10 18:34Z |

## Building

```
fleet-agent-mgmt, any folder                      FLEET_HOME
  shared/launch/   agent-up, shape-up, settings ──▶ roster.md (moved out of shared/), shaping/
  shared/hooks/ records/ ledger/ fleet/ board/ tests/ ──▶ Leads/ lead-ux/ (copied), checks/, records/
  shared/migrate/  install.sh ──▶ user-level settings and skill links, absolute clone path
cut-over   record AgentMgmt HEAD ─▶ copy + hash ─▶ install ─▶ lead resumes in FLEET_HOME ─▶ workers move at close ─▶ freeze
rollback   install.sh --repo AgentMgmt ─▶ lead resumes in AgentMgmt; the copy stays in FLEET_HOME
```

## Open

- Where the clone sits: a) beside AgentMgmt in the Projects folder, recommended: one short path for every hook line; b) inside `FLEET_HOME`: code and data mixed again.
- How the lead session keeps its history: a) relaunch it in its new folder with `claude --resume <session id>`, recommended: Claude Code finds a session id across project folders when one copy exists (code.claude.com/docs/en/sessions), nothing is copied, and the rehearsal tries it on a throwaway session first; b) start fresh from its last resume note.
- Running worker sessions at the cut-over: a) each keeps its old paths until its ticket closes, then relaunches, recommended: the old paths keep working; b) relaunch each mid-ticket, changing its hooks mid-ticket.
- The clean-clone token list, and whether the push leak check (shared/hooks/push-gate.sh) also reads it after this rung: recommended yes, both read one list in `FLEET_HOME`.

## Checks

| command | pass | on main |
|---|---|---|
| `for t in shared/tests/test-*.sh; do bash "$t" \|\| exit 1; done` | exit 0, "0 fail" | red, this change builds it: exit 1, "bash: shared/tests/test-*.sh: No such file or directory" |
| `shared/migrate/check-copy.sh` | exit 0, "0 missing", "0 differing" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/tests/test-clean-clone.sh scan` | exit 0, "owner tokens: 0 hits" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/tests/test-clean-clone.sh launch` | exit 0, "launch: ok" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-live.sh` | exit 0, "old-repo paths: 0" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-cutover.sh lead` | exit 0, "lead: ok" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-cutover.sh worker` | exit 0, "worker: ok" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-live.sh --rehearsal` | exit 0, "old-repo paths: 0", "rehearsal lead turn: ok", "rehearsal launch: ok" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-live.sh --rolled-back` | exit 0, "new-repo paths: 0" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/tests/test-layout.sh` | exit 0, "0 fail" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/tests/sealed-run.sh` | exit 0, "0 fail", "planted read: caught" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/tests/test-clean-clone.sh planted` | exit 0, "planted: 3 of 3 caught" | red, this change builds it: exit 127, "No such file or directory" |
| `shared/migrate/check-frozen.sh` | exit 0, "frozen: ok" | red, this change builds it: exit 127, "No such file or directory" |

## Tests

| Test | Proves | Does not prove |
|---|---|---|
| test-clean-clone.sh | a fresh clone under a separate home has no user token, starts a shaping session and launches one agent | that a real Claude login works under that home |
| sealed-run.sh | every test passes from a clone in another folder with the user's folders denied | Linux: sandbox-exec is macOS only |
| test-layout.sh | every script sits in a named group, and the viewer lists board.md's sections from `FLEET_HOME` | how the viewer looks to a person |
| check-live.sh --rehearsal, --rolled-back | the written migration and its rollback leave no stale path in a scratch home | the live home: that is check-live.sh with no flag |
| check-cutover.sh lead, worker | the lead passes the state gate on 3 turns while a worker commits a record; a relaunched worker writes a receipt | sessions not yet relaunched |

---

## Paths: FLEET_HOME and the repo root

```
contract   shared/lib/paths.sh, sourced by every shell script:   FLEET_REPO = the clone root, from the script's own folder
                                                                 FLEET_HOME = $FLEET_HOME if set, else the default under the user's home
           shared/lib/paths.py, imported by every python script: the same two names, the same rule
           every script reads data only under FLEET_HOME: roster.md, Leads/, lead-ux/, checks/, records/, profiles/, shaping/
data       FLEET_HOME layout, the same folder names AgentMgmt used:
             roster.md            the fleet block and the owner line (moved out of shared/roster.md)
             Leads/ lead-ux/      copied from AgentMgmt, never moved
             checks/ records/ profiles/ samples/ shaping/   already there today
             leak-tokens.txt      the clean-clone token list; absent in a fresh clone
errors     FLEET_HOME missing: a script that needs data exits 2 naming the folder and install.sh
must not   hard-code a home path; read the roster from shared/
source     shared/shape-up.sh line 15 (FLEET_HOME exists); 40 shared/ files already use dirname "$0" or __file__
```

## shared/launch/

```
contract   agent-up.sh <name>, shape-up.sh: unchanged command lines; the roster comes from FLEET_HOME/roster.md
           the tmux launch line exports FLEET_REPO and FLEET_HOME before claude starts
           ic-settings.json, lead-settings.json, shape-settings.json: hook lines read "$FLEET_REPO/shared/hooks/<hook>"
data       roster.example.md: an invented fleet (owner "Robin", rows atlas-ic-1, orbit-ic-1) for a fresh clone
moves      agent-up.sh shape-up.sh *-settings.json term-width.sh card-width.txt shaping/  from shared/ to shared/launch/
errors     no FLEET_HOME/roster.md: agent-up.sh exits 1 and names roster.example.md
must not   put a model or effort on the launch line (unchanged rule, agent-up.sh lines 9-40)
source     shared/agent-up.sh lines 19-21, 79-89; shared/ic-settings.json lines 15-84
```

## shared/hooks/

```
contract   every hook finds its siblings from its own folder; data paths from shared/lib/paths.*
fix        state-gate.sh lines 29-31: SCHEMA from the repo, STATE files from FLEET_HOME/checks
           state-gate.sh: the lead's ledger is current by the newest commit touching the lead's own folder, not HEAD,
             so a worker's record commit in FLEET_HOME never trips it; each pass is logged for check-cutover.sh
           push-gate.sh line 118 GATE_RUN, message-gate.sh lines 81 and 86, skill-lib.sh, postcompact-boot.sh line 21,
             leak_check.py line 28: from FLEET_REPO or FLEET_HOME
           leak_check.py and push-gate.sh read FLEET_HOME/leak-tokens.txt when it exists
must not   change what any gate allows or denies; the user-level hook lines stay absolute paths (Rejected, row 3)
source     the line numbers above, at AgentMgmt main
```

## shared/records/, shared/ledger/, shared/fleet/

```
moves      records/  record-add.sh record_add.py gate-run.sh gate_run.py freeze-rules.sh freeze_rules.py frozen.py
                     amend-frozen.sh legacy-records.txt frozen-before-stop1-log.txt precedents-* md-check.sh md_check.py
           ledger/   ledger-add.sh ledger_add.py card-add.sh state-set.sh
           fleet/    fleet-check.sh fleet-fix.sh fleet-audit.sh
fix        ledger-add.sh line 25: the ledger path from FLEET_HOME; it signs by git config, never a forced -S
           freeze_rules.py line 233 LEAD_CWD: the lead's folder under FLEET_HOME
           fleet-check.sh line 45: from FLEET_HOME
           skills and docs name scripts as $FLEET_REPO/shared/<group>/<script>; install.sh sets both names in the
             user-level settings env block, so every session's shell has them
must not   change a script's arguments or output
source     shared/ledger-add.sh line 25; shared/freeze_rules.py line 233; shared/fleet-check.sh line 45
```

## shared/board/

```
moves      lead-ux/fleet-board.sh to shared/board/fleet-board.sh
fix        FLEET_DIR becomes FLEET_HOME; url_of reads its links from FLEET_HOME/board-links.tsv, absent in a fresh clone
contract   fleet-board.sh list: non-interactive, prints board.md's section names from FLEET_HOME
must not   change the board's look
source     lead-ux/fleet-board.sh (FLEET_DIR, url_of)
```

## shared/tests/

```
moves      every test-*.sh and testdata/ from shared/ and shared/hooks/ to shared/tests/
fixtures   invented keys ATL- and ORB-, owner "Robin"; no real name, key, client or home path
           files to clean: test-skill-hooks.sh (34 home paths), test-record-add.sh, test-ledger-add.sh, test-hooks.sh,
             test-precedents.sh, STATE-schema.md, .gitignore line 4
new        test-clean-clone.sh scan|launch|planted
             scan     clones the repo into a temp folder, greps every file and every commit for the token list
                      (FLEET_HOME/leak-tokens.txt, else home paths only); prints "owner tokens: N hits"
             launch   HOME set to a temp folder, tmux on a private socket, a stub claude on PATH;
                      runs install.sh, shape-up.sh and agent-up.sh atlas-ic-1; prints "launch: ok"
             planted  plants three tokens in a temp clone (a file, a commit message, a test fixture); prints
                      "planted: 3 of 3 caught"
           sealed-run.sh: clones into a temp folder and runs every test under a sandbox-exec profile that
             denies AgentMgmt, the default state folder and the Claude home; one planted read must fail
           test-layout.sh: every script sits in a named group, no script left at the top of shared/, and
             fleet-board.sh list prints the sections of a fixture board.md
errors     a test that reads outside its temp folder fails under sealed-run.sh
source     sandbox-exec deny profile: a denied read exits 1 "Operation not permitted" (run 2026-11-11)
```

## shared/migrate/

```
contract   install.sh [--repo <clone>] [--home <user home>]
             writes absolute <clone>/shared/hooks/... into the user-level hook lines, repoints the 13 skill
             links, sets FLEET_REPO and FLEET_HOME in the user-level env block; prints each change
             --repo <AgentMgmt> is the rollback
           copy.sh <AgentMgmt> <state folder>
             records AgentMgmt HEAD, copies Leads/ and lead-ux/ (tracked and untracked), moves roster.md's
             data to <state folder>/roster.md, writes copy-manifest.tsv (path, sha256 at copy time)
           check-copy.sh       every manifest file present in the state folder with its hash: "0 missing", "0 differing"
           check-live.sh       greps the user-level settings, skill links, launch lines: "old-repo paths: 0"
             --rehearsal       the whole migration in a scratch home, then a lead turn and a launch there
             --rolled-back     install.sh --repo <AgentMgmt> in the scratch home: "new-repo paths: 0"
           check-cutover.sh lead|worker
             lead     three lead turns pass state-gate.sh while a worker commits a record: "lead: ok"
             worker   a relaunched worker writes a STATE receipt under the new paths: "worker: ok"
           check-frozen.sh     AgentMgmt HEAD equals the recorded HEAD and its tree is unchanged: "frozen: ok"
           make-repo.sh <dest>  one commit of the tree without Leads/, TechLeads/, lead-ux/, archive/, then
             test-clean-clone.sh scan on it
data       TechLeads/ and archive/ are not copied: they stay in AgentMgmt (maintainer, 2026-11-11)
must not   move or delete a file in AgentMgmt; write session history; push
source     agentmgmt-cleanup r1 ticket, the cut-over and rollback
```

## shared/docs/migration.md

```
contract   the cut-over in order, one command per step, each with its check line:
             1 wait until no brief is mid-flight      2 copy.sh, check-copy.sh       3 make-repo.sh
             4 install.sh, check-live.sh              5 the lead relaunches in its new folder, check-cutover.sh lead
             6 each worker relaunches at its close, check-cutover.sh worker     7 freeze AgentMgmt, check-frozen.sh
           rollback: install.sh --repo <AgentMgmt>, check-live.sh --rolled-back; the copy stays in FLEET_HOME
must not   run a one-way step without the maintainer's word
source     agentmgmt-cleanup r1 ticket
```

## Risks and watch

| risk | watch |
|---|---|
| a wrong path in state-gate.sh stops every Claude session on the machine | check-live.sh --rehearsal runs a lead turn in a scratch home before the live install |
| a script missed by the move still names shared/<script> | test-layout.sh and sealed-run.sh fail on a stale path |
| the lead's history does not resume in the new folder | rehearsed on a throwaway session; rollback is install.sh --repo AgentMgmt |
| the ledger keeps growing after the copy | check-copy.sh compares against hashes taken at copy time |

## Glossary

| term | meaning |
|---|---|
| sandbox-exec | the macOS command that runs a process under a deny profile |
| tmux private socket | `tmux -L <name>`: a server that cannot see the user's own sessions |

## More information

- agentmgmt-cleanup r1 ticket
- code.claude.com/docs/en/sessions (resume by id), code.claude.com/docs/en/settings (env block, hooks)

---

## Amendments

2026-11-12 install.sh --home names the user's home; the state folder is FLEET_HOME, default <home>/.fleet-agent-mgmt (final review of this branch).
