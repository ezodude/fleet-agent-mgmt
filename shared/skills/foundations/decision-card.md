# The decision card

One shape for every decision put to the owner, wherever it appears: a Lead
message, a spec's open items, an analysis, an ADR, a grill question. The
card is measured by reading cost per decision, not by line count: a spaced
card reads cheaper than a crammed one half its length (the owner: "I
didn't mind the detail - its very useful in this context ... same content
but laid out with more space btw sections"). Depth is one scroll below,
never a file away; the owner again: "I need more depth of valuable
decisions based on my retro. However, I don't want more dense info."

## The card

```
✖ **<LANE-ID>** · <project> · <IC> · <the question, in words> · <the date that makes it urgent>

**problem**     <what goes wrong, for whom, in plain words; one concrete example>
            <no id, file:line, sha or diagram in this field>

**stakes**      <what this touches: demo date, regulated control, money, client answer>

**happened**    check · <IC> · <lane> · <STOP or decision> · received <time>
            <actual output against the pass line, or the fact that raised it>
            <what the IC did and what it was told>

**options**     a) <option>
               <consequence>
            b) <option>
               <consequence>

**rec**         <letter>, <the reason the recommendation holds>

**unverified**  <what the card rests on that nobody checked>   (omit when empty)

**trace**       <appendix ID: what the reader finds there>      (only when stakes warrant it)

**reply**       "<LANE-ID> b"
```

Glyph in the header: ✖ a failed gate, ? a decision with nothing failed,
✔ decided (ADR, or a ruling being recorded).

## Problem first

Every card, and every answer that raises an issue to the owner, opens
with `problem`: what goes wrong, for whom, in words a reader with no code
open understands, and one concrete example. Diagrams, file:line, ids,
options and the recommendation come after it. A card that opens with a
pipeline diagram or a line of code makes the owner work out what the risk
is before they can weigh it; the owner asked twice for the problem first,
simply, always. The `grilling` question's `The problem:` line is the same
field.

## What reaches the owner as a card

A card is for a decision only the owner can make:

```
  THE OWNER RULES ON                              THE LEAD DECIDES, NO CARD
  the goal, and what done proves                  where a step runs (environment, page, publish)
  a constraint the owner holds                    which file or copy an IC reads; paths and ids
  a one-way act's word                            the order of steps; how two rungs share a resource
  a trade-off touching a client, money,           the wording of a question the IC drafts anyway
    a regulated control or a demo date            a default with no stake beyond the rung
```

The test, before any card goes out: would the owner's answer differ from
the recommendation for a reason only the owner holds? If not, it is the
lead's call. Decide it, record it as `lead's call` with its reason (in
the brief's brackets, the ledger, or the report), and show it once in the
next brief delta or report, so the owner can overrule it with one line.
A card on mechanics costs the owner a round trip for an answer that was
already the recommendation; the owner stopped one grill with "why am I
making this decision ... stop wasting my time".

## Layout rules

The eight caps. Each one is a reading cost the owner pays; none is a line
count. Checkable by eye on the card.

```
  CAP                                            WHY
  1  one fact per line                           a line with two facts is read twice
  2  a line under 100 characters, indent included  a wrap breaks the column the eye is on
  3  a table is at most 6 rows and 4 columns     beyond that it is a comparison, not a glance
  4  at most 5 options, one consequence each,    the reply must be a letter
     the consequence on its own line under the
     option
  5  one reply line, one decision                a card whose reply needs two answers is two cards
  6  nothing the card needs lives elsewhere      a hop to another message or file is a context
     (no "as above", no "see the log")           switch, the dearest cost in the retro
  7  every id expanded once on the card          R2, D14, a dataset name: a cold reader stops
     (rung, decision, gate, dataset)             at each bare one
  8  a blank line between fields, none inside    the eye finds the field before reading it;
     a field; a table or list follows its lead   a blank line before an indented line renders
     line with no blank above                    as a code block, four columns left, blank eaten
```

- Label at column 1 in bold, text at column 13 as rendered. `**stakes**` is
  ten characters raw and six rendered, so the label is padded to twelve
  rendered columns: `**stakes**` plus six spaces, `**happened**` plus four.
  Wrapped text sits at column 13, under the text, never under the label.
  In a file, where nothing renders, a field's first line sits four columns
  right of its continuation lines; in the pane they line up (bold labels
  and the lane id: "it looks great", the owner's words).
- The lane id in the header is bold: `✖ **ATL-61 build D15** · …`. The
  verdict line above a card opens `**Verdict:**`.
- No blank line inside a field. The pane renders markdown: a blank line
  followed by a line indented four or more spaces is a code block, so the
  line loses four columns and the blank line after the block disappears.
  Seen on two live cards: b) sat at column 9 and `rec` lost its blank
  line. Fields start at column 1 and are safe.
- In the fleet pane every line of a card body, fenced diagrams included,
  is at most the column count in `shared/launch/card-width.txt`, stricter than
  cap 2, and every label is at most 10 characters (`unverified`): the
  pane wraps a longer line, and a longer label narrows every card on its
  row. `shared/ledger/card-add.sh` refuses both. A grill's "Recommended:" is
  written "Recommendation:", which the pane draws as `rec`.
- Any table's header row is in CAPS, so a header is never read as a row.
- The recommended option is named in `rec`, not marked in the option list.
- The header carries every identifier a cold reader needs: lane-prefixed
  decision id, project, IC, the question in words, the date. No bare "D1".
- A sub-grill on one lane (after "<lane> brief back", or an owner question
  that opens one) ids its items by capital and number, lane-prefixed
  ("atlas A3"), never a lone option letter, so "J2 a" reads as item
  then option: A1..An for a brief's design questions, J1..Jn for a
  ticket's, in order, never reused; a dropped id stays dropped, so a gap
  reads as a drop, not a miss (atlas A1..A6 and J1..J4, J3 dropped).
- A lane renamed mid-grill keeps its old prefix on ids already sent; new
  cards, the brief and the ticket use the new name from the ruling on,
  with one line naming the old one, so every id a reader quotes still
  finds its card (atlas renamed atlas-ingest at J2 a).
- A reply may be a combination of letters ("a+c"); it is still one reply
  line and one decision. Two questions on a card are two cards.
- reply names the shortest message that unblocks the work, and closes the
  card.
- There is no cap on lines per field or per card. Length is bounded by
  cap 1 (one fact per line) and cap 5 (one decision): a card that keeps
  growing is carrying a second decision or a trace.

## Worked example

The same decision twice. The spaced one carries every fact; the crammed
one is trimmed to what shows its shape. Example values INVENTED (atlas,
ATL-61).

Crammed, as sent (no blank lines, a table inside `happened`, consequences
past column 100, R2 and D14 bare):

```
(crammed, as sent; not the shape, do not copy)
ATL-61 build D15     what to do with the red dbt_build in the e2e job
happened   check · atlas-ic · ATL-61 build · D14 spike · received 18:34, five rows confirmed
           same three tests run as SQL on the SHARED dev schemas and the user sandbox:
             guard_input_import                          dev 1   user 1    (fail if != 0)
             forms_split_parent_children_reconcile       dev 12  user 12
             forms_balance_sheet_balances                dev 4   user 4
           packages/dbt diff vs origin/main is EMPTY; dbt command line byte-identical
stakes     R2/R4 (full simple case) cannot go green on the current pass line; the mart owner has a real defect
options    a) hand the three tests to the mart owner unchanged, e2e keeps the red         0 cost here, R4 stays red
           b) narrow this job's dbt_filter for the e2e run only                          yml change on the branch, needs your word
