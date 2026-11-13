#!/usr/bin/env python3
"""Pad every markdown pipe table in a file so its columns line up, in place.
Usage: align-tables.py <file>   Prints "aligned N tables" or "no tables",
WARN for any line over 160 characters, and the screen one count.
A row is a table row when it starts with optional spaces and a bar. Runs of
rows form a table; each column is padded to its widest cell, one space each
side of every bar. Separator rows (---) are left out and not required.
Every table gets a blank line above and below: a markdown viewer pulls a
line written straight under a table into it as a one-cell row.
Screen one is the line starting "close ·" to the first "---" inclusive,
blank lines and ``` fence lines not counted. What a viewer breaks is
checked after it, by shared/records/md-check.sh."""
import re, sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
out, i, n, blanks = [], 0, 0, 0
def is_row(l): return re.match(r"^\s*\|.*\|\s*$", l) is not None
while i < len(lines):
    if not is_row(lines[i]):
        out.append(lines[i]); i += 1; continue
    j = i
    while j < len(lines) and is_row(lines[j]): j += 1
    block = lines[i:j]
    indent = re.match(r"^\s*", block[0]).group(0)
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in block]
    cols = max(len(r) for r in rows)
    rows = [r + [""] * (cols - len(r)) for r in rows]
    sep = lambda r: all(re.fullmatch(r"-+", c) for c in r)
    body = [r for r in rows if not sep(r)] or rows
    w = [max(len(r[c]) for r in body) for c in range(cols)]
    if out and out[-1].strip():
        out.append(""); blanks += 1
    for r in rows:
        if sep(r):
            out.append(indent + "|" + "|".join("-" * (w[c] + 2) for c in range(cols)) + "|")
        else:
            out.append(indent + "| " + " | ".join(r[c].ljust(w[c]) for c in range(cols)) + " |")
    if j < len(lines) and lines[j].strip():
        out.append(""); blanks += 1
    n += 1; i = j
open(p, "w", encoding="utf-8").write("\n".join(out))
for k, l in enumerate(out, 1):
    if len(l) > 160: print(f"WARN line {k} is {len(l)} chars; a pane wraps it")
print(f"aligned {n} tables" if n else "no tables")
if blanks: print(f"added {blanks} blank lines around tables")
start = next((k for k, l in enumerate(out) if l.startswith("close ·")), None)
end = next((k for k, l in enumerate(out) if start is not None and k > start and l.strip() == "---"), None)
if start is not None and end is not None:
    count = sum(1 for l in out[start:end + 1] if l.strip() and not l.strip().startswith("```"))
    print(f"screen one: {count} lines, blank lines not counted" + ("" if count < 45 else "; WARN over 44, cut repetition, never rows"))
