# fleet-board

A terminal viewer of lead-1's board page. It reads files and tmux panes and never types, attaches or changes tmux state.

Run it in its own tmux session: `tmux new-session -d -s fleet-board shared/board/fleet-board.sh`, then `tmux attach -t fleet-board`. It needs fzf 0.74 or later.

- `fleet-board.sh` is the board: YOURS, RED, NEXT and one green line; `l` shows the log of everything on the page.
- `fleet-board-live.py` is the watcher the board starts. It must sit beside the script.

## What updates the screen

The watcher uses kqueue on the page, the cards, the reports, every `STATE.md` and every shaping brief, and posts to fzf's `--listen` socket only on a change. It also runs one `tmux list-panes` a second and captures a pane only when it moved, so the header shows each session as busy, idle, waiting or holding a dialog. A 30 second tick moves the ages and the clock.

## YOURS rows

- Each row leads with who asks: the IC whose pane it is, else lead-1. The ticket and decision follow when the board has them. A row that only an IC wrote takes the decision id at the start of its text, else the ticket from the `rung:` line of that IC's `STATE.md`.
- A row with no card file is drawn in the card shape from its own text and marked "no card file".
- `d` hides any row and `u` brings back the last one hidden. An open card leaves on its own once the page's done today names its ticket and decision.

## Settings and state

Env: `FLEET_HOME`, `BOARD_SOCK` (unix socket; a path over 100 bytes falls back to TCP `BOARD_PORT`, default 6266), `REFRESH_SECS` (the tick, 30), `LIVE_POLL` (1.0 s), `LIVE_SKIP` (sessions not to read), `LIVE_ONLY` (tests: read only sessions with this prefix).

State lives in `$FLEET_HOME/board-state`: `read` (the hidden rows), `board.pid` (one board per data folder; a second one refuses to start), `live.pid`, `live.log` (one line per render: reason, milliseconds, what was posted) and `live.err`. A crashed watcher restarts; after three quick exits the header says it stopped, and `ctrl-r`, `d` and `l` then render without it.

Check a pane reading without the board: `python3 -I shared/board/fleet-board-live.py once`.