rec        a now, plus c so the series can close; b is a product change this rung should not make
reply      "ATL-61 build D15 a", "b", "c", or "a+c"
```

Spaced, to the caps (the block the owner asked for):

```
✖ **ATL-61 build D15** · atlas · atlas-ic · what to do with the red dbt_build in the
  e2e job · 2026-09-15

**problem**     the end-to-end import job cannot pass: its dbt step fails on three tests
            that fail the same way on the shared dev data, so the fault is not this rung's code
            e.g. the balance-sheet test fails 4 times in dev and 4 times in the sandbox

**stakes**      R2 and R4, the full simple case, cannot go green on the current pass line
            the mart owner has a real defect

**happened**    check · atlas-ic · ATL-61 build · D14, the spike into the red tests · received 18:34
            five rows confirmed
            the same three tests run as SQL on the shared dev schemas and the user sandbox
              TEST                                        DEV   USER
              guard_input_import                            1      1
              forms_split_parent_children_reconcile        12     12
              forms_balance_sheet_balances                  4      4
            guard_input_import fails if its count is not 0
            packages/dbt diff vs origin/main is empty; the dbt command line is byte-identical
            dbt_build has been green once ever, 2026-08-11, 98 nodes
            skipped as upstream-failed five times since 2026-09-14; today it builds 563 nodes
            clone_schemas copies nothing (CREATE SCHEMA IF NOT EXISTS only)

