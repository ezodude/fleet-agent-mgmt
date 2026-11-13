# One-way acts

A one-way act is one the fleet cannot undo with one command. Before any
act on the list the IC stops and asks for the owner's word, typed in the
IC's pane. Everything else is two-way: the IC decides, writes a decision
record entry (`recording-a-decision`) and continues. The framework the
owner holds core: guardrails not gates, one-way and two-way decisions.

This list holds for rungs whose handoff is written from 2026-10-13. A rung
already running keeps its frozen `rules.md` and `gate.md`.

## The standing list, expanded into every rung's rules.md at the freeze

Plain one-line rules, one act per line, written for a decision model that
answers "does this decision do that?" yes or no per line. No "unless",
no "normally", no two acts on one line.

```
ONE-WAY  stop and ask before:
  push to main, master, the repo's default branch, or a branch another person pushed to   [standing]
  force-push to any remote branch                                    [standing]
  push the rung's own branch or open its draft PR before a green gate receipt at HEAD   [standing]
  mark a pull request ready for review, merge it or close it         [standing]
  merge into any branch another person reads                         [standing]
  deploy, release, tag a release or run a release job outside the profile's sandbox   [standing]
  a third sandbox deploy or e2e run in one rung                      [standing]
  write over state another person or worktree wrote                  [standing]
  write to a shared warehouse, schema, table, job or workspace       [standing]
  create, start or resize anything that keeps billing after the command returns: a cluster, a warehouse or SQL endpoint, a job schedule, a subscription or paid plan   [standing]
  write to a ticket, a wiki page, a chat channel, or the body of a PR marked ready   [standing]
  change a DECIDED row or come back to a REJECTED row                [standing]
  any act only the owner can take                                    [standing]
```

A project's extra one-way acts live on the `one-way` line of its profile,
`~/.fleet-agent-mgmt/profiles/<project>.md`. The rung handoff's §2 `one-way`
block lists the brief's acts and the profile's acts, one act per line
(writing-a-rung-handoff step 7). The freeze never reads the profile: an act
reaches rules.md only as a spec row.

Screen one of the spec carries only the per-rung lines, in its
`## One-way` table of `stop and ask before` rows: one row per line of the
handoff's `one-way` block, none dropped, plus any act the design makes
one-way. Each row is in the team's words, with its source in its own
`source` cell (the ticket, a repo file and line). The spec never names this
file, the brief, the handoff or the gate block (foundations/public-docs.md).
At STOP 1 lead-1 checks every handoff `one-way` line has its row; a missing
one is `spec back`. At "spec ok"
`shared/records/freeze-rules.sh <spec path> <record folder> --approved <sha>`
(writing-a-design-spec step 5) writes `rules.md` with the standing lines
verbatim above them, `gate.md`, and `frozen.sha256`. The IC may add a line;
it may not remove or soften a standing one. A later change goes through
`shared/amend-frozen.sh` (recording-a-decision).

## Who reads the list

```
  the IC        before any act the list names: stop, ask in the pane, wait
  push-gate.sh  on every `git push` and `gh pr create`: the five push conditions
                below, denied on a miss; `gh pr merge` denied always; `gh pr ready`
                denied unless the newest DR has an `owner` line (shared/hooks/push-gate.sh)
  dr-check.sh   on every decision record entry: the standing list as two questions
                (standing-1 outside the worktree, standing-2 writes where others read)
                plus one per spec line. A yes on a one-way line with no `owner` line
                writes `stop and ask, standing-1 …`; a yes on DECIDED or REJECTED
                writes `rework, decided-n …`; both before the act (shared/hooks/dr_check.py)
                For standing-1 and standing-2, a push of the rung's own branch and
                opening its draft PR are not outside the worktree and not a write where
                others read; push-gate.sh holds their five conditions. A push to main or
                the default branch, a force push, marking ready, merging, deploying, and
                a ticket, wiki or chat write stay yes
  lead-1        in the audit after the push: a one-way act with no
                owner's word in the record is the owner's card, always
```

## Two-way, by contrast

A choice the IC can undo with one revert inside the rung's branch and
worktree: a file layout, a function's shape, a fixture, the wording of a
doc not yet published. The IC decides, records it and continues. The
`undo` line of the entry is the test: if it cannot be written in one
line, the act is one-way and the IC stops.

Three acts reach past the worktree and are still two-way, each only on
its conditions. A miss on any condition makes the act one-way: stop, ask.

```
  push the rung's own branch and open its draft PR, all five required:
    1  the newest gate receipt is at HEAD with 0 red lines, or each red line
       overridden by the owner: "<lane> r<n> override <checks>: <reason>" typed
       in the IC's pane, and a DR whose `owner` line quotes it; the receipt stays red
    2  the jev audit on the decision record exits 0
         python3 shared/hooks/dr_check.py <record>/decision-record.md --audit
    3  the branch is the rung's own feature branch, named in the handoff;
       never main, master or the default branch; never a branch another
       person has pushed to
    4  a plain push: never --force, -f, --force-with-lease or a +refspec
    5  the PR opens as a draft (`gh pr create --draft`), body from the spec summary
  one DR for the push, one for the PR; each names the receipt; no `owner` line.
  Marking the PR ready, merging and closing it stay the owner's word.

  deploy or run e2e from the rung's own branch to the project's sandbox:
    the sandbox is the `sandbox` line of the profile and nothing else: an
    environment, local or remote, that only this rung writes to. A local
    database, a container or a dev server on the IC's machine counts.
    Anything another worktree or person can write to is someone else's
    state, not a sandbox.
    at most 2 per rung; one DR each, numbered `sandbox 1 of 2`, `sandbox 2 of 2`.
    The third comes back to the owner: ask in the pane.
    No `sandbox` line, or `sandbox  none`: every deploy needs the word.

  re-run a red gate line whose fix stays inside the worktree:
    one DR per re-run, at most 2 re-runs per line; a third red goes to the
    owner (gate-block.md, on failure).
```
