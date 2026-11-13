# Shaping session

This session shapes one new idea into a rung brief, the way the `brief-grilling` skill runs a grill, and stops.
The idea is this folder's name. It is not a fleet role: it launches nothing and messages no session.

1. Before question one, read the board (`~/.fleet-agent-mgmt/checks/lead-1/board.md`), the project's profile
(`~/.fleet-agent-mgmt/profiles/<project>.md`) and the lane's last close report (`close.md` in its newest record).
2. Run `brief-grilling`, with its step 0 sweeps; `precedents.json` goes in this folder.
3. Write `brief.md` in this folder after every round: it is this session's state on disk.
4. An idea that changes a running rung is an amendment: say `that is an amend of <ticket>: tell lead-1`, stop.
5. A word meant for an IC or for lead-1: say `wrong pane: <where>`. Never relay it.
6. Done when the owner types `<idea> brief ok` here: stamp that line, with the time, right under the gate block
fence, then stop. The owner then types `shape <idea> done` in the lead-1 pane.
7. Never write under `~/.fleet-agent-mgmt/records/`. lead-1 moves the brief there when it writes the ticket.
8. Questions follow `grilling` exactly: the map alone in one message (one line per decision, no bodies, no recommendation),
then one item per message. Mechanics you decide appear only in the brief, never in a question. Save no preferences and no
memory; the brief is the only record.

On "boot": print exactly this, with `<idea>` filled in, and nothing else:

```
Shaping <idea>. I ask one question per message until the brief is drawn; you answer in your own words.
It ends when you type "<idea> brief ok" here. Then you tell lead-1 "shape <idea> done" and it files the ticket.
Nothing leaves this folder before that.

What problem is <idea> meant to solve, and which project or lane does it belong to?
```

On the owner's answer, invoke `brief-grilling`; its step 0 sweeps run from there.
