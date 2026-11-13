# Grove, High Output Management, monitoring and leverage, distilled

Andrew Grove, High Output Management, 1983. Notes:
https://www.nateliason.com/notes/high-output-management-andy-grove
One page. This is what the fleet uses.

## Leverage

A manager's output is the output of the organisation under them. Leverage
is highest when one thing written once is read by many, and when the manager
reads only the exception. Write the gate once, copy it everywhere, read the
red line.

## Delegation is not abdication

The deliverable stays the manager's responsibility. What is delegated is
the work, never the check.

## Task-relevant maturity

How closely to monitor is set by the person's record on this task, not by
general trust. Low record: tell what, when and how, check early. High
record: set the objective, monitor by exception.

An IC session has no memory between rungs. The record lives with the Lead,
in the ledger, and is summed into the recap's gates token. A new ticket for
an IC name starts from that token, not from zero and not from trust.

## Monitoring by exception

```
  recap line     gates 5/5   green   not read further
  recap line     gates 4/5   red     open that IC's STOP report, and only that one
```

Attention goes where the check failed. Everything green is not read.

## Applied here

```
  Grove                       fleet
  write once, read by many    gate-block.md copied into DoD, handoff §0, STOP report, recap
  monitor by record           the gates token sets the check-in interval in the next handoff
  monitor by exception        the recap box; red opens one report, green opens none
  delegation is not           on failure: do not tick, report; at most 2 re-runs inside
  abdication                  the worktree. The IC never decides what counts as passed
```

Related: Gloria Mark, UC Irvine, on interruption cost, is the basis for
holding rollups while a grill is open. Larson, An Elegant Puzzle, on cutting
work in progress, is the basis for one review lane at a time.
