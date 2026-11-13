---
name: keeping-the-board
description: Use when the lead session writes or rewrites its board page (checks/lead-1/board.md), and at every event that creates or closes a piece of work: a ticket filed by any path, a brief ok'd, an IC launched, a close report accepted, an IC that cannot move, the owner's "done" on a task with no IC. Lead-only.
---

# Keeping the board

The owner reads the board, not the lead's pane. The board is a viewer of one page the lead writes. Whatever the page does not say, the owner never sees: work that lives only in the lead's memory, the ledger or the ticket tracker has no row, so it does not exist.

## The page

Copy `board-template.md` (next to this file) and keep its six sections in this order. The viewer parses `## <section>` headings and `- ` bullets; a bullet's fields are split by ` · `, the first field is the id, and `say:`, `where:`, `since:` are read as tokens.

```
  section        holds                                               not here                              viewer shows it as
  ## yours       everything waiting on the owner's word               the lead's own chores                 YOURS, by default
  ## next        work that exists but has no IC yet                   anything an IC is already on          NEXT, by default
  ## running     one row per IC                                      closed ICs                            green count; RED when the row carries red:
  ## owed        the lead's own backlog                              anything the owner decides            behind l
  ## done today  the day's acts, newest first                        anything still open                   behind l, grouped per ticket
  ## to read     reports the owner may read                          anything the owner must act on        behind l
```

## Events, one row each, before anything else

Write the row at the moment the event happens, not at the next page refresh.

```
  event                                              row                                   section
  a ticket is filed, by any path (skill, PR follow-up, "file the 2 tickets")
                                                     ABC-123 r1 · <one sentence> · say: launch ABC-123 r1       next
  a brief is ok'd and names a later rung             <idea> r2 · <one sentence> · say: shape <idea> r2          next
  a brief is ok'd and names extra tickets            <idea> tickets · <one sentence> · say: file the <n> tickets   yours
  a close report is accepted with an owed line       <ticket> owed · <the line> · say: launch <ticket> r<n+1>     next
  an IC is launched                                  the next row moves to running
  an IC cannot move, or the lead flags it            the running row gains · red: <why>
  the owner says "done" on a task with no IC         done today row; its next or running row goes
  anything that needs the owner's word               yours, with say: and where:
```

A next row leaves the page only when a running row for it appears, or the owner says it is dropped. A yours row leaves when the owner's word is on record.

## Rules

- `say:` is one word the owner types as written, the recommended one when there is a choice; the choice itself goes in the sentence. `where:` is the pane or chat it goes to.
- One row per item. A ticket with three loose ends is one row whose sentence names three.
- An empty section keeps its heading and has no bullet.
- A row exists only on the page. A ledger entry, a ticket in the tracker or a line in chat is not a row.
- When the page's sections differ from the template, the next write starts from the template.

## Check before each write

```
  every ticket filed today has a next or running row               yes / no
  every brief ok'd today: its later rungs and extra tickets have rows   yes / no
  every close accepted today: its owed lines have rows             yes / no
  every row in yours has say: and where:                          yes / no
```

One "no" means the page is not ready to write.
