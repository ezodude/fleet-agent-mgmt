# Changelog

AgentMgmt changes, newest first, one line per change, its commits in brackets.
Left out: ledger entries, lead-1 state-block commits, per-ticket design, spec and handoff records, session handoffs, test-only commits and merges. A day with only those has no heading.

## 2026-10-28

- Changed the brief template so a brief displays correctly in a markdown viewer: the title is a heading, each field is a heading, constraints and open are numbered lists, only the gate block sits in a fence, and no line runs over 150 characters; brief-grilling runs `md-check.sh` on a brief before it is drawn and before it is saved

## 2026-10-27

- Added the precedents sweep: `precedents-gather.sh` prints a project's earlier close-report lessons, a haiku agent sorts them into the record's `precedents.json`, and `precedents-check.sh` checks it against the gatherer; a rung brief's first write waits until the check passes (5ee69bf)

## 2026-10-26

- Added `term-width.sh`, which measures the room a card has in the fleet pane, and `card-width.txt`, the cap it sets: 54 columns at a 160-column terminal (accdf1d)
- Changed `card-add.sh` to refuse a card with a body line over the width cap or a label over 10 characters, as the pane draws them (accdf1d)
- Changed grill questions to go out as lead-1 cards: holding-rollups, brief-grilling and the decision card send the body to the card file and the main window carries the pointer line (accdf1d)

## 2026-10-23

- Added the owner's override of a red gate line: the owner types `<lane> r<n> override <checks>: <reason>` in the IC's pane, the IC quotes it in a DR, and push-gate lets the push through; the receipt stays red and the close lists it (0408ccd, 140fcdf)
- Added the fleet-console mod: a read-only side pane showing each IC's state, its record's done line and lead-1's open decision cards (9bbd200)
- Added `card-add.sh`, which writes lead-1's decision cards to files and marks them answered (f53c64f)
- Added `state-set.sh`, lead-1's safe way to write into an IC's STATE.md: it refuses a file that changed under it, keeps its timestamp and writes by rename (8c2e992, 4b477d8)
- Added the prompt marker: when the owner or lead-1 types in an IC's pane, the IC updates its STATE.md before its turn ends (d3268c4)
- Added a regression suite that runs the state checks on copies of the live STATE.md files (10b163b, 188e082)
- Changed decision cards to go to a card file first; once the mod is loaded the main window gets only a pointer line (85526b0)
- Changed lead-1 to start with the fleet-console mod (4510f24)
- Fixed the prompt marker loading for every session; it now loads for ICs only, from `ic-settings.json` (d9dc7d8)
- Fixed `state-set.sh` writing a STATE.md that md-check fails, or one with unpaired backticks (9a50b1f)
- Fixed the state check skipping an IC working in a sub-folder of its repo (f8afd23)

## 2026-10-22

- Added a check on the STATE "awaiting" line: it opens with none, owner:, lead-1: or an IC's name, owner first; the state gate and ledger-add both enforce it (c8d1346, fa453df, f383762, b9a4ea0)
- Added a whole-fleet check that `ledger-add.sh` runs before every entry, refusing the entry on any fault (afcc02a)
- Added lead-1 committing each record folder when its ticket ends; the skill boot skips committed records (53894f7)
- Added `md-check.sh`, which fails a markdown file a viewer would display wrongly; closing a rung runs it (0ce49d3)
- Changed the handoff template so repo files carry no "Ruled by" line (785f590)
- Fixed the awaiting check missing the owner named by name or in another letter case (4a7e351)
- Fixed the state check ignoring the state block's layout; older text now moves under "## log" (ee1132f)
- Fixed IC STATE.md files drifting from the 15 keys; they sit in a state block with history below it (232d353)
- Fixed shared files naming the old checks folder; they name `~/.fleet-agent-mgmt/checks` (73ae612)
- Fixed the message gate misreading a STOP header with a suffix (930478f)
- Fixed the rules freeze missing the owner's word when it carried quotes or an option tag (4e2cbb3)
- Fixed close reports displaying wrongly in a markdown viewer: tables, lists, plain-text blocks and reply strings (0dbb0e2, bdab10b)

