# fleet-console

A read-only pane for lead-1's Claude Code session. `/fleet` opens it. It shows one row per IC
(session file plus `~/.fleet-agent-mgmt/checks/<name>/STATE.md`) and one row per lead-1 workflow started today.
lead-1's decision cards (`~/.fleet-agent-mgmt/checks/lead-1/cards/*.md`, written by `shared/ledger/card-add.sh`) make
their row wait on you and show first in its card; lead-1 gets a row of its own only while it has an open card.
The spec is `SPEC.md`.

## Files

| file | what it is |
|---|---|
| `hooks/register.tsx` | the hooks module: `/fleet`, the 5 s refresh and 1 s tick while the board is open, the pane, the letter keys, the `0` key that closes the card |
| `hooks/parse.ts` | pure helpers (STATE.md keys, whom an "awaiting:" line waits on, the record folder and done state, the "…" cut, the dock width, ages, header, a decision card file and its labelled parts), imported by the tests |
| `types/index.d.ts` | the `$.state` contract: `board`, `selected`, `tick` |
| `test/fleet.test.tsx` | K4 and K5, the refresh rule, the header, the awaiting rule, an unreadable STATE.md, the refreshed age, the timers, the keys (close card, workflow card, legend, card by name), the layout (dock width, row cuts, head row, keys line place, counts), decision cards (C4), and K7, the render regression |
| `test/layout.ts` | the board's test-kit tree laid out as text (an approximation, not the engine's paint): the render regression's snapshots |
| `test/fixtures/invented/` | invented fixtures, no live data: five ICs' STATE.md, session files, lead-1 workflow files, lead-1's card files (`cards/`); `records.json` lists the record folders their "handoff:" lines name (file names and times only), `newest.json` and `mtimes.json` give every mtime; `baseline/` holds the 28 render snapshots drawn from these fixtures by the code as it was before decision cards existed |
| `test/fixtures.gen.ts` | the fixtures embedded for the tests; written by `test/make-fixtures.py` |

## Testing it after a change

1. Run the checks. Nothing here touches a pane or a session.

   ```
   claude plugin validate $FLEET_REPO/mods/fleet-console      # K1: exit 0
   claude plugin test $FLEET_REPO/mods/fleet-console          # K2, K4, K5: exit 0, " 0 fail"
   grep -rnE 'send-keys|paste-buffer|prompt\.(fill|submit)|session\.send|ui\.status|AbovePrompt|switch-client|process\.run' \
     $FLEET_REPO/mods/fleet-console/hooks                     # K3: exit 1, no output
   ```

2. If you changed a fixture, run `python3 test/make-fixtures.py` from the mod folder and then run the tests again.
   It reads only `test/fixtures/invented/`, never a live folder. A change that is meant to move the board's
   drawing with no card file present fails K7: delete the snapshots it names from `baseline/`, run the tests
   (each missing one is printed between `@@BEGIN <name>` and `@@END`), and write the new ones from that output.
   The tests have no disk of their own: they serve `fixtures.gen.ts` as the file tree under an invented `HOME` (the user "owner"),
   with the clock set to 2026-10-21 16:55 BST.
3. To try it live, follow "How to try it" in `SPEC.md`, steps 1–19, then 20–22 for decision cards (lead-1 runs
   `shared/ledger/card-add.sh`; the board shows the card). It runs in a throwaway session in a plain new
   Terminal window (Cmd+N), started with `claude --plugin-dir $FLEET_REPO/mods/fleet-console`. Each
   step names the tests that check the same thing, or says "real terminal only". Load it into lead-1 only after the
   owner has typed "fleet-console v0 ok".

## What the tests prove, and what they do not

