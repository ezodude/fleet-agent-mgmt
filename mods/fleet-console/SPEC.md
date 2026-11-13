# fleet-console v0 · spec

A read-only pane in lead-1's Claude Code session. It answers one question:
what is every stream doing, and what does it need from the owner? It sends
no words. The board it builds is `V0.dc.html` on the mock-up canvas
(https://claude.ai/artifact/M1pRmkm8vohLHMRBCwQLeX, version 6).

## What it does

```
  /fleet          a command (immediate: works while lead-1 is busy) opens pane id "fleet" with focus, no card open,
                  asking for the widest dock the engine allows: min(45% of the terminal, terminal - 60) columns
                  (a width the owner dragged the dock to wins). The pane's title is "fleet", drawn only as a
                  tab while two panes are open
  board order     head row, keys line (see "Keys"), counts, rows, then the open card
  head row        "FLEET · read-only · /fleet opens it" on the left; "<HH:MM> · refreshed <n>s ago" on the right:
                  the age of the last refresh that worked, counting up each second ("1m ago", "1h05 ago" past a
                  minute), so a refresh that fails or stops shows as a growing age
  counts          "<n> IC (<b> busy) · <w> wait on you, oldest <age> (<IC name>) · <k> workflow(s) running"
                  ("1 workflow running"); w counts the rows with an open decision card (see "Decision cards") and
                  the "awaiting:" lines that open with "owner:" (see "Awaiting"), nothing else; the oldest is the
                  oldest open card's "since:", else "updated:"; "<w> wait on you" is amber only while w is above 0.
                  w counts ICs only: when lead-1's own row waits too, it is named, never counted as an IC
                  ("3 IC and lead-1 wait on you", "lead-1 waits on you" when no IC waits). While any card file is
                  shown and the whole line is wider than the pane, the ", oldest …" part is left out
  no rows         a dim line "no IC sessions with a STATE.md, and no lead-1 workflow today"
  rows a, b, …    one per IC: a session file in ~/.claude/sessions/*.json with that name AND
                  ~/.fleet-agent-mgmt/checks/<name>/STATE.md, in name order; then one per lead-1 workflow started today;
                  then lead-1's own row, last, only while lead-1 has an open decision card for row lead-1, so no
                  other row's letter moves when it comes or goes
  IC row          <glyph> <letter>: <name> · rung line · busy|idle (session file status); the glyph says whether
                  the rung is finished (see "Done"): green "✔" done, blue "●" not done, amber "?" unknown
                  (workflow rows have none); then one line. With an open decision card for the row:
                    amber "waiting on you: <ids, newest first> · <age of the oldest card's since> · <n> card(s)"
                  Otherwise from the STATE.md "awaiting:" line (see "Awaiting"), with the age since "updated:":
                    owner: <text>      amber "waiting on you: <text> · <age>"
                    lead-1: <text>     "waiting on lead-1: <text> · <age>" (a session name: "waiting on <name>")
                    none, or no line   dim "last: <updated> · next: <the "next:" line>"
                    any other line     "awaiting: <the line as written> · <age>", never amber
                  a STATE.md that cannot be read: rung "-" and a dim "STATE.md unreadable: <reason>"; the other
                  rows draw as usual
  row cuts        each row line is one line, cut at the pane's edge with "…": the rung, the awaiting text,
                  the next text or a workflow's name gives way; the name, the status and the age stay whole.
                  The second line sits 3 columns in, under the name. While a card is open every row is one
                  line with no blank line between rows, so the card starts high in the pane
  workflow row    <letter>: workflow <name> · <r> of <n> agents returned (journal.jsonl) · started <time>
  lead-1 row      <letter>: lead-1 · lead session · busy|idle, a blank where an IC row has its glyph, then the
                  amber "waiting on you: …" line of its open cards. Its letter lines up with the IC rows' letters,
                  2 columns right of a workflow row's letter (workflow rows have no glyph); left as it is, since
                  moving the workflow rows would change the board drawn with no card file (K7)
  letter key      shows that row's card under the list (see "Keys") and moves the board the least that shows the
                  card (its top when the engine refuses). An IC's card: a title (<letter> · <name>, then
                  "· waiting on you" for "owner:", "· waiting on lead-1" or "· waiting on <name>"; nothing else adds
                  to it), the done line (see "Done"), STATE.md "updated:" with its age, then in this order "stop:",
                  "next:", the newest file in ~/.fleet-agent-mgmt/checks/<name>/ other than STATE.md (path only,
                  listed never read; "-" when there is none) and "awaiting:" last, the one that can run long; each
                  in full under its own label, cut into rows at "; ", ". " and " / " outside () and "", a word
                  longer than its row broken after a "/". With an open decision card for the row, the card shows
                  each open decision card first, newest first (see "Decision cards"), then a rule, then the
                  STATE.md card above with no close key of its own; with none open, the STATE.md card is drawn
                  exactly as before, ending with one dim line "last answered: <id> · <answer>" when the row has an
                  answered card
  Esc             focus back to the prompt; the board and its card stay (see "Keys")
  refresh         $.clock.every(5000): stat first, read a file only when its mtime changed. It runs only while the
                  board is open: closing it stops the refresh and the 1 s tick, /fleet starts them again, and a
                  session that starts with the board still up (the mod reloaded) starts them at once
  lead-1          workflows are lead-1's, found from the session file whose name is "lead-1",
                  never from the session the mod runs in (so a throwaway session shows the same rows)
```

## Decision cards

lead-1 writes every decision card it sends the owner to a file, with
`shared/ledger/card-add.sh` (one file per card; see that script's header), at
`~/.fleet-agent-mgmt/checks/lead-1/cards/<slug>.md`, the slug being the id
with each space as "-":

```
id: ATL-42 D6
row: atlas-ic-1                      the board row: an IC's name, or lead-1
status: open                         open | answered
since: 2026-10-21 15:46 BST
where: atlas-ic-1                    the pane the owner types the reply in
reply: ATL-42 D6 a | ATL-42 D6 back: <line>
answer: -                            or "<the owner's words> · <HH:MM>" once answered
---
<the card's body exactly as sent>
```

The board lists that folder and reads each `*.md` whose name does not
start with "." (read when its mtime moves, never written). A file with no
`---` line, a key missing, a status other than open or answered, a row that
is not a plain name, or an empty body is not a card: it is left out. A card
whose row is not on the board is not shown. Answered cards never show on a
row.

A decision card in the card, in the shape the owner approved:

```
  b · last card · ATL-42 D6 · waiting on you since 15:46        0: close card

  about     atlas · ATL-42 D6, ship the retry with a limit of three or wait
            for the vendor · lead-1 · decision 1 of 1, answering "…"

  problem   the vendor has not said how many calls a minute it allows, …

  state     STOP 2 is ready for push; nothing is pushed yet.

  options   a) ship with a limit of three tries, and ask the vendor for its
               limit at the same time
               the import may still be blocked on a bad night
            b) hold the push until the vendor answers
               no date for that answer

  rec       a, because three tries is already fewer calls than today's
            import makes.

  you type, in atlas-ic-1's pane   ATL-42 D6 a
                                   ATL-42 D6 back: <line>
```

- The title: the row's letter, "last card" ("card 1 of 2" when there are
  several), the id, and "waiting on you since" the card's time ("HH:MM"
  today, "YYYY-MM-DD HH:MM" before). When that does not fit on one line
  beside the close key, "waiting on you since …" goes on its own line under
  the rest, so the title never breaks inside a phrase.