## 2026-10-20

- Changed the skills so a card opens with the problem in plain words, and mechanics are the lead's call, not the owner's (fe54414)

## 2026-10-17

- Changed the roster: an interview IC works in worktree w3 (9c7fc37)

## 2026-10-16

- Added the grilling skill to the shared skills, with probe times, lane ids, sub-grill ids, a critic on every block and verbatim logging (94d8008)
- Changed the shared skills to name no person, project, ticket or session; every example is invented (2bae48f)
- Changed the roster: a library IC row became an interview IC (9619172)

## 2026-10-15

- Added PO views for external trackers: Jira, GitHub or any later tracker gets only `<tracker>-po.md`, cut from the fleet ticket; `ticket.md` never leaves the fleet (ac67db4)
- Changed the roster so a rung can name the Free Edition profile and a sandbox catalog (9d14f29)
- Fixed `amend-frozen.sh` accepting a rules change or a new Checks line without the owner's typed "amend ok" naming the card (b4b5c66)

## 2026-10-14

- Added `record-add.sh`, which writes decision record and evidence entries behind an append-only guard and runs the Jev audit after each write (1c99b80)
- Added a public-docs guard: the spec template carries no fleet terms, and a leak check runs at artefact and push time (e87e0c0)
- Added Markdown tables for the spec's rules and Checks, which the freeze reads (8bc8716)
- Changed lead-1's STOP checks to run on Haiku 5.5 (3c82cb4)
- Changed the roster and the record lists after two rungs ended, and listed seriatim-r1 as a legacy record folder (c2b9dbd, 84977de, 5ea0688)
- Fixed the spec freeze accepting a "spec ok" the owner had not typed after the newest STOP 1; it reads Claude Code's session logs (1488e3d)
- Fixed `ledger-add.sh` committing files staged elsewhere; it commits the ledger by path (a20e27f)
- Fixed Jev blocking a push or PR on the rung's own branch; push-gate refuses when the newest jev line says stop and ask or rework (91c38c5)
- Fixed plans landing in the repo; they live in the record folder (6035acd)
- Fixed five freeze faults: a strict spec parser, frozen-file hashes, a Bash write gate, the STOP 1 chain and restored rules (af7b783)

## 2026-10-13

- Added the bounded rung: gate outcomes in the brief, at most two re-runs per red line, a sandbox scope, and the IC opening a draft PR at a green receipt behind `push-gate.sh`; the review became an audit after the push (55452d1)
- Added held-list keys to `ledger-add.sh` (held+=, held-=, held-note=), a line-count guard and tests (d718b2f)
- Added skill gates: a session handoff needs drafting-handoff, and a lead-1 message over 15 prose lines needs explaining-in-steps (81bd031)
- Added retired rule rows: a row tagged `[retired <date> by <line>]` is no longer asked (2d90f46)
- Added the IC flow reference, the revert runbook and the framework behind them (994117a)
- Changed rung briefs, tickets and handoffs to live in the record folder; the old Leads/lead-1 paths refuse writes (4291468)
- Changed project profiles to one file per project under `~/.fleet-agent-mgmt/profiles` (abe7ba4)
- Changed the skill gate to read the turn through `turn_text.py` (b0fbfaf)
- Changed brief-grilling: a fact sweep first, the gate critic before the owner sees the block, a delta draw at the close (48e88cb)
- Changed briefs to be amended in place, carried to the decision record as "goal amended" (56b1aff)
- Changed the roster: reco-ic-1 added, then retired after its rung closed (cdc4f0b, 39acbbf)
- Fixed "ready for push" passing when a jev line had no receipt behind it (6bd9f0e)
- Fixed dr-check checking only the newest entry; it checks every entry with no jev line (dd379d4)
- Fixed a failed Jev check being graded by the IC itself; it is now stop and ask, and the freeze expands `~` (944ec9a)
- Fixed a rule row that starts with a number losing it (5e457ac)
- Removed the stale JEV_LOG note from `dr-check.sh` (80572a6)

## 2026-10-12

