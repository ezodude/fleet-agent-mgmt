#!/usr/bin/env python3
"""The text of the current turn, from a Claude Code transcript, for stop-skill-gate.sh.

  python3 turn_text.py <transcript.jsonl>      prints the turn's text; nothing is written

A turn is every assistant record after the last human turn. A human turn is a user
record whose content is a string, or a list with no tool_result block (a tool_result
record is the harness answering a tool call, not the owner typing). From each assistant
record it takes the text blocks and the `message` input of every SendMessage call, so a
STOP report sent to lead-1 behind a final text of "sent, holding" still counts. When the
turn holds no text at all it prints the last non-blank assistant text seen in the file.

Exit 0 always; an unreadable line is skipped. The gate appends this output to
.last_assistant_message before it looks for a skill header.

  python3 turn_text.py --start <transcript.jsonl>   prints owner | compact | machine

Who started the current turn, for the lead's chat gate: the last user record that is
neither a tool_result nor a harness insert. A harness insert (stop hook feedback, a skill
body, a reminder) is isMeta with no origin; it continues the turn, it does not start one.
origin.kind "human" is the owner; isCompactSummary, or text opening "This session is being
continued", is compact; any other origin (a peer, a subagent, a notice), or text opening with
a harness wrapper, is machine. Anything else is the owner. No record at all: owner.
A line absorbed mid-turn is an attachment of type queued_command. One the owner typed
makes the turn the owner's; one opening with a harness wrapper (a peer message, a task
notice) changes nothing, so a notice never takes a turn back from the owner.
"""
import json
import sys


def turn_text(path):
    last, turn = "", []
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            r = json.loads(line)
        except Exception:   # noqa: BLE001  a torn line is not a turn
            continue
        ty, c = r.get("type"), r.get("message", {}).get("content")
        if ty == "user":
            human = isinstance(c, str) or not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c or [])
            if human:
                turn = []
            continue
        if ty != "assistant":
            continue
        if isinstance(c, str):
            txt, sends = c, []
        else:
            blocks = [b for b in c or [] if isinstance(b, dict)]
            txt = "\n".join(b.get("text", "") for b in blocks if b.get("type") == "text")
            sends = [str((b.get("input") or {}).get("message", ""))
                     for b in blocks if b.get("type") == "tool_use" and b.get("name") == "SendMessage"]
        if txt.strip():
            last = txt
        turn += [x for x in [txt] + sends if x.strip()]
    return "\n".join(turn) if turn else last


MACHINE_OPENERS = ("<cross-session-message", "<agent-message", "<task-notification",
                   "Another Claude session sent a message", "[Cross-session idle notice]")


def turn_start(path):
    start = "owner"
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            r = json.loads(line)
        except Exception:   # noqa: BLE001  a torn line is not a turn
            continue
        a = r.get("attachment") if r.get("type") == "attachment" else None
        if isinstance(a, dict) and a.get("type") == "queued_command":
            # a line absorbed while the turn ran: an owner line makes the turn the owner's; a peer
            # message or task notice absorbed mid-turn never takes it back (2026-11-09: a background
            # test's notice bounced lead-1's answer to the owner's typed question)
            if not str(a.get("prompt", "")).lstrip().startswith(MACHINE_OPENERS):
                start = "owner"
            continue
        if r.get("type") != "user":
            continue
        c, origin = r.get("message", {}).get("content"), r.get("origin")
        if not isinstance(c, str):
            blocks = [b for b in c or [] if isinstance(b, dict)]
            if any(b.get("type") == "tool_result" for b in blocks):
                continue
            c = "\n".join(b.get("text", "") for b in blocks if b.get("type") == "text")
        if r.get("isMeta") and not origin:
            continue
        kind = (origin or {}).get("kind") if isinstance(origin, dict) else None
        txt = c.lstrip()
        if kind == "human":
            start = "owner"
        elif r.get("isCompactSummary") or txt.startswith("This session is being continued"):
            start = "compact"
        elif kind or txt.startswith(MACHINE_OPENERS):
            start = "machine"
        else:
            start = "owner"
    return start


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--start":
        print(turn_start(sys.argv[2]))
        sys.exit(0)
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    print(turn_text(sys.argv[1]))
