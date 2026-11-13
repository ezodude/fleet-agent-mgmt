---
name: holding-rollups
description: Use when lead-1 (AgentMgmt fleet Lead) has a grill or any owner-led exchange open and an IC message, STOP report or idle notice arrives before it closes. Lead-only.
---

# Holding rollups

## Overview

While the owner is thinking with you, nothing from the fleet reaches them unless
waiting would cost something irreversible. Everything else is held, checked
in the background, and delivered as one recap when the grill closes.

**Core principle:** the grill owns the owner's attention until its diagram is
confirmed. An IC's news is never urgent because it is new.

The owner settled it as "hold rollups, blockers interrupt", with the
rider "no interruption mid-grill is good but I can have a quick look if I
need to". Gloria Mark: one interruption
that needs thought costs the thread, not the seconds.

**REQUIRED BACKGROUND:** `reporting-a-rung` for the rows, the card and the
check; `foundations/decision-card.md`.

Glyphs, same as `reporting-a-rung`: ✖ a gate failed, ? waiting on the owner,
● working, ○ down or not started, ✔ done and proven. Ids: `<lane> Dn` a
decision, `<lane> Wn` a word request (the owner's go or hold on one step).

"The check" everywhere below: the read-only haiku subagent described in
`$FLEET_REPO/shared/skills/reporting-a-rung/templates/check-prompt.md`.
Dispatch: fill its four slots, call the Agent tool with model haiku; it
runs in the background and notifies on return. It compares a STOP report
to its evidence file and gate block and returns a fixed block.

## When a grill is open

From the map message of a `grilling` round until the owner confirms the closing
diagram. Also from any message where the owner says not to interrupt, until they
says otherwise.

## The held list

Lives in `$FLEET_HOME/Leads/lead-1/LEDGER.md` under a
`## held` heading, one row per arrival, `templates/held-list.md`. It is
emptied by the close recap.

## On every arrival while open

0. After compaction: read `## held` in the ledger and rebuild the held
   line from it before anything else.
1. Append it to the held list: time, IC, lane, kind, glyph, clock if any.
2. If it is a STOP report, dispatch the check now, in the background. The
   close recap is written from check blocks, never from the reports.
3. Test it against the interrupt conditions. Most arrivals meet none.
4. Assemble the next grill message in this order, `templates/grill-message.md`:
   a. the held line, always first while anything is held
   b. the interrupt card, only if step 3 said interrupt, two lines
   c. a rule line `---`: above it the fleet, in decision-card shape;
      below it the grill
   d. The owner's last answer acknowledged, the map delta
   e. the grill question, its number unchanged. With the fleet console
      mod loaded and reply words on it, the question is a card:
      `$FLEET_REPO/shared/ledger/card-add.sh new` with
      row=lead-1 where=lead-1, the body per `foundations/decision-card.md`,
      and this slot carries only the pointer line the script prints. On
      the answer, `card-add.sh answer`. Without the mod, the question
      inline, in the `grilling` skill's own format, untouched
5. Never send the interrupt as its own message.

## Interrupt conditions

```
  GLYPH  ARRIVAL                                                   CLOCK THAT DECIDES       VERDICT
  ?      an IC needs the owner's word for an irreversible step         window < grill's end    interrupt
  ○      an IC is down or wedged and owed work today               today                   interrupt
  ✖ ? ●  a fact that changes the open question or a settled one    now                     interrupt
  ✖      a gate failed, the IC holds, no window named              none                    hold
  ?      an idle notice for an ask already with the owner                none                    hold
  ● ✔    a green STOP, progress, or options with no deadline       none                    hold
  any    a fact that changes a later, unasked question             that question's turn    hold, map delta
  ●      a UAT entry in an IC's decision record                    none                    never relayed: the owner wrote it
```

A UAT entry is the owner's own words typed in the IC's pane and acted on.
It is counted at lead-1's audit after the push and
in the close; it is never news to the owner and never a card.

Grill's end: questions left times the pace so far; three questions at
fourteen minutes each is 42 minutes. No fourth interrupt condition. "It
only takes a line" is not one.

## The quick look

When the owner says "fleet", or asks anything about an IC while a grill is open:
reply with `templates/quick-look.md`, the `reporting-a-rung` rows only, red
first, then one resume line. No cards, no bodies, no paths.

## At close

The owner confirms the diagram. The next message is the recap in
`$FLEET_REPO/shared/skills/reporting-a-rung/templates/recap-box.md`:
held line first, rows, verdict, one card. A check not yet returned makes
its row read "check dispatched 14:45, not returned", never a guess from
the report. Then clear the held list.

## Red flags, stop and fix

- The interrupt is its own message, or "Q4 follows in my next message".
- A "parked" list with a line per item, or an evidence path per item.
- A quick look delivered without the owner asking.
- A red gate interrupting because it is red. Red without a clock holds.
- A grill question that uses a held item's facts. Using it relays it.
- The held line missing from a grill message while something is held.
- A UAT entry relayed, summarised or re-asked.
- A grill question body pasted in the main window while the fleet
  console mod is loaded. The body is the card in the fleet pane; the
  main window carries its pointer line.

| Excuse | Reality |
|---|---|
| "He would want to know about the red gate now" | The IC is holding. Ten more minutes cost nothing; the broken thread costs the handoff. |
| "A path costs nothing, they can ignore it" | A path is a hop they have to decide not to take. That decision is the interruption. |
| "The interrupt needs context, so it needs a message" | Two lines: what, by when, reply word. Context is in the card at close. |
| "Three parked items in a table is tidy" | Tidy is still reading. The held line is the table. |
