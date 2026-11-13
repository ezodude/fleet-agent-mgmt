# The rung, end to end

One picture of a rung from the grill to the close, with who acts, what
is written where, and the three decision trees the rung turns on. Every
skill named is in `shared/skills/`; every hook in `shared/hooks/`.
The framework the owner holds core: guardrails not gates, a
standing Definition of Done, review at the end not at every step,
one-way and two-way decisions, blameless and accountable.

## The flow

```
  OWNER + lead-1                         IC                                                    WRITTEN WHERE
  ─────────────────────────────────────  ────────────────────────────────────────────────────  ───────────────────────────────────
  sweeping-precedents (step 0) ──▶ earlier closes' lessons                                     records/<project>/<lane>-r<n>/precedents.json
  brief-grilling ──▶ brief ok                                                                  records/<project>/<lane>-r<n>/brief.md
    (gate block: outcomes only; profile born on a first rung)                                  $FLEET_HOME/profiles/<project>.md
  writing-a-ticket                                                                             Jira | GitHub issue | filesystem (outcomes, no commands)
  writing-a-rung-handoff ──▶ launch ──▶  reads §0: gate outcomes, DECIDED, OPEN, CHAIN         records/<project>/<lane>-r<n>/handoff.md
                                         each gate line as a command, run once on origin/main  <record>/evidence.md
                                         writing-a-design-spec: screen one                     <repo>/docs/superpowers/specs/
                                           ## Checks: per gate line, command, pass line, main's output
                                 ◀────── STOP 1: direction review (hold)
  "spec ok" ──────────────────────────▶  freeze-rules.sh --approved <sha> ──▶ rules.md + gate.md + frozen.sha256    <record>/rules.md, gate.md, frozen.sha256
  lead-1: a line red on main (STOP 1) or red on main at a later STOP
    ──▶ after the freeze, amend gate.md (kind a|b), amend-frozen.sh, tell the owner            <record>/gate.md # Amended header line
                                         plan, no hold                                         <record>/plan.md  (never in the repo)
                                         build, autonomous
                                           a choice the plan left open ──▶ DR                  <record>/decision-record.md  (+ jev line, dr-check.sh ──▶ receipts/<stamp>-jev-DR<n>.json)
                                           every run ──────────────────▶ E                     <record>/evidence.md
                                           a red line, fix in the worktree ──▶ DR, re-run      at most 2 re-runs per line; a third red goes to the owner
                                           a sandbox deploy or e2e run ──▶ DR, sandbox n of 2  the profile's `sandbox` line; a third: ask in the pane
                                           a ONE-WAY line ──▶ ask in the pane, wait for the word ──▶ DR with owner line
                                           the owner types feedback ──▶ act ──▶ UAT entry
                                         gate-run.sh runs gate.md ──▶ receipt                  <record>/receipts/<stamp>-gate.md
                                 ◀────── STOP 2: ready for push (a report, no hold)            message-gate.sh: receipt at HEAD, no ✔ over red; jev audit exit 0
                                         push the rung's own branch, open a draft PR           push-gate.sh: the five conditions (one-way.md); one DR each
  lead-1: the audit after the push (never the diff)                                            REVIEW entry and DR `review` lines in the record
    DRs ok | rework, gates, TESTS, SUBTLETIES ──▶ band
    rework ordered in the pane ───────▶  new commits, same branch, new receipt, ready
                                         for push again, the draft PR updates                  (two rounds, then the owner)
  owner: the word to mark the PR ready,  closing-a-rung ──▶ close.md, then stop                <record>/close.md, NUMBERS with the band
    then merges                            the merged spec ──▶ freeze-rules.sh --check - --record   exit 2: each reason a `spec drift` gap row
  lead-1: at the ticket end, however it ends: the ledger close line with the record path,      $FLEET_HOME committed by lead-1
    and in the same step a commit of the record folder; profile edited on the word, committed
```

`<record>` is `$FLEET_HOME/records/<project>/<lane lowercase>-r<n>/`,
the owner's artefact, outside every repo. STOP files and
STATE.md stay under `$FLEET_HOME/checks/<ic>/`.

This flow holds for rungs whose handoff is written from 2026-10-13. A rung
already running keeps its frozen `rules.md` and `gate.md`.

## Tree 1, the IC before any act: one-way or two-way

