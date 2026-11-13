---
name: recording-evidence
description: Use when a fleet IC (AgentMgmt Lead and ICs) runs anything whose result a report, a decision record entry, a TESTS row or a close report will rest on: a test command, a gate, a probe, a read-back, a count. The entry is written from the output, at the time of the run. IC-facing; the haiku check and lead-1 read it.
---

# Recording evidence

## Overview

The evidence file is where a claim becomes a fact: the command as run,
where and when, the exit code, the output as printed, what it proves and
what it does not. Every number in a STOP report or a close report, and
every number screen one of a spec rests on, points at an entry here or
is marked `unmeasured`; for the spec, the STOP report does the pointing.
It exists because a rung once closed on a false pass nobody could trace.
The evidence file has its own skill and template; gate receipts sit
beside it.

**Core principle:** quote, never paraphrase. "58 passed, 2 failed" stays
as printed. An entry is written when the run ends, not at the STOP.

**REQUIRED BACKGROUND:** `foundations/gate-block.md` (a gate is a
command plus a pass line), `recording-a-decision` (the folder).

## Where it lives

`$FLEET_HOME/records/<project>/<lane lowercase>-r<n>/evidence.md`,
beside the decision record. Gate runs go through
`$FLEET_REPO/shared/records/gate-run.sh <record folder>`, run
from the worktree; it reads `gate.md` in the folder (the exact commands
from spec screen one, frozen with rules.md at "spec ok" by
`shared/records/freeze-rules.sh`) and writes a receipt
under `receipts/`; the evidence entry for a gate is one line pointing at
the receipt, which the script prints ready to paste. A STOP message with
no receipt at the worktree's HEAD, or a ✔ over a red command, is refused
before it sends. The haiku check (`reporting-a-rung`, Lead side) reads this
file; lead-1 reads it only when the check says "cannot read".

## The entry

```
## E<n> <what, five words> · <date time>
  ran       <the command exactly as typed, one per line; variables shown as run>
  where     <cwd> · <branch> · HEAD <sha>
  exit      <code>
  output    <the lines that carry the result, quoted as printed; a tail of 1 to 10 lines>
  proves    <one line>
  does not  <one line: what this output leaves open>
```

The entry is written with
`$FLEET_REPO/shared/records/record-add.sh <record folder> e`,
run from the worktree, the entry on stdin: its first line is the five
words, then the indented lines. The script numbers it `E<n>`, stamps the
time and appends it at the end of the file; it refuses a missing field
(`ran`, `exit`), a number that is not the next one, or a file with no
header. Feed it with a quoted heredoc delimiter, `<<'EOF'`: a bare `<<EOF`
lets the shell run any `$(...)` in the body, and the hook denies it. A hook
denies an IC's Edit that does not append at the end, or appends anything but
the next `## E<n>` entry (text on the last line, an indented line under the
last entry), a Write over the file once it has text, and a Bash write to it
outside `record-add.sh`.

For a gate run: `ran` is the receipt path and `output` is the receipt's
verdict line (`green` or `red: <line>`), nothing retyped. For the main
run before STOP 1: the IC runs each Checks command once on origin/main,
one entry per command. `ran` is the command exactly as the Checks row
writes it, and `where` reads `<cwd> · origin/main · HEAD <sha>`, a sha
on origin/main. Spec screen one quotes this output in the `on main`
cell. The STOP 1 send is refused when a command has no such entry, or
when an `on main` cell is a placeholder (`-`, TODO, tbd, n/a). For a
read-back (a file, a page, a table): `ran` is the read command, `output`
the lines read, `proves` names what matched what.

## Rules

1. **One entry per run.** A re-run is a new entry; the old one stays.
   `E<n>` is the next number in the file; `record-add.sh` reads it.
2. **Exit code always.** No exit code, no entry. A run killed or timed
   out records `exit killed <how>` and is red.
3. **Output as printed.** The shell filter (rtk) reshapes some runners:
   a bare pytest prints "N passed" on green and no "0 failed"; `make
   test` prints unchanged. Record what the pane shows.
4. **Proves and does not, both.** A test proves the case it names and
   does not prove the deploy; a count on dev does not prove prod.
5. **Pointed at, not repeated.** The STOP report, the DR `evidence`
   line and the close PROVED table carry E ids; they never carry the
   output a second time. The spec carries no E id: it is a public repo
   doc (`foundations/public-docs.md`). The STOP 2 report names the E id
   beside each spec TESTS row.
6. **Header first:** `# <lane> rung <n> · evidence · <IC>`, written
   with the Write tool; every entry after it through `record-add.sh`.

## Red flags, stop and fix

- An output line retyped from memory, rounded, or summarised ("all
  green").
- An entry with no `exit` line, or with "ok" as the exit.
- A gate result written here by hand instead of through `gate-run.sh`.
- A STOP report row with a tick and no E id beside it.
- An entry edited after a later run changed the answer.
- An entry added with Edit or Write instead of `record-add.sh`.
- A `does not` line reading "n/a".

| Excuse | Reality |
|---|---|
| "The output is long, I summarised" | The tail is 1 to 10 lines. The summary is where one rung's false claims lived. |
| "I'll record the runs at the STOP" | Four runs later the exit codes are a memory. Write it when the pane prints it. |
| "The gate passed, the receipt is enough" | Then the entry is one line pointing at it. The E id is what the report cites. |

## Example

`templates/evidence.md` carries the invented lane atlas / ATL-42 rung 1
with a main run of a gate line before STOP 1, a probe, a test run, a
gate run through its receipt, and a read-back. Copy the shape, replace
every value.