**options**     a) hand the three tests to the mart owner unchanged, e2e keeps the red
               0 cost here, R4 stays red
            b) narrow this job's dbt_filter for the e2e run only
               yml change on the branch, needs your word
            c) dated DoD line: the import e2e passes with dbt_build red on these 3
               needs your line, nothing else moves

**rec**         a now, plus c so the series can close
            b is a product change this rung should not make

**unverified**  nobody else wrote the shared dev schemas during the read
            ref-to-schema came from information_schema, not dbt compile

**reply**       "ATL-61 build D15 a", "b", "c", or "a+c"
```

## The trace

Depth for the reader who doubts. It lives at the bottom of the SAME
message or file, under the decision id. Never in another file, never "see
the evidence log". Contents, in order: the mechanism trace the charter
demands (cases written out), the rejected options with one line each, the
evidence paths. Under fifteen lines per decision; over that, the decision
is not ready for a card. The card itself carries every fact the decision
turns on (cap 6); the trace carries how they were found.

## Where it is used

```
  grill question             this card, headed "Qn of N", the fields unchanged
  recap body                 reporting-a-rung: one full card per message, a header-only card behind
  spec / analysis open items writing-a-design-spec, writing-an-analysis: one card per open item on the STOP report; the committed file states each as a plain-words question, options and recommendation, with no IC name, lane id or reply line (foundations/public-docs.md)
  ADR                        writing-an-adr: one ✔ card at the top, the body is its trace
  DoD amendment              writing-a-ticket: dated, citing the card id that caused it
```

## The card file

The lead writes every card it sends the owner to a file first, with
`shared/ledger/card-add.sh`; the body on stdin is the card exactly as sent. The
script's header gives the file's place and layout.

```
shared/ledger/card-add.sh new "ATL-42 D6" row=atlas-ic where=atlas-ic reply="ATL-42 D6 a | ATL-42 D6 back: <line>" < card.md
ATL-42 D6 · card in fleet pane, row atlas-ic · reply ATL-42 D6 a | ATL-42 D6 back: <line>
```

- `row` is the board row the card is about (an IC, or the lead itself);
  `where` is the session whose pane the owner types the reply in.
- The id is words of plain letters, digits, ".", "_" and "-", one space
  between words, as the card's header writes it; the script refuses any
  other (a leading, trailing or double space, an accented letter).
- Once the fleet console mod is loaded in the lead's session, the main
  window carries only the pointer line the script prints: the owner reads
  the card in the fleet pane, under that row's letter, so the main window
  holds one line per decision instead of a full card. Until the mod is
  loaded, the card goes in the main window as before, and the file is
  written all the same.
- Once the mod is loaded, a grill question with reply words is one of
  these cards: row and where are the lead's own session, and the grill
  message carries its pointer line in place of the question
  (`holding-rollups` step 4e). Until then the question stays inline, in
  the `grilling` skill's own format, and no card file is written for it.
- On the owner's reply, the lead runs
  `shared/ledger/card-add.sh answer "ATL-42 D6" "<the owner's words, verbatim>"`.
  The card then leaves the row's wait count, so the board never shows a
  decision as waiting after the owner answered it.

## Why

Fournier: delegate the goal and the escalation boundary. The card IS the
boundary, written down. Grove: monitor by exception; the ✖ card is the
exception, and its trace is the check the manager can open.