- The body is cut into labelled parts at its blank lines, each label one
  word: the first paragraph with no label is "about" (the frame line: what
  the card is about, less a leading "?" glyph, which every open card would
  carry; a "✖" or "✔" is kept), "The problem:" is "problem", "Status:" is
  "state", "Recommendation:" is "rec", any other "<Label>:" or "**label**"
  (the decision-card skill's fields) keeps its label in lower case, a
  paragraph with no label that opens with "a) " is "options", and any other
  paragraph with no label of its own sits in the text column under an empty
  label. "**label**" opens a part on any line; "<Label>:" and "Reply" only
  at the start of a paragraph, so a line inside a paragraph that starts with
  such a word stays where it is. Inside a ``` fence nothing opens a part
  and a blank line is kept. The "**" bold marks are dropped; every other
  character is kept as written.
- Labels in one column for the whole row, as wide as the longest label on
  any of its open cards and 3 more, so the cards of a row line up; the text
  wraps in its own column, a line keeping how far it sat in from its part's
  first line. An option line ("a) …") hangs its wrapped lines 3 in, under
  its text, not under its letter.
- The reply part (a paragraph opening "Reply " or a "**reply**" field) is
  left out, and the card ends "you type, in <where>'s pane" with each
  alternative of `reply:` on its own line, beside it when every card of the
  row fits that way, else 2 columns in under it on every card of the row.

STATE.md comes in two shapes: a fenced ```state block and bare `key: value`
lines (the test fixtures carry both, atlas-ic-1 and atlas-ic-2).
Read `key: value` lines at the start of a line, in or out of a fence; when a
key repeats, take the last one. A missing key shows `-`. Text is shown as
written, never reworded.

## Awaiting

An IC's "awaiting:" line opens with `none`, `owner:`, `lead-1:` or `<name>:`
(a session name in ~/.claude/sessions, with a row on the board or not), free
text after. Only `owner:` waits on you. The lines written before this rule
are free text: "none", "nothing", "-" or an empty line reads as idle; any
other line is shown as written, never as waiting on you and never in the
wait count. Until the STATE.md files use the rule, the counts say "0 wait on
you".

## Done

Whether an IC's rung is finished comes only from its record folder. Take
the first word of the STATE.md "handoff:" line as a path ("~/…" or
an absolute path). If its folder is
`<home>/.fleet-agent-mgmt/records/<project>/<folder>/`, list that folder
(listed, never read):

```
  close.md listed            DONE       ✔  green   "✔ DONE · <folder> closed <YYYY-MM-DD HH:MM> · close report in the record"
  folder listed, no close.md NOT DONE   ●  blue    "● NOT DONE · <folder> open · no close report yet"
  folder cannot be listed    UNKNOWN    ?  amber   "? UNKNOWN · this rung predates record folders, so there's no close report"
```

Anything else ("handoff:" under lead-1's handoffs, a URL, ".", no line) is
UNKNOWN. The closed time is close.md's modified time from the listing; when
the listing gives none (a link), the line says "closed" with no time. The
card line sits under the title, one line, cut with "…" when the card is
narrow.

## Never

- type into a pane or the prompt: no `send-keys`, `paste-buffer`, `$.prompt.fill`, `$.prompt.submit`
- message a session: no `$.session.send`
- draw a status line or the band: no `$.ui.status`, no `AbovePrompt` (the owner's own status bar stays as it is)
- read a session transcript: the only `.jsonl` read is `subagents/workflows/*/journal.jsonl`; the other
  files read are session files, STATE.md files and `checks/lead-1/cards/*.md`
- write a file: no `$.fs` write; `$.store` only if a test needs it
- run any process (no `$.process.run`)

## Not in v0

Tabs per IC, buttons that draft words, the asks band, word checks, the
workflow step pager, transcript restyles. Each waits on use of v0 (owner
rulings fleet-console R1, Q2, Q3 stay open).

Board parts v0 leaves out: the background-checks row; a workflow row's
purpose and result line; the "tracks" label; and going to an IC's pane (dropped: each IC
is its own tmux session and terminal, so a switch would move the owner's
terminal into it).

## Checks

| id | command | pass |
|----|---------|------|
| K1 | `claude plugin validate $FLEET_REPO/mods/fleet-console` | exit 0 |
| K2 | `claude plugin test $FLEET_REPO/mods/fleet-console` | exit 0, " 0 fail" |
| K3 | `grep -rnE 'send-keys\|paste-buffer\|prompt\.(fill\|submit)\|session\.send\|ui\.status\|AbovePrompt\|switch-client\|process\.run' $FLEET_REPO/mods/fleet-console/hooks` | exit 1, no output |
| K4 | K2's fixture test: the five invented STATE.md fixtures give rows a–e with the expected rung, status and "awaiting:" text, none of them waiting on you | in K2 |
| K5 | K2's key test: pressing atlas-ic-1's letter (`b` in the fixtures) shows its card, then the other letters switch it; no process runs | in K2 |
| K7 | K2's render regression: with no card file, the board at 180, 120, 81 and 54 columns, with no card open and with each letter's card open, is drawn byte for byte as `test/fixtures/invented/baseline/` (28 snapshots drawn by the code as it was before decision cards existed, from the same invented fixtures) | in K2 |
| K8 | `shared/tests/test-card-add.sh` | exit 0, "<n> pass, 0 fail" |
| K6 | a critic reads `V0.dc.html` and the pane test render: every element on the board is present or named in "Not in v0" | critic says yes |

Done for v0: K1–K6 pass, then the owner opens it in a throwaway session in
a plain new Terminal window ("How to try it", step 1:
`claude --plugin-dir $FLEET_REPO/mods/fleet-console`)
and types "fleet-console v0 ok". Only then is it loaded into lead-1.

## Keys

```
  a, b, …         every letter drawn on the board is a key, IC and workflow rows alike (a–z, g included).
                  The card follows its row by who it is (the IC's name, the workflow's run id), never by the
                  letter: a reorder never swaps it to another IC, and the card goes when its row leaves.
                  IC rows are in name order, so an IC keeps its letter when it restarts under a new pid.
  workflow card   read-only: "<letter> · workflow <name>", then agents (<r> of <n> returned), started,
                  status (running or done <time>), run id and the journal path
  0               closes the card; a "0: close card" key is drawn in the card's title row only while a card is open
  Esc             hands the keys back to the prompt; the board and its card stay (the pane does not ask
                  Esc to close it)
  ctrl+x x        the engine's own close (or the pane's close mark): closes the board, stops the refresh
                  and clears the card. The engine binds ctrl+x x only while the board holds the keys; while
                  they are at the prompt, ctrl+x tab (or a click on the board) comes first
  legend          while the board holds the keys: "<range> open a card · 0 closes the card (only while a
                  card is open) · Esc back to your prompt · other keys go to your prompt · ctrl+x x closes
                  the board" ("<range> open a card" left out while the board has no rows). While it does not (after Esc, a click elsewhere, a key no row answers, or
                  /fleet over a prompt with text), in amber: "your keys are at the prompt: click the board
                  or press ctrl+x tab to use the letters here · ctrl+x tab, then ctrl+x x closes the board"
  ↑ ↓             the engine scrolls the board with them only when it is longer than the pane; on a board
                  that fits, they go to the prompt and the board loses the keys. A mod cannot take arrow
                  keys (a hotkey is one letter or digit), so the legend does not name them
```

## How to try it (the owner, after K1–K6)

Nothing below touches lead-1 or an IC: the mod loads only in the session
started with `--plugin-dir`, and it reads files and runs no process. The
last column names the K2 tests that check the same thing, or says "real
terminal only" where only a real terminal can show it.

| # | do | expect | shown by |
|---|----|--------|----------|
| 1 | in Terminal, press Cmd+N for a plain new window and drag it to the full screen width; run `tput cols` and write the number down, then run `claude --plugin-dir $FLEET_REPO/mods/fleet-console` | a fresh Claude Code session filling that window; lead-1's window is untouched | real terminal only |
| 2 | `/plugin` | a dim line `1 mod active · fleet-console` | real terminal only |
| 3 | `/fleet` | with the width from step 1 at 110 columns or more, the board docks on the right, beside the transcript; narrower, it opens above the prompt. It asks for min(45% of the terminal, terminal − 60) columns, 90 at 200. If it opens above the prompt on a wide window, write down whether `CLAUDE_CODE_NO_FLICKER` is set: that layout places a pane above the prompt at any width | `O3: the dock is asked` (the width asked, not the width granted); the placement is real terminal only |
| 4 | read the first rows, then the rows | first "FLEET · read-only · /fleet opens it" with "<HH:MM> · refreshed <n>s ago" on its right, then the keys line, then the counts; one row per live IC and per lead-1 workflow today. Each IC row opens with ✔ (done, green), ● (not done, blue) or ? (unknown, amber), as "Done" says; workflow rows have none. Only an IC whose "awaiting:" line opens with `owner:` reads "waiting on you" (amber, counted); `lead-1:` or an IC's name reads "waiting on lead-1" or "waiting on <name>". Today's STATE.md files are all in the old free-text form, so every second line starts "awaiting:" (or "last:" for "none"), and the counts say "0 wait on you" | `K4 pane`, `O4`, `C2 old form`, `C2 pane`, `N9`, `C3 pane` |
| 5 | press one IC's letter (rows are in name order) | that IC's card: the done line ("✔ DONE · <record folder> closed …" when its rung is closed), updated, then stop, next, newest file, awaiting, each under its label with wrapped rows indented, as in `~/.fleet-agent-mgmt/checks/<name>/STATE.md` | `K5`, `card shape`, `C3 card` |
| 6 | press each letter on the board in turn, workflow rows included (for example `b`, `f`, `c`, `a`) | the card follows each letter; a workflow's letter shows its read-only card; no letter lands in the prompt, which stays empty | `O2` (each letter is a key; the tests press by key, so the empty prompt is real terminal only) |
| 7 | press Esc, type a prompt | keys go to the prompt; the pane and its card stay; the legend turns amber and says the keys are at the prompt | `N3a` (the words); Esc itself is real terminal only |
| 8 | look under the prompt | your own status bar, unchanged | K3 (the mod never draws a status line); the look is real terminal only |
| 9 | send a long prompt, then type `/fleet` while it runs | the pane responds while the session is busy | real terminal only |
| 10 | wait 10 s after an IC updates its STATE.md | its row changes; "refreshed <n>s ago" counts up each second and goes back to 0s at each refresh | `refresh: every 5 s`, `N3: "refreshed"` |
| 11 | with a card open, press `0` | the card closes, the board stays, the prompt stays empty, and "0 closes the card" leaves the legend | `O1: 0 closes the card` (the tests press by key, so the empty prompt is real terminal only) |
| 12 | open a card, close the board with ctrl+x x (or its close mark), then `/fleet` | the board opens with no card | `O1: 0 closes the card` (/fleet opens no card), `N7`; the close itself is real terminal only (the kit cannot raise the close event) |
| 13 | press Esc, then ctrl+x tab (or click the board); then press a letter | the amber line goes, the letters legend is back, and the letter opens its card. Also: type text in the prompt, then `/fleet`: the board opens without the keys and says so in amber | `N3a` (the words); the keys are real terminal only |
| 14 | open a card, press Esc (the legend turns amber), then press ctrl+x x | write down what happens. Expected: the board and its card stay, because the engine binds ctrl+x x only while the board holds the keys; the amber line says "ctrl+x tab, then ctrl+x x closes the board". Then press ctrl+x tab and ctrl+x x: the board closes, and `/fleet` opens it with no card | `N3a` (the words only); what the keys do is real terminal only |
| 15 | with no card open and the whole board on screen, press ↑ | write down what happens. Expected today: ↑ goes to the prompt (an old prompt comes back) and the board loses the keys, because the engine scrolls with the arrows only when the board is longer than the pane; the mod cannot take arrow keys. The legend then turns amber | real terminal only |
| 16 | with the board docked from step 3, read every row | write down the width from step 1 and what you see. Expected: no row wraps; a row too long for the pane ends in "…" with its status or age still whole, and its card has the text in full. The board asks for the widest dock the engine allows, 45% of the terminal with 60 columns left for the transcript (90 at 200 columns, which is also the width the engine opens it at; the ask gains columns only above 200). A smaller font (Cmd −) or dragging the dock's edge widens it up to that cap, and a width you dragged before wins over the board's ask | `O3` (the cut at a given pane width); the width on a real terminal is real terminal only |
| 17 | make the window short (or the font large) so the board is taller than the pane; scroll the board up to its top, then press the letter of the IC with the longest card; then press `0`, scroll to the bottom and press another letter | write down what happens each time. Expected: the board moves the least that shows the card, so the card's top row (its letter, name and "close card") is on screen at once, at the bottom of the pane when the whole card fits, at its top when the card is taller than the pane; scroll for the rest. If the engine refuses that, the board goes back to its top instead (the FLEET row, the keys line, one line per row, then the start of the card) | `N6` (one line per row with a card open); the scroll is real terminal only (the kit answers the board's scroll with "no implementation", so no test sees the press ask for it) |
| 18 | with the board open, save any file of the mod unchanged (it reloads when the turn ends), then watch "refreshed" for 15 s | write down what happens. Expected: "refreshed" goes on counting up and back to 0s every 5 s, so the refresh came back after the reload | `N3: after a reload`, `N3: a session that starts` (the start hook with the board listed); a real reload is real terminal only |
| 19 | `/exit`, then close the window | nothing left running; lead-1 untouched | `N7` (closing the board stops the timers); the exit is real terminal only |

Decision cards (after the owner's word that lead-1 writes card files).
lead-1 writes a test card with the real script; it is its own write path
into `~/.fleet-agent-mgmt/checks/lead-1/cards/`, and the board only reads it.

| # | do | expect | shown by |
|---|----|--------|----------|
| 20 | in lead-1: `printf 'fleet · try D1 · lead-1\n\nThe problem: a test card.\n' \| shared/ledger/card-add.sh new "try D1" row=lead-1 where=lead-1 reply="try D1 ok"` | it prints "try D1 · card in fleet pane, row lead-1 · reply try D1 ok"; within 5 s the board gains a last row "lead-1 · lead session" with an amber "waiting on you: try D1 · 0m · 1 card", and the counts say "lead-1 waits on you" (lead-1 is named, never counted as an IC) | `C4 lead-1 row`, `C4 pane`, `C4 header` |
| 21 | press that row's letter | "last card · try D1 · waiting on you since <HH:MM>", then "about" and "problem" in a label column, then "you type, in lead-1's pane   try D1 ok" | `C4 card` |
| 22 | in lead-1: `shared/ledger/card-add.sh answer "try D1" "test over"` | it prints "try D1 · answered · test over · <HH:MM>"; within 5 s the lead-1 row and its card are gone, and the counts are as before step 20 | `C4 lead-1 row`, `C4 answered` |

If the pane does not draw: in a `--plugin-dir` session a transcript line
names the refused element (`ui.render (Pane) refused: …`); the mods
troubleshoot page names the debug log. Tell lead-1 the step number and
what you saw.