- **They prove:** the five invented fixtures give rows a–e equal to `expected.json`, in name order; moving an IC to a session
  file with a higher pid keeps every letter, and the open card stays on its IC by name (and goes when that IC leaves
  the board). Pressing atlas-ic-1's letter shows its card, the other letters then switch it, and no process runs. Every
  letter on the board is a Button with that hotkey, the workflow row included, and the workflow's letter opens its
  read-only card. A `0` "close card" key is drawn only while a card is open and closes it; `/fleet` opens the board
  with no card. The legend names `0` only while a card is open and always names ctrl+x x; when the pane does not hold
  the keys it says so, names ctrl+x tab instead of the letters, and says ctrl+x tab comes before ctrl+x x. The
  `ui.close` hook that clears the card is registered with a fallback that hands the close on to the engine if the
  hook fails. The card for atlas-ic-1 (fenced block) and atlas-ic-2 (bare lines) has the labels stop, next, newest file,
  awaiting in that order, each clause on its own row beside a `·` mark, and the clauses and path parts joined back
  give each STATE.md value with no character lost; at 60 columns a long path breaks after a `/`, never mid-word. Each
  IC row opens with ✔ (green), ● (blue) or ? (amber) and its card has the matching line under the title: done when
  close.md is listed in the record folder the "handoff:" line names (a `~` path or an absolute path), not done when
  that folder has no close.md, unknown for a handoff elsewhere, a URL, a folder that cannot be listed or a path that
  climbs out with `..`; a close.md with no time in the listing shows no time; the card line is cut with "…" at 54 and
  60 columns, never wrapped; a close.md that appears turns the row done on the next refresh. The
  mod reads only session files, STATE.md files and workflow `journal.jsonl` files; record folders are listed, never
  read. A session name or lead-1 id
  holding `/`, `..` or a leading dot is skipped, never listed or read. A `journal.jsonl` that is a link is never
  read. On a 5 s tick it reads a file again only when that file's mtime has moved, a read that failed included.
  `/fleet` typed in a 200-column terminal asks for a 90-column dock (min(45%, width − 60)); with no width given it
  asks for none. STATE.md's rung and awaiting are kept in full; at 86 body columns every row line fits the pane (the
  "waiting on you", "awaiting:" and "last:" lines included), a long one ending in "…" with its status or age whole,
  and at 400 columns nothing is cut. A workflow row keeps its state ("running", "done <time>") whole: its name gives
  way first, then, at 60 columns, its counts too, so every row line still fits. The second line sits in a 3-column
  indent, never in leading spaces. The first row is "FLEET · read-only · /fleet opens it" with the time on its right,
  then the keys line, then the counts; with a card open every row is one line. The counts say "1 workflow running",
  draw "0 wait on you" plain and a count above 0 amber, and a board with no rows says so and names no card to open.
  Whom an IC waits on comes from its "awaiting:" line: `owner:` reads "waiting on you" (amber, counted, its card
  titled so, the oldest named by the IC), `lead-1:` or a session name reads "waiting on <who>", `none` draws the
  "last:" line; the fixture lines, all in the old free-text form, read as "awaiting: <text>" and count 0, and
  "none", "nothing" and "-" in that form are idle. One STATE.md that cannot be read shows its row as "STATE.md
  unreadable: <reason>" with every other row drawn, and its row comes back when the file is written again. "refreshed
  <n>s ago" counts up each second, keeps growing while refreshes fail (the problem shown), reads "1m ago" past a
  minute and goes back to 0s when a refresh works. Closing the board stops every timer the mod started and /fleet
  starts them again (tested by calling the mod's hooks with a stand-in `$`, since the kit cannot raise the close); a
  session that starts with the board listed refreshes at once and every 5 s. The card's newest file is never STATE.md
  (`stop-2.md` for atlas-ic-1, "-" for an IC with only STATE.md), and it is listed, never read; a name starting "."
  beside STATE.md is never the newest file. With no card file, the board at 180, 120, 81 and 54 columns, with no card
  open and with each letter's card open, is drawn byte for byte as the 28 baseline snapshots (as text, from the
  kit's tree). A card file gives its header and body; a file with no `---`, a key missing, another status, a row that
  is a path or an empty body is left out with no crash; an id may hold spaces. An open card makes its row read "waiting
  on you: <ids> · <age of the oldest> · <n> card(s)" in amber, counted, with every letter unmoved; its letter shows
  the decision card first (title, then about, problem, state, options, rec and the other parts under their labels,
  the reply paragraph left out, then "you type, in <where>'s pane" and the alternatives), a rule, then the STATE.md
  card line for line as with no card file, with one close key. "Reply" or "<Label>:" inside a paragraph stays in it,
  and a ``` fence keeps its lines and blank lines with no label inside. An option's wrapped lines hang under its
  text; at 54 columns "waiting on you since …" moves to its own line rather than break; the cards of one row share
  one label column and one place for the reply. Two open cards on a row show in full, newest first, a rule between
  them. lead-1's row is drawn last only while it has an open card, and goes when the card is answered; the counts
  name lead-1 ("2 IC and lead-1 wait on you") and never count it as an IC, and drop the "oldest" part when the line
  would not fit the pane.
  An answered card never shows on a row; with none open, the card ends "last answered: <id> · <answer>". Card
  files are read only from `checks/lead-1/cards/*.md`, never one whose name starts with ".".
- **They do not prove:** that a card file lead-1 writes reaches the board on a real disk (the tests serve the
  fixtures; `shared/tests/test-card-add.sh` checks that the script writes one fixture byte for byte), how the pane looks
  on a real terminal, that hotkeys reach the pane (tests press buttons by
  key, and only check that each `hotkey` prop is set), what ctrl+x x does while the keys are at the prompt, that Esc
  returns the keys, that closing the board clears the card (the test kit cannot raise the close event), what ↑ does
  on a board that fits, whether ctrl+x tab or a click gives the keys back, or the local-time display. Nor do they
  prove the dock width the engine grants (the test kit has no terminal: the 45% and width − 60 cap is read from the
  engine, not tested), whether the board docks beside the transcript or opens above the prompt, that a row fits on a
  real terminal (wide characters, the engine's own truncation), or that a letter brings its card into view (the kit
  answers the board's scroll with "no implementation", so no test sees the press ask for it, nor whether the engine
  moves a docked pane). Nor do they prove that the engine lists the board after a real reload of the mod (the kit
  cannot reload a module), or that the real close event reaches the hook that stops the timers. Each of these is
  checked by the owner's run of "How to try it" (steps 1–3, 6–9, 11–19, the rows marked "real terminal only").
