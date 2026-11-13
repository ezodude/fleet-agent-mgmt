---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**, and deliver each round **staged**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet.

**REQUIRED SUB-SKILL:** explaining-in-steps governs pacing. One decision per checkpoint; never a wall of questions.

A round is delivered as:

1. **The map**, one turn. Number the frontier, one line per decision, no bodies, no recommendations. End with "N open. Q1 next." and stop. A frontier of one or two skips the map. When the map changes, a dropped item stays on it marked `dropped: <reason>` and a restated item is marked `restated`; never remove one silently, or the user cannot tell a merged question from a lost one.
2. **One question per message.** Open with the problem and the decision in plain words, draw the mechanism when there is one, give the choices as what happens if picked, then the recommendation and the facts it rests on. Prefer multiple choice; open-ended is fine when the choices are not yet known. If a topic needs more exploration, break it into several questions rather than one long one. Stop and wait.
3. **On each answer:** one-line acknowledgement, what it settled or unblocked (the map delta, with any dropped or restated item marked as in step 1), then the next question. Do not re-open a settled branch.
4. **Facts from sub-agents** land inside the question they unblock, compressed to what that decision needs, with the time of the probe (`probed 11:35: ...`) so the user can judge whether it is stale. Never as a standalone dump.
5. **"batch"** from the user switches to whole-round delivery (every frontier question in one message) until they say otherwise.

Question format, plain text, no emoji. Written for a reader who knows nothing yet: no id, sha or ruling number in the first five lines; jargon spelt out on first use or avoided. The one id allowed up top is the question's own, prefixed by its lane (`atlas Q3`), and the question ends with the exact reply words (`atlas Q3 a`), the shape decision cards use, so a reply read cold names its lane and its choice. Ids stay unique across lanes: never a bare Q1.

```
<lane> Q3 of 9 - <title>

The problem:  <what goes wrong today, one concrete case, plain words>
The decision: <what is being chosen between, one sentence>

<the mechanism drawn, when there is one>

  a) <choice>: <what happens if we pick it>
  b) <choice>: <what happens if we pick it>
  c) <choice>: <what happens if we pick it>

Recommended: <letter, and the one reason>
Rests on: <facts; ids, shas and ruling numbers here or in the file, never above>
Reply:    "<lane> Q3 a" | "<lane> Q3 b" | "<lane> Q3 c"
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and deliver the next round the same way. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's, but only the ones that are truly theirs: the goal, a constraint they hold, an irreversible step, a trade-off with real stakes. Before asking, test each question: would the user's answer differ from your recommendation for a reason only they hold? If not, it is mechanics (where something runs, which file, the order of steps, a default with no stake): decide it yourself, mark it "my call" with its reason, and list it once in the closing summary so the user can overrule it in one line. Put the rest to the user and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Close with a shared-understanding summary drawn as a diagram, and wait for the user to confirm it. Do not act on it until they do.
