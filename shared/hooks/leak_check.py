#!/usr/bin/env python3
"""The leak list for committed docs, in one place: artefact-gate.sh and push-gate.sh both read it.

  python3 leak_check.py --doc <file|-> [--path <p>]   the full list, plus render faults for */specs/*.md
  python3 leak_check.py --diff                        a unified diff on stdin: the ADDED lines,
                                                      path and name patterns only
  python3 leak_check.py --text <label>                any text on stdin (a commit message, a PR
                                                      title or body): path and name patterns only

A doc an IC commits to a product repo is public: the team reads it on GitHub. It never
names the fleet. --doc checks every pattern below. --path names the doc in the hits and
decides the render check when the text comes on stdin; a file argument is its own path.
--diff and --text check only the paths and names, since code may use ids such as DR1 or E2.
Names match in any case. Inside a ``` or ~~~ fence the four line-start labels (Reply:,
style:, source:, record:) are not read, so a fenced YAML sample passes; every other
pattern still is.

With the --tokens flag (any mode) and when FLEET_HOME/leak-tokens.txt exists, every token in it is
also a hit, in any case; without the flag the file is never read, since a product repo may use
them (a ticket key in a commit message). push-gate.sh passes --tokens only for this repo's own
clone. One token per line, blank lines and lines starting with # ignored, and a token ending in
<digits> (ABC-<digits>) stands for the regex ABC-[0-9]+. A token is a hit only where no letter or digit sits directly before or after it. Absent: no tokens.

Roster IC names come from the fleet block of FLEET_HOME/roster.md (FLEET_ROSTER overrides
the path), the same block skill-lib.sh reads.

Output: one hit per line, "file:line: pattern: text". Exit 0 clean, 1 with hits, 2 on
a usage error. Nothing is written.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from paths import FLEET_REPO, FLEET_HOME  # noqa: E402

ROSTER = os.environ.get("FLEET_ROSTER", os.path.join(FLEET_HOME, "roster.md"))

# Paths and names: checked in a doc and in the added lines of a push.
PATHS = [
    # a Databricks workspace path (a Workspace/Users path, a Users/<user> or Users/${...} placeholder) is product text;
    # the label and pattern are split so a grep for the home prefix finds no hard-coded home path in this file
    ("/Users" "/", r"(?<!/Workspace)/Users" r"/(?!<|\$?\{)"),
    (".fleet-agent-mgmt", r"\.fleet-agent-mgmt"),
    (".claude/checks", r"\.claude/checks"),
]
# Checked in a doc only.
DOC_ONLY = [
    ("~/", r"~/"),
    ("$HOME path", r"\$\{?HOME\}?/"),
    ("STOP n", r"\bSTOP [0-9]"),
    ("screen one", r"(?i)\bscreen one\b"),
    ("spec ok", r"(?i)\bspec ok\b"),
    ("Reply: line", r"^Reply:"),
    ("style: line", r"^style:"),
    ("source: line", r"^source:"),
    ("record: line", r"^record:"),
    ("DR id", r"\bDR[0-9]+\b"),
    ("UAT id", r"\bUAT[0-9]+\b"),
    ("E id", r"\bE[0-9]+\b"),
    ("the IC", r"(?i)\bthe IC\b"),
    ("decision-record", r"decision-record"),
    ("evidence.md", r"evidence\.md"),
    ("handoff.md", r"handoff\.md"),
]
# Fleet header lines; inside a fence they are a code or config sample, not read.
LINE_START = {"Reply: line", "style: line", "source: line", "record: line"}


def roster_names(path=ROSTER):
    """Every name in the roster's fleet block, lead-1 included."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    names, inside = [], False
    for line in lines:
        if line == "```fleet":
            inside = True
        elif inside and line == "```":
            break
        elif inside and line.strip():
            names.append(line.split("\t", 1)[0].strip())
    return names


def name_patterns():
    names = ["lead-1"] + [n for n in roster_names() if n and n != "lead-1"]
    return [(n if n == "lead-1" else n + " (roster name)", r"(?i)(?<![\w-])" + re.escape(n) + r"(?![\w-])")
            for n in names]


USE_TOKENS = False   # set by --tokens


def token_patterns():
    """One (label, regex) per token in FLEET_HOME/leak-tokens.txt; none when the file is absent."""
    try:
        lines = open(os.path.join(FLEET_HOME, "leak-tokens.txt"), encoding="utf-8").read().splitlines()
    except OSError:
        return []
    out = []
    for line in lines:
        tok = line.strip()
        if not tok or tok.startswith("#"):
            continue
        if tok == "<digits>":
            continue   # an empty prefix would match any digit run
        rx = re.escape(tok[:-len("<digits>")]) + "[0-9]+" if tok.endswith("<digits>") else re.escape(tok)
        out.append((tok + " (leak token)", r"(?i)(?<![A-Za-z0-9])" + rx + r"(?![A-Za-z0-9])"))
    return out


def compiled(doc):
    pats = PATHS + name_patterns() + (token_patterns() if USE_TOKENS else []) + (DOC_ONLY if doc else [])
    return [(label, re.compile(rx)) for label, rx in pats]


def short(text):
    text = text.strip()
    return text if len(text) <= 120 else text[:117] + "..."


