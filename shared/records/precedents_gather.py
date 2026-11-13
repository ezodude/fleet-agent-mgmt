"""The precedents gatherer: the earlier close reports of one project, as numbered rows.

    shared/records/precedents-gather.sh [--root <records root>] <project>

For each record folder <root>/<project>/<record>/ that holds a close.md, prints the CHANGED, LEARNED and
OWED sections of the close report's screen one, one row per line, each with its reference
"<record> · <section> · row <n>". The brief-grilling step 0 sweep (shared/skills/sweeping-precedents) feeds
this output to a haiku agent, so the agent reads only what is printed here.

Read: close.md only, screen one only (up to the first line that is exactly --- or a "## " heading). Never
read: a sources/ folder, at the project level or in a record; any other file in a record folder.

A section opens at a line at the left edge that starts with its name ("LEARNED, what bites the next
rung", the template's shape), or at a table header row whose first cell starts with it ("| LEARNED: KIND",
the compact shape). It ends at the next line at the left edge that is not a table row, or the next table
header row naming another section. The first table row after a title is the column names, printed once; separator rows are skipped.
A bullet or text line inside a section is a row too; a section whose only line is "none" prints none.

A row whose text (case and spacing aside) matches an earlier row is printed and marked
"(same text as <reference>)", so the sweep merges rows that say the same thing.

Exit 0 with the rows, or with "none: no close report for <project>"; exit 2 with a plain reason on stderr
for a missing root or project, or a project that is not one folder name.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from paths import FLEET_HOME  # noqa: E402

SECTIONS = ("CHANGED", "LEARNED", "OWED")
USAGE = "usage: precedents-gather.sh [--root <records root>] <project>"
TITLE = re.compile(r"^(CHANGED|LEARNED|OWED)(?=[,:\s]|$)")
CELL_HEAD = re.compile(r"^\|\s*([A-Z][A-Z]{2,}):\s*")
SEPARATOR = re.compile(r"^\|?[\s:|-]*-[\s:|-]*$")


def die(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(2)


def natural(name):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", name)]


def cells(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def screen_one(text):
    lines = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line.strip() == "---" or line.startswith("## "):
            break
        lines.append(line.rstrip())
    return lines


def read_close(text):
    """{section: (column names or "", [row text])} for the sections present; title line or ""."""
    lines = screen_one(text)
    title = next((l.strip() for l in lines if l.strip().startswith("close ·")), "")
    found, cur, want_head = {}, None, False
    for line in lines:
        if not line.strip():
            continue
        s = line.strip()
        m = CELL_HEAD.match(s) if s.startswith("|") else None
        if m:   # compact shape: the header row names its section
            cur = m.group(1) if m.group(1) in SECTIONS else None
            if cur:
                found[cur] = (" | ".join(cells(s[m.end():])), [])
            want_head = False
            continue
        if not line[0].isspace() and not s.startswith("|"):   # a table may sit at the left edge
            t = TITLE.match(line)
            cur = t.group(1) if t else None
            if cur:
                found[cur] = ("", [])
                want_head = True
            continue
        if cur is None or s.startswith("```"):
            continue
        if s.startswith("|"):
            if SEPARATOR.match(s):
                continue
            if want_head:
                found[cur] = (" | ".join(cells(s)), found[cur][1])
                want_head = False
                continue
            found[cur][1].append(" | ".join(cells(s)))
        else:
            want_head = False
            found[cur][1].append(re.sub(r"^[-*]\s+", "", s))
    for k, (cols, rows) in found.items():
        if [r.lower() for r in rows] == ["none"]:
            found[k] = (cols, [])
    return title, found


def main(argv):
    root = os.environ.get("FLEET_RECORDS") or os.path.join(FLEET_HOME, "records")
    args = list(argv)
    if args[:1] == ["--root"]:
        if len(args) < 2:
            die(USAGE)
        root, args = args[1], args[2:]
    if len(args) != 1 or not args[0] or args[0].startswith("-"):
        die(USAGE)
    project = args[0]
    if "/" in project or project in (".", "..", "sources"):
        die(f"precedents-gather: a project is one folder name, not {project}")
    if not os.path.isdir(root):
        die(f"precedents-gather: no records root {root}")
    pdir = os.path.join(root, project)
    if not os.path.isdir(pdir):
        there = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)) and not d.startswith("."))
        die(f"precedents-gather: no project {project} under {root} (projects: {', '.join(there) or 'none'})")
    records, missing = [], []
    for d in sorted(os.listdir(pdir), key=natural):
        rdir = os.path.join(pdir, d)
        if d == "sources" or d.startswith(".") or not os.path.isdir(rdir):
            continue
        close = os.path.join(rdir, "close.md")
        (records if os.path.isfile(close) else missing).append(d)
    if not records:
        print(f"none: no close report for {project}")
        return 0
    out = [f"precedents · {project} · {len(records)} close report{'s' if len(records) != 1 else ''} · {pdir}"]
    seen = {}
    for rec in records:
        try:
            with open(os.path.join(pdir, rec, "close.md"), encoding="utf-8", errors="replace") as f:
                title, found = read_close(f.read())
        except OSError as e:
            out += ["", f"== {rec} · unreadable: {e.strerror}"]
            continue
        out += ["", f"== {rec} · {title}" if title else f"== {rec}"]
        for sec in SECTIONS:
            if sec not in found:
                out.append(f"{sec:<9} none: no {sec} section")
                continue
            cols, rows = found[sec]
            if not rows:
                out.append(f"{sec:<9} none")
                continue
            out.append(f"{sec:<9} {cols}".rstrip())
            for n, row in enumerate(rows, 1):
                ref = f"{rec} · {sec} · row {n}"
                key = re.sub(r"\s+", " ", row.lower()).strip()
                mark = f"   (same text as {seen[key]})" if key in seen else ""
                seen.setdefault(key, ref)
                out.append(f"  {ref}   {row}{mark}")
    if missing:
        out += ["", f"no close.md   {', '.join(missing)}"]
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