```
  is the act a push of the rung's own branch, or opening its draft PR?
    yes ──▶ all five conditions hold (one-way.md, Two-way)?
              yes ──▶ one DR for the push, one for the PR, each naming the receipt; then act. No `owner` line.
              no  ──▶ it is one-way: stop and ask.
  is the act a re-run of a red gate line?
    yes ──▶ does the fix stay inside the worktree (code, tests, local cache, local tools)?
              yes ──▶ re-run 1 or 2 on this line ──▶ one DR (what was red, the fix, the receipt); fix, re-run.
                      a third red on this line   ──▶ stop, report it; it goes to the owner as a card via lead-1.
              no  ──▶ a sandbox deploy or e2e run? the next question. Anything else outside the worktree: stop and ask.
  is the act a deploy or an e2e run from the rung's own branch to the profile's `sandbox`?
    yes ──▶ sandbox 1 or 2 of this rung    ──▶ one DR, numbered `sandbox n of 2`; then act.
            a third                         ──▶ stop, ask in the pane.
            no `sandbox` line, or `none`    ──▶ stop and ask: every deploy needs the word.
  otherwise:
  is the act on rules.md ONE-WAY (standing list + the rung's lines)?
    yes ──▶ stop. Ask in this pane, quoting the line. Wait for the word. Then a DR with the `owner` line, then act.
    no  ──▶ did the plan already decide it, and would nobody ask about it in review?
              yes ──▶ act. No entry.
              no  ──▶ can the `undo` be written in one line?
                        no  ──▶ it is one-way after all: stop and ask.
                        yes ──▶ write the DR (plan, question, decided, instead of, because, undo, evidence). Read the jev line.
                                  continue     ──▶ act.
                                  stop and ask ──▶ ask in the pane, quoting the line; the next entry carries the word on `owner`.
                                  rework       ──▶ do not act. Next entry with a different `decided`, or ask lead-1 for a card.
                                  stop and ask, no check ──▶ the check did not run (no key, call error, missing answers): ask in the pane. Never grade the entry yourself.
                                  stop and ask, no check (rules.md or gate.md does not match frozen.sha256 | no [standing] lines)
                                               ──▶ a frozen file changed by hand: stop, tell lead-1; only amend-frozen.sh changes them.
                                  no rules.md ──▶ setup fault: tell lead-1; no entry belongs before the freeze.
```

## Tree 2, lead-1 after the push: the audit, and the band at the close

STOP 2 "ready for push" is a report, not a hold: the IC sends it at a green
receipt at HEAD and pushes without waiting. lead-1 audits the record after
the push (DR `review` lines, gates, TESTS, SUBTLETIES) and writes the
REVIEW entry. The band is recorded at the close.

```
  any ONE-WAY act with no `owner` line in the record?
    yes ──▶ the owner's card, now, whatever else is green. Next rung on this project at per-task STOPs.
    no  ──▶ rework items = DRs marked rework + gates red + TESTS unproven
            count only `crossed a line` and `claim false`; `better path found` is reworked, not counted
              0     ──▶ audit ok. Marking the PR ready and merging are the owner's word.
              1 - 2 ──▶ rework ordered in the IC's pane, same mode. New commits on the same branch, new receipt, the draft PR updates.
              3+    ──▶ rework ordered; next rung on this project at per-task STOPs until one clean rung.
            round 3 ──▶ the rung comes to the owner as a card.
  at the close ──▶ the band goes into close.md NUMBERS and sets the next rung's mode.
```

One lever moves (the mode); effort, model, the Jev check and the review
depth stay fixed, so a change in the numbers has one cause.

## Tree 3, the kind of rung

```
  is the goal an answer or a change?
    an answer ──▶ research: filesystem ticket; gate "the analysis answers the question with a recommendation
                  and says what it does not prove"; writing-an-analysis; evidence file only; closes on the word;
                  the ruling is the next brief.
    a change  ──▶ build: the flow above.
```

## What each artefact answers, after the fact

```
  precedents.json    which lessons of earlier rungs bound this one, and which were left out, why?
  brief              what was the problem and what did the owner hold?
  rules.md           what could the IC not do, at the sha the owner approved?
  gate.md            which commands prove done, at the sha the owner approved, and was a line amended?
  decision-record    what did the plan say, what did it leave open, what did the IC decide, instead of what, why, and did the check or the review object?
  evidence.md        what was run, where, with what exit code and output?
  receipts/          was the gate green at the HEAD that was pushed? what did Jev see for each entry, and what did it answer?
  close.md           was it shipped as designed, and what are the rung's numbers?
```

One grep each. lead-1 commits the folder once, at the ticket end
(however the ticket ends), and it is never edited after; a correction
is a later rung's entry that names it.