- Added `freeze-rules.sh`, which writes rules.md from the committed spec, byte for byte at its sha (0e21f58)
- Added a TERMS block to the design spec that names each thing once; the freeze copies it into rules.md (62287b3)
- Added a receipt per Jev call under the record's receipts/; dr-check names the lines it skipped (e4b8b86)
- Changed dr-check so the owner's word clears any rule line, and the jev line names the row cleared (7fc4a15)
- Changed dr-check's REJECTED and DECIDED questions and set its band at 0.65 (686815c)
- Changed dr-check and gate-run to keep their logic in Python (`dr_check.py`, `gate_run.py`) behind small shell wrappers (9c46c84, d3502a3)
- Changed skills, scripts and hooks to give plain reasons instead of citations; the owner's name stays only on the roster (1ec1eb7, e7a448e)
- Changed the skills: the money line names the act, one-way lines start with a verb, verdict keys and the jev rework count show at review and close (edcee02)
- Changed the roster: dbx-ic-1 and dbx-ic-2 ended their rungs, sessions killed and STATE archived (7682344, 65c28be, 7c9dafe)

## 2026-10-09

- Added plan and question lines to decision record entries, and a goal line to the record header (2f30125)
- Added JEV_LOG to `dr-check.sh`, recording the raw answers per call for calibration (ab5569d)

## 2026-10-08

- Added `dr-check.sh`: Jev checks every decision record entry against rules.md and appends its verdict as a jev line; it runs as an IC hook (a817abe)
- Added `gate-run.sh`, which writes a receipt per gate run; the message gate refuses a STOP with no receipt at HEAD or a tick over a red line (950938b)
- Added the recording-a-decision and recording-evidence skills, and the record folder under `~/.fleet-agent-mgmt/records` (ff2f311)
- Added brief-grilling: the lead's grill for a rung ends in a brief, not a design, with profile questions on a project's first rung (9a8cb0c)
- Added the foundations one-way.md, definition-of-done.md with seven project profiles, and rung-flow.md (fdc0db4, 08c593c)
- Changed writing-a-ticket and writing-a-rung-handoff: the gate block comes from the brief, a profile is required, the standing done list is pasted verbatim, research tickets, the record folder (08820dd)
- Changed writing-a-design-spec: direction, rejected, subtleties and rule lines on screen one; STOP 1 shows screen one only; rules.md frozen at the approval sha (ae081b1)
- Changed reporting-a-rung, closing-a-rung and holding-rollups: the ready-for-push review and band, the receipt in the check, close.md in the record folder (5b3c2c3)

## 2026-10-01

- Reverted stop triage: reporting-a-rung's step 0 and its automatic rows removed (076d201)

## 2026-09-29

- Changed writing-rules: publish, then read back every doc before calling it done (e38344c)
- Changed the lead charter to let lead-1 relay dev user-target Databricks writes (27e470b)

## 2026-09-24

- Added `stop-triage.py`, which scored a STOP for auto-proceed, with its config and a 29-case test (ed9def1)
- Added the stakes line, save-then-send and stop triage as the lead's step 0 to reporting-a-rung (c6f448f)
- Added stop-triage reading its key from the environment or a mode-600 key file; `agent-up.sh` warns when there is none (6a65655)
- Changed writing-a-ticket: Jira's Definition of Done is plain done-lines, and the gate block opens Further detail (0039e1f)
- Fixed stop-triage's parsing of labels, options and stakes (06eec5c, 0dbca15)
- Fixed stop-triage checking outward words on every option; it checks the picked option only (f80f357)
- Fixed stop-triage's confidence cut-off, raised from 0.5 to 0.7 after replay swings (cbe0165)

## 2026-09-23

- Changed the fleet to claude-opus-5-5, with model and effort in settings files and a `--model` override (4a83cdd)
- Changed the roster: platform-ic-1 added for its first rung (d86ac5f)
- Fixed `agent-up.sh --resume` ignoring the settings file's model (e62511e)
- Fixed `agent-up.sh` picking the wrong transcript; it picks by agent name (718b0ff)
