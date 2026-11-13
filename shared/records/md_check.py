"""Render a markdown file the owner will read and fail on what a viewer breaks.

Called by shared/records/md-check.sh, which pins markdown-it-py. Usage:
  md_check.py <file> [<file> ...]
Exit 0 every file clean, 1 a fault in any file, 2 a file it cannot read.

The file is parsed as CommonMark with tables on, the way a markdown viewer
reads it, and four faults are reported, one line each with its line number:

  swallowed   a line written straight under a table, with no blank line,
              that the viewer pulls into the table as a one-cell row
  merged      lined-up plain text (a continuation line indented, or two or
              more lines with runs of 3+ spaces mid-line) that the viewer
              runs into one paragraph; put it in a ``` fence
  vanishes    a <word> outside backticks or a fence, which the viewer reads
              as an HTML tag and drops; write `<word>`
  wide        a line over 160 characters, which a pane wraps

Ordinary prose wrapped across lines is not a fault: only indented or
column-aligned continuation lines are.
"""
import re
import sys

from markdown_it import MarkdownIt

WIDTH = 160
ROW = re.compile(r"^\s*\|.*\|\s*$")
ALIGNED = re.compile(r"\S {3,}\S")


def check(path: str) -> list[tuple[int, str]]:
    lines = open(path, encoding="utf-8").read().split("\n")
    tokens = MarkdownIt("commonmark").enable("table").parse("\n".join(lines))
    faults = []
    for tok in tokens:
        if tok.type == "table_open" and tok.map:
            for n in range(*tok.map):
                if lines[n].strip() and not ROW.match(lines[n]):
                    faults.append((n + 1, f"swallowed: {lines[n].strip()[:70]}"))
        if tok.type == "paragraph_open" and tok.map and tok.map[1] - tok.map[0] > 1:
            span = lines[tok.map[0]:tok.map[1]]
            indented = any(re.match(r"^\s+\S", l) for l in span[1:])
            aligned = sum(1 for l in span if ALIGNED.search(l.strip())) >= 2
            if indented or aligned:
                faults.append((tok.map[0] + 1, f"merged: {len(span)} lines run into one paragraph: {span[0].strip()[:60]}"))
        if tok.type == "inline" and tok.children:
            for child in tok.children:
                if child.type == "html_inline":
                    faults.append((tok.map[0] + 1 if tok.map else 0, f"vanishes: {child.content}"))
        if tok.type == "html_block" and tok.map:
            faults.append((tok.map[0] + 1, f"vanishes: {lines[tok.map[0]].strip()[:70]}"))
    for n, line in enumerate(lines, 1):
        if len(line) > WIDTH:
            faults.append((n, f"wide: {len(line)} chars"))
    return sorted(faults)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: md-check.sh <file> [<file> ...]")
        return 2
    worst = 0
    for path in sys.argv[1:]:
        try:
            faults = check(path)
        except OSError as error:
            print(f"md-check {path}: cannot read: {error}")
            worst = 2
            continue
        if faults:
            print(f"md-check {path}: {len(faults)} faults")
            for at, fault in faults:
                print(f"  line {at}: {fault}")
            worst = max(worst, 1)
        else:
            print(f"md-check {path}: ok")
    return worst


if __name__ == "__main__":
    sys.exit(main())
