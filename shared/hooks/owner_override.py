#!/usr/bin/env python3
"""The owner's override of a red gate line, read by push-gate.sh at a push or a draft PR.

    owner_override.py <record> <receipt> <session log folder>

The owner overrides a red line by typing, in the IC's pane:

    <lane> r<n> override <checks>: <reason>        ATL-42 r1 override lint, 7: fixed upstream next week

lane and rung come from the record folder's name (atl-42-r1: ATL-42, r1), in any case. <checks> is one
or more receipt line numbers or names, split by commas or spaces: a name is a whole word of exactly one
gate line's command ("lint" in `make lint`; a word in two commands names neither). <reason> is not empty.

A typed line counts only when Claude Code's session log holds it as typed by a person (origin.kind
"human", as freeze_rules.human_matches reads it): a message from lead-1 or any other session is "peer"
and never counts. The IC then notes it: an `owner` line in decision-record.md quoting the typed line.

Prints one line per red line, tab separated: <n> <state> <detail>, state one of
    covered    the typed line and the decision record's owner line that quotes it
    unnoted    typed, but no owner line in decision-record.md quotes it
    open       no typed override names this line
Exit 0 when every red line is covered, 1 otherwise. The receipt stays red: the override lets the
push through, it does not turn the line green, and the close lists it.
"""

import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "records"))
import freeze_rules  # noqa: E402  human_matches and typed_line, shared with the spec freeze

LINE = re.compile(r"^  (\d+)  (green|red) +exit \d+  (.*)$")


def receipt_lines(receipt):
    """{n: (state, command)} for every gate line of a receipt."""
    out = {}
    with open(receipt, encoding="utf-8") as fh:
        for raw in fh:
            m = LINE.match(raw.rstrip("\n"))
            if m:
                out[int(m.group(1))] = (m.group(2), m.group(3))
    return out


def lines_named(token, lines):
    """The receipt line a token names: its number, or a whole word of exactly one command."""
    if token.isdigit():
        return {int(token)} if int(token) in lines else set()
    word = re.compile(r"(?<![\w-])" + re.escape(token) + r"(?![\w-])", re.I)
    hits = {n for n, (_, cmd) in lines.items() if word.search(cmd)}
    return hits if len(hits) == 1 else set()


def squash(s):
    return re.sub(r"\s+", " ", s).strip().lower()


def main(record, receipt, logs):
    name = os.path.basename(os.path.normpath(record))
    m = re.match(r"^(.+)-r(\d+)$", name)
    if not m:
        print(f"0\topen\trecord folder {record} does not end in -r<n>")
        return 1
    lane, rung = m.group(1).lower(), f"r{m.group(2)}"
    typed = re.compile(r"^" + re.escape(f"{lane} {rung} override ") + r"(.+?):\s*(\S.*)$", re.I)
    lines = receipt_lines(receipt)
    red = sorted(n for n, (state, _) in lines.items() if state == "red")
    if not red:
        return 0

    def overrides(text):
        return [typed.match(freeze_rules.typed_line(l)) for l in text.split("\n")]

    folders = [logs] if logs and os.path.isdir(logs) else []
    _, hits = freeze_rules.human_matches(folders, 0, lambda text: any(overrides(text)))
    named = {}   # line n -> the newest typed override naming it
    for h in sorted(hits, key=lambda h: h["epoch"]):
        for mt in filter(None, overrides(h["text"])):
            for tok in re.split(r"[,\s]+", mt.group(1)):
                if tok and tok.lower() != "and":
                    for n in lines_named(tok, lines):
                        named[n] = (freeze_rules.typed_line(mt.group(0)), h["timestamp"])

    try:
        with open(os.path.join(record, "decision-record.md"), encoding="utf-8") as fh:
            owners = [squash(l) for l in fh if re.match(r"^  owner\s", l)]
    except OSError:
        owners = []
    bad = 0
    for n in red:
        if n not in named:
            bad += 1
            print(f"{n}\topen\t{lines[n][1]}")
            continue
        said, when = named[n]
        if any(squash(said) in o for o in owners):
            print(f"{n}\tcovered\t\"{said}\" typed {when}")
        else:
            bad += 1
            print(f"{n}\tunnoted\t\"{said}\" typed {when}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: owner_override.py <record> <receipt> <session log folder>")
    sys.exit(main(*sys.argv[1:]))