def leaks(lines, pats, fenced=frozenset()):
    """(line number, label, text) for each pattern found, one hit per pattern per line.
    On a line number in `fenced` the LINE_START labels are not read."""
    out = []
    for n, line in lines:
        for label, rx in pats:
            if n in fenced and label in LINE_START:
                continue
            if rx.search(line):
                out.append((n, label, short(line)))
    return out


def fence_lines(lines, start=0):
    """Line numbers (1-based) inside a fence or on a fence line, and the line an
    unclosed fence opened at (0 when every fence closes). A fence opens on ``` or
    ~~~ (three or more) and closes on a line of the same character, at least as
    many, and nothing after it."""
    inside, fence, opened_at = set(), None, 0
    for k in range(start, len(lines)):
        line = lines[k]
        if fence is None:
            m = re.match(r"\s*(`{3,}|~{3,})", line)
            if m:
                fence, opened_at = m.group(1), k + 1
                inside.add(k + 1)
            continue
        inside.add(k + 1)
        if re.match(r"\s*" + re.escape(fence[0]) + "{%d,}\\s*$" % len(fence), line):
            fence = None
    return inside, (opened_at if fence else 0)


def render_faults(text):
    """Faults that break GitHub rendering: text straight above a `---` (it turns the
    block into a heading) and a fence left open. A front-matter block at line 1
    and lines inside a fence are not read for the `---` fault."""
    out, lines = [], text.splitlines()
    i = 0
    if lines and lines[0].strip() == "---":            # front matter: skip to its closing ---
        for k in range(1, len(lines)):
            if lines[k].strip() == "---":
                i = k + 1
                break
    inside, unclosed = fence_lines(lines, i)
    for k in range(i, len(lines)):
        if k + 1 in inside:
            continue
        # under a table row --- ends the table as a rule; it does not underline the row as a heading
        if lines[k].strip() == "---" and k > 0 and lines[k - 1].strip() and not re.match(r" {0,3}\|", lines[k - 1]):
            out.append((k + 1, "text above ---", short(lines[k - 1])))
    if unclosed:
        out.append((unclosed, "unclosed ``` fence", short(lines[unclosed - 1])))
    return out


def is_spec(path):
    """A spec: any *.md under a specs/ folder, the path absolute or relative to the repo."""
    return re.search(r"(^|/)specs/.*\.md$", path or "") is not None


def check_doc(text, path="-"):
    """Hits for a committed doc: the full leak list, plus render faults for a spec."""
    lines = text.splitlines()
    hits = leaks(enumerate(lines, 1), compiled(doc=True), fence_lines(lines)[0])
    if is_spec(path):
        hits += render_faults(text)
    return sorted(hits)


def check_text(text):
    """Hits in plain text (a commit message, a PR title or body), paths and names only."""
    return leaks(enumerate(text.splitlines(), 1), compiled(doc=False))


def check_diff(diff):
    """Hits in the added lines of a unified diff, paths and names only: (file, line, label, text).
    A `+++ ` line is a file header only outside a hunk; the hunk's own counts say where
    it ends, so an added line whose text starts with `++ ` is still read."""
    pats, out = compiled(doc=False), []
    path, n, old, new = "-", 0, 0, 0
    for line in diff.splitlines():
        if old > 0 or new > 0:                         # inside a hunk
            if line.startswith("+"):
                for _, label, text in leaks([(n, line[1:])], pats):
                    out.append((path, n, label, text))
                n, new = n + 1, new - 1
            elif line.startswith("-"):
                old -= 1
            elif line.startswith(" ") or line == "":
                n, old, new = n + 1, old - 1, new - 1
            continue
        if line.startswith("+++ "):
            p = line[4:].split("\t", 1)[0]
            path = p[2:] if p.startswith("b/") else p
        elif line.startswith("@@"):
            m = re.match(r"^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            if m:
                old = int(m.group(1)) if m.group(1) is not None else 1
                n = int(m.group(2))
                new = int(m.group(3)) if m.group(3) is not None else 1
    return out


def main(argv):
    global USE_TOKENS
    if "--tokens" in argv:
        USE_TOKENS = True
        argv = [a for a in argv if a != "--tokens"]
    if len(argv) >= 2 and argv[0] == "--doc":
        src, path = argv[1], None
        if "--path" in argv:
            k = argv.index("--path")
            path = argv[k + 1] if k + 1 < len(argv) else None
        try:
            text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8", errors="replace").read()
        except OSError as e:
            print("leak_check: %s" % e, file=sys.stderr)
            return 2
        name = path or src
        hits = check_doc(text, name)
        for n, label, line in hits:
            print("%s:%d: %s: %s" % (name, n, label, line))
        return 1 if hits else 0
    if len(argv) == 2 and argv[0] == "--text":
        hits = check_text(sys.stdin.read())
        for n, label, line in hits:
            print("%s:%d: %s: %s" % (argv[1], n, label, line))
        return 1 if hits else 0
    if argv == ["--diff"]:
        hits = check_diff(sys.stdin.read())
        for f, n, label, line in hits:
            print("%s:%d: %s: %s" % (f, n, label, line))
        return 1 if hits else 0
    print("\n".join(__doc__.strip().splitlines()[2:7]), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
