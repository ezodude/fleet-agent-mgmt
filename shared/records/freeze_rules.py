#!/usr/bin/env python3
"""Freeze a rung's rules and gate: write <record>/rules.md and <record>/gate.md from the approved design spec.
Check a spec's screen one strictly, and against a record folder's rules.md and gate.md.

Run by the IC in its worktree on "spec ok", through shared/records/freeze-rules.sh
(writing-a-design-spec step 5). It copies, it never composes:

  rules.md  =  rules · <lane> r<n> · frozen at <sha> · <date time>
               screen one's TERMS block
               the standing ONE-WAY block of skills/foundations/one-way.md, verbatim
               screen one's ONE-WAY, DECIDED and REJECTED blocks, in the spec's order

  gate.md   =  gate · <lane> r<n> · frozen at <sha> · <date time>
               GATE BLOCK
               screen one's checks lines, without their heading and without the
               `on main` lines (main's output stays in the spec and evidence.md)

  frozen.sha256 = the spec's repo path, the approved sha, and the sha256 of rules.md
               and gate.md (shared/frozen.py documents it and every check that reads it)

Screen one is the spec from its title line to the first line that is exactly
`---` outside a fence and outside an HTML comment (CRLF is read as LF). A fence
is read as GitHub reads it: it opens on ``` or ~~~ (three or more, at most three
spaces in front) and closes on the same character, at least as many, with
nothing after it; a line indented four spaces is never a fence line or a table
row. It is read in one of two shapes, chosen per spec:

  new shape   any `## Terms`, `## One-way`, `## Decided`, `## Rejected` or
              `## Checks` heading (a heading that only starts with one of these
              names counts too, and is refused below). All five blocks are
              required. The strict rules:
              - A block heading is exactly `## Terms`, `## One-way`, `## Decided`,
                `## Rejected` or `## Checks`, at the left edge. A heading with
                more words (`## One-way doors`), another case (`## decided`) or
                another level (`### Checks`) is refused: it is ambiguous.
              - Headings inside a fence or an HTML comment are not headings. A block
                heading inside an HTML comment is refused: GitHub does not show it.
                A block heading inside a block quote or a list item, and an
                underlined heading (a block name over `===` or `----`), are
                refused: the freeze would not read them, GitHub shows them.
              - Each block heading appears once.
              - Under a block heading: blank lines, then exactly one Markdown table
                or one fence, then only blank lines until the next heading. Anything
                else is refused, not dropped: a row after a blank line, a row with no
                leading `|`, a line under the table, a second table or fence.
              - A table has a header row, a `|---|` row and at least one row; every
                row has the header's cell count; no two columns share a name. An
                empty block is written as one row `none`, never as a header alone:
                `none` in the rule column, or as the row's only filled cell.
              - The `---` fold has a blank line or a table row above it (under a
                text line GitHub reads it as a heading underline).
              A rule table (Terms, One-way, Decided, Rejected) becomes one rules.md
              line per row, two spaces in front: each cell with its whitespace runs
              collapsed to one space (`\\|` read as `|`), columns padded and two
              spaces apart, the `|---|` row dropped. Column order in rules.md: the
              `#` (or `id`) column, then the rule column (`stop and ask before`,
              `never change`, `do not come back to`), then the other columns, then
              `source` in brackets. A rule table without its rule column is refused.
              A `#` cell is a row number: 1, 1., ✔ 1 or D1. A source cell reading
              `standing` or starting `retired <date> by <n>`, and any cell holding
              `[standing]` or `[retired`, is refused: those tags are written by the freeze and by
              lead-1's amendments, never by the spec. Terms rows keep their column
              order (name first). Under the default heading (`TERMS`,
              `ONE-WAY  stop and ask before:`, `DECIDED  never change:`,
              `REJECTED  do not come back to:`).
              A fence's non-blank lines are the block. A line at the left edge gets
              two spaces in front; a line already indented is copied as is. The
              rules.md heading is the fence's first line when it starts with the
              block's capital name; a first line that is the block's caption
              (`never change`, with or without `:`) is the default heading, never a
              rule; a first line at the left edge ending in `:` with every other line
              indented joins the heading as its caption. In a rule fence a line
              indented deeper than the row above it (a wrapped rule) is refused.
              A checks table has the columns command (or proves done), pass and on
              main, each once, in any order; a cell that is one code span is read
              without its backticks (a command holding a backtick goes in a double
              backtick span). A fence line indented with a tab is refused. A checks
              fence uses the gate labels; a first line starting `GATE` is dropped.
  old shape   capital heading lines (`TERMS  (`, `ONE-WAY  stop and ask before:`,
              `DECIDED  `, `REJECTED  `, `GATE  `), each with its two-space indented
              lines under it, unfenced; each heading once. A block line after a blank
              line, or indented with a tab or one space, is refused instead of
              dropped. GATE is optional: a spec without it gets rules.md only and a
              warning. Rungs that started before the new shape still freeze.

Checks lines (both shapes) are read by shared/records/gate_run.py's own reader: a label is
two spaces, the label (proves done, pass, on main, on failure, owner's word,
record), then two or more spaces or the end of the line; a deeper line continues
the label above it. The proves done, pass and on main lines are the same count. A
pass line is refused when it has curly quotes, an exit code worded other than
`exit N`, or an absent condition naming more than one string (`no "a" or "b"`:
write `no "a", no "b"`). It is also refused when it has words but no quoted string
(`exit 0, 0 failed`): gate-run checks only the exit code and quoted strings, so
those words would never be checked. gate.md is that shape; shared/records/gate-run.sh runs it.

The record folder is the second argument. A spec in the old shape may name it on a
`record:` line instead; with both, they must be the same folder.

<sha> is the commit that holds the spec (git log -1 -- <spec>), so the rules can
always be read beside the spec the owner approved. When <record>/decision-record.md
exists its `rules:` line is set to the same sha.

--approved <sha> names the commit the owner reviewed: the sha on the STOP 1 report's
spec line. It is required for every spec (--dump alone may leave it out). It must be
the sha of the newest line for this spec path in <record>/stop1.log, which
shared/hooks/message-gate.sh writes when a STOP 1 report passes; any other commit is
refused. The freeze refuses when screen one at HEAD is not screen one at that
commit, line for line; edits below the fold are free. The sha is written to
frozen.sha256.

The owner's word: the spec freeze also needs the owner's "<lane> r<n> spec ok" (or
"<lane> spec ok"), typed by a person in lead-1's pane or the IC's pane after the newest
STOP 1 line in stop1.log (owner_ok, documented there). It is read from Claude Code's
session logs, ~/.claude/projects/<the session cwd with every / and . turned into ->/*.jsonl,
in lead-1's folder (before the move too, from migrate/agentmgmt-path) and the IC's worktree (the repo top level of the spec) only. The log
root comes from the user's home in the password database, never from an environment
variable or a flag. A message relayed by lead-1 or any other session does not count; "spec
back" never matches; no log folder, or no entry typed by a person in it, is a refusal. The
chore freeze has no STOP 1 and does not read the logs; a record folder listed in
shared/records/legacy-records.txt or in the settings home's legacy-records.txt, under the settings home's records (never FLEET_RECORDS), skips it.

The same reader serves one more word (amend_ok, documented there): after the freeze, shared/frozen.py
amend (shared/amend-frozen.sh) refuses a rules.md amendment, and a gate.md amendment that adds a proves
done line, unless the owner typed "<lane> r<n> amend ok <card id>" after the record's last amendment
(else its freeze) and the card id is in the amend-frozen.sh reason.

The freeze refuses with exit 2 and writes nothing when: the spec is not committed
or has uncommitted changes; there is no --approved, it is not the newest STOP 1
sha in stop1.log, or screen one changed after it; the owner's spec ok typed after
that STOP 1 is not in the session logs; no record folder is given (argument or `record:` line), or the
two differ; the record folder does not end in -r<n>; screen one breaks a rule
above; rules.md, gate.md or frozen.sha256 already exists (a change after the
freeze is a card to the owner, then lead-1 appends a dated amendment line, tags
the row it replaces `[retired <date> by <line>]` and runs shared/amend-frozen.sh;
a gate line that cannot pass on origin/main is amended by lead-1 in gate.md under
a dated `# Amended` header line, the same way); a gate.md the freeze did not write
is named as such (delete it: a gate.md is never copied by hand); the standing
block is not found in one-way.md. Every reason is printed, one per line.

--check runs the same strict reading with no git and no write: exit 0 when the
spec would freeze, 2 with one reason per line on stdout. With --record <folder>:
when the folder holds rules.md, the spec's Terms, One-way, Decided and Rejected
rows are compared with rules.md's rung rows, whitespace runs collapsed: a spec row
missing from rules.md, or a rules.md row missing from the spec, is a reason. A
rules.md row ending in `[retired <date> by <line>]` and a row under an
`<KIND>  amended <date>:` heading may be in the spec or not. When gate.md came from
the freeze (its first line is `gate · ... · frozen at ...`), its commands and pass
lines are compared with the spec's Checks the same way; when it has a `# Amended`
line, the copy named on frozen.sha256's first gate history line (the gate as it
froze) is compared instead, and an amended gate.md with no gate history line is a
reason. A record folder named in shared/records/legacy-records.txt or the settings home's legacy-records.txt (as
<records>/<project>/<rung>, the records root from FLEET_RECORDS or
~/.fleet-agent-mgmt/records) is not checked at all: exit 0, a note on stderr. --path names the spec in that note
when it is read from stdin.

A chore (a docs-only cleanup, say) has no spec and no STOP 1. lead-1 freezes it before launch,
from lead-1's folder (the cwd is lead-1's row in FLEET_HOME/roster.md), with
--chore <record folder>/handoff.md:

  rules.md  =  rules · <lane> chore · frozen at handoff.md · <date time>
               the standing ONE-WAY block of skills/foundations/one-way.md, verbatim
  gate.md   =  gate · <lane> chore · frozen at handoff.md · <date time>
               GATE BLOCK
               the handoff's `## Checks` table as label lines, without the `on main` lines
  frozen.sha256 = a `chore  handoff.md` line in place of the spec and approved lines

The handoff is read strictly: a title line; a `RECORD` line naming the folder it is saved in; one
CHAIN block; no line anywhere in the handoff (the CHAIN, MODE, OPEN, the report shape, a fence) that
names writing-a-design-spec, STOP 1, --approved or a spec freeze, so the IC is never told a STOP 1
holds; one `## Checks` heading (the same heading rules as a spec's) with one table under it, columns
command, pass and on main, read as a spec's Checks table is, with the same pass-line refusals; no
placeholder `on main` cell (lead-1 runs each command once on origin/main and writes what it printed).
Refused, nothing written, when the folder already holds rules.md, gate.md, frozen.sha256, a
*-pre-*.md copy or stop1.log, when frozen.sha256 has a spec line, when decision-record.md's `rules:`
line is set, when the folder is listed in shared/records/legacy-records.txt or the settings home's legacy-records.txt, or when it holds ic-sessions.log:
an IC's hooks write a line there for each IC session that starts on an open record folder of its own
that is not frozen, and for each IC Bash command on one that is not a chore's (shared/frozen.py
stamp), so a record an IC has worked on is never frozen as a chore, whoever runs the freeze and from
wherever. The spec freeze refuses a chore's record: frozen.sha256 has a chore line, or handoff.md has
a `## Checks` heading written exactly so (another heading that starts with Checks is not one). A change to
a chore's frozen gate after launch is lead-1's amendment (shared/amend-frozen.sh), as for a rung.

Usage
  freeze_rules.py <spec path> <record folder> --approved <sha>          write rules.md, gate.md and frozen.sha256;
                                                                        print each header line and path
  freeze_rules.py <spec path> <record folder> --approved <sha> --dump   print what would be written; write nothing
  freeze_rules.py <spec path> --approved <sha> [--dump]  old shape only: the folder from the spec's `record:` line
  freeze_rules.py --check <spec|-> [--path <repo path>] [--record <folder>]
  freeze_rules.py --chore <record folder>/handoff.md [--dump]           lead-1, before a chore's launch
"""
import glob, json, os, pwd, re, subprocess, sys, time
from datetime import datetime
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))   # shared/: the frozen module stays there
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
from paths import FLEET_HOME  # noqa: E402
import gate_run  # noqa: E402  the one reader of gate.md lines, shared with shared/records/gate-run.sh

ONE_WAY = os.path.join(HERE, "..", "skills", "foundations", "one-way.md")
LEGACY = os.path.join(HERE, "legacy-records.txt")
PRE_LOG = os.path.join(HERE, "..", "frozen-before-stop1-log.txt")
RULE_BLOCKS = ("ONE-WAY", "DECIDED", "REJECTED")
ROW_BLOCKS = ("TERMS",) + RULE_BLOCKS
GATE_LABELS = gate_run.LABELS
GATE_REQUIRED_NEW = ("proves done", "pass", "on main")
# new shape: the `##` heading for each block, and the rules.md heading line when the fence has none
NEW_HEADING = {"TERMS": "Terms", "ONE-WAY": "One-way", "DECIDED": "Decided", "REJECTED": "Rejected", "GATE": "Checks"}
DEFAULT_HEADING = {"TERMS": "TERMS", "ONE-WAY": "ONE-WAY  stop and ask before:",
                   "DECIDED": "DECIDED  never change:", "REJECTED": "REJECTED  do not come back to:"}
CAPTION = {"ONE-WAY": "stop and ask before", "DECIDED": "never change", "REJECTED": "do not come back to"}
RULE_COLUMN = dict(CAPTION, TERMS="what it is")
ID_COLUMNS = ("#", "id")
ID_CELL = re.compile(r"(✔\s*)?(\d+\.?|D\d+)")
TAG = re.compile(r"\[standing\]|\[retired\b", re.I)
BLOCK_NAMES = "|".join(re.escape(x) for x in NEW_HEADING.values())
ANY_BLOCK_HEADING = re.compile(r"^ {0,3}#{1,6}\s+(" + BLOCK_NAMES + r")\b", re.I)
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")   # a fence line as GitHub reads it: at most 3 spaces in front
ROW = re.compile(r"^ {0,3}\|")                # a table row; 4 spaces in front is a code block on GitHub
RETIRED = re.compile(r"\s*\[retired \d{4}-\d{2}-\d{2} by \d+\]$")   # the tag lead-1's amendment writes
CONTAINER_HEADING = re.compile(r"^ {0,3}((>|[-*+]|\d+[.)])\s*)+#{1,6}\s+(" + BLOCK_NAMES + r")\b", re.I)
SETEXT = re.compile(r"^ {0,3}(=+|-+)\s*$")
PLACEHOLDER = re.compile(r"^\W*(|-+|–|—|\?+|todo\b.*|tbd\b.*|n/?a|none|not run\b.*|to do\b.*)\W*$", re.I)
# a line of a rung's handoff, never of a chore's: the spec step, STOP 1, the spec freeze (a freeze-rules
# line without --chore)
SPEC_STEP = re.compile(r"writing-a-design-spec|\bSTOP\s*1\b|--approved\b|freeze[-_]rules(\.sh|\.py)?\s+(?![^\n]*--chore\b)\S",
                       re.I)
SESSIONS = "ic-sessions.log"   # one line per IC session or IC Bash command on an open, unfrozen record (frozen.py stamp)
# the owner's "spec ok" and "amend ok", read from Claude Code's session logs. Fixed paths: never an environment variable
# (not HOME either, and not FLEET_HOME) and never a flag, so the IC's command line cannot point the freeze at logs of
# its own. The fleet home these paths use is the one the owner's user-level settings file names (its env block, key
# FLEET_HOME), else <passwd home>/.fleet-agent-mgmt; the settings file is only read (json.load, .get).
# Tests import this module and pass a root, or set these constants from python.
USER_HOME = pwd.getpwuid(os.getuid()).pw_dir
USER_SETTINGS = os.path.join(USER_HOME, ".claude", "settings.json")   # a test patches this constant, never an env var


def settings_fleet_home():
    """FLEET_HOME from USER_SETTINGS's env block when it names one, else <passwd home>/.fleet-agent-mgmt."""
    try:
        with open(USER_SETTINGS, encoding="utf-8") as f:
            named = (json.load(f).get("env") or {}).get("FLEET_HOME")
    except (OSError, ValueError, AttributeError):
        named = None
    return named if isinstance(named, str) and named else os.path.join(USER_HOME, ".fleet-agent-mgmt")


SESSION_LOGS = os.path.join(USER_HOME, ".claude", "projects")      # one folder per session cwd, *.jsonl inside
LEAD_CWD = os.path.realpath(os.path.join(settings_fleet_home(), "Leads", "lead-1"))   # lead-1's folder under the settings' FLEET_HOME


def old_lead_cwd(fleet_home):
    """lead-1's folder before the move to FLEET_HOME: <P>/Leads/lead-1 when <fleet_home>/migrate/agentmgmt-path
    (written by shared/migrate/copy.sh) has an absolute path P on its first line, else None (also on a read error)."""
    try:
        with open(os.path.join(fleet_home, "migrate", "agentmgmt-path"), encoding="utf-8") as f:
            first = f.readline().strip()
    except (OSError, ValueError):
        return None
    return os.path.realpath(os.path.join(first, "Leads", "lead-1")) if os.path.isabs(first) else None


LEAD_OLD_CWD = old_lead_cwd(settings_fleet_home())   # lead-1's folder before the move, read too (owner_ok, amend_ok)
LIVE_RECORDS = os.path.join(settings_fleet_home(), "records")   # legacy-records.txt read against this


class Refused(Exception):
    """One or more reasons the spec cannot be frozen."""
    def __init__(self, reasons):
        super().__init__("; ".join(reasons))
        self.reasons = list(reasons)


def fail(msg):
    raise Refused([msg])


def spec_sha(spec):
    """Short sha of the commit that holds the spec. A dirty or untracked spec is refused."""
    git = lambda *a: subprocess.run(["git", *a], capture_output=True, text=True).stdout.strip()
    if git("status", "--porcelain", "--", spec):
        fail(f"{spec} has uncommitted changes; commit the approved spec first")
    sha = git("log", "-1", "--format=%h", "--", spec)
    if not sha:
        fail(f"{spec} is not in git")
    return sha


# ---------- screen one ----------------------------------------------------------------------

def opens(line):
    """True when the line opens a fence: ``` or ~~~ (three or more) with at most 3 spaces in front.
    A ``` line with another backtick after it is inline code on GitHub, not a fence."""
    m = FENCE.match(line)
    return bool(m) and not (m.group(1)[0] == "`" and "`" in line[m.end():])


def closes(line, opener):
    """True when the line closes the fence opened by `opener`: the same character, at least as many,
    at most 3 spaces in front and nothing after it."""
    m = FENCE.match(opener)
    c, n = m.group(1)[0], len(m.group(1))
    return re.match(r"^ {0,3}" + re.escape(c) + "{%d,}\\s*$" % n, line) is not None


def fence_end(lines, j):
    """The index of the line that closes the fence opened on line j, or None when it is not closed."""
    return next((k for k in range(j + 1, len(lines)) if closes(lines[k], lines[j])), None)


def contexts(lines):
    """Per line: "fence" (a fence line or inside one), "comment" (inside an HTML comment block) or "text".
    A fence opens on ``` or ~~~ (three or more, at most 3 spaces in front) and closes on the same
    character, at least as many, with nothing after it, as GitHub reads it."""
    ctx, opener, comment = [], None, False
    for l in lines:
        if comment:
            ctx.append("comment")
            comment = "-->" not in l
        elif opener is not None:
            ctx.append("fence")
            if closes(l, opener):
                opener = None
        elif opens(l):
            ctx.append("fence")
            opener = l
        elif re.match(r"^ {0,3}<!--", l):
            ctx.append("comment")
            comment = "-->" not in l[l.index("<!--") + 4:]
        else:
            ctx.append("text")
    return ctx


def screen_one(text):
    """(lines, contexts) from the title line to the first `---` line outside a fence and a comment, fold excluded."""
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ctx = contexts(lines)
    for i, l in enumerate(lines):
        if l == "---" and ctx[i] == "text":
            return lines[:i], ctx[:i]
    fail("no `---` fold in the spec")


def is_new_shape(lines, ctx):
    return any(c == "text" and ANY_BLOCK_HEADING.match(l) for l, c in zip(lines, ctx))


def heading_problem(n, l):
    """(block name, problem) for a text heading line that names a block; (None, None) for any other heading."""
    m = re.match(r"^ {0,3}(#{1,6})\s+(.*?)\s*$", l)
    if not m:
        return None, None
    title = re.sub(r"\s+#+$", "", m.group(2)).strip()
    for name, head in NEW_HEADING.items():
        if l.rstrip() == f"## {head}":
            return name, None
        if re.match(rf"{re.escape(head)}\b", title, re.I):
            if title.lower() != head.lower():
                why = "it has more words, so it is ambiguous"
            elif len(m.group(1)) != 2:
                why = f"it is a level-{len(m.group(1))} heading"
            elif title != head:
                why = "the case differs"
            elif l.startswith(" "):
                why = "it is indented"
            elif re.search(r"\s#+\s*$", m.group(2)):
                why = "it ends in closing `#` marks"
            else:
                why = "the space after `##` is not one space"
            return name, (f"line {n}: `{l.strip()}` is not read as `## {head}` ({why}); write the block heading as "
                          f"exactly `## {head}` and give any other section another name")
    return None, None


def setext_block(lines, ctx, i):
    """The block name when line i is the text of a setext heading (a text line over `===` or `---`
    that is not the fold) naming a block; else None."""
    if ctx[i] != "text" or not lines[i].strip() or i + 1 >= len(lines) or ctx[i + 1] != "text":
        return None
    if not SETEXT.match(lines[i + 1]) or ROW.match(lines[i]) or re.match(r"^ {0,3}#", lines[i]):
        return None
    m = re.match(r"^ {0,3}(" + BLOCK_NAMES + r")\b", lines[i], re.I)
    return m.group(1) if m else None


def block_body(lines, ctx, i, end, head):
    """((kind, body lines), None) for the one table or fence under the block heading on line i, read up to line
    `end` (the next heading); (None, problem) when there is none, or anything else stands under the heading."""
    j = i + 1
    while j < end and not lines[j].strip():
        j += 1
    if j == end:
        return None, f"`## {head}` has no table or fence under it; an empty block is one row `none`"
    if ctx[j] == "text" and ROW.match(lines[j]):
        k = j
        while k < end and ctx[k] == "text" and ROW.match(lines[k]):
            k += 1
        kind, body = "table", lines[j:k]
    elif ctx[j] == "fence" and opens(lines[j]):
        k = fence_end(lines, j)
        if k is None:
            return None, f"`## {head}`: the fence on line {j+1} is not closed before the `---` fold"
        kind, body = "fence", lines[j + 1:k]
        k += 1
    else:
        return None, (f"`## {head}`: line {j+1} `{lines[j].strip()[:60]}` comes before any table or fence; "
                      "under the heading goes one table or one fence")
    rest = [m for m in range(k, end) if lines[m].strip()]
    if rest:
        m = rest[0]
        return None, (f"`## {head}`: line {m+1} `{lines[m].strip()[:60]}` follows the {kind} and would not be "
                      f"frozen; under the heading goes one {kind} and nothing else before the next heading "
                      "(a row after a blank line, a row with no leading `|`, a second table or fence, or text)")
    return (kind, body), None


def scan_new(lines, ctx):
    """New shape, strict: {block name: ("table" | "fence", body lines, heading index)}; every problem
    raised together."""
    problems, found, named, heads = [], {}, set(), []
    for i, (l, c) in enumerate(zip(lines, ctx)):
        if c == "comment" and re.match(r"^\s*(<!--\s*)?#{1,6}\s+(" + BLOCK_NAMES + r")\b", l, re.I):
            problems.append(f"line {i+1}: `{l.strip()}` sits inside an HTML comment, which GitHub does not show; "
                            "delete the comment or move the block out of it")
        if c == "text" and CONTAINER_HEADING.match(l):
            problems.append(f"line {i+1}: `{l.strip()[:60]}` is a block heading inside a block quote or a list "
                            "item, which the freeze does not read; write the block heading at the left edge, "
                            "its table under it, outside any quote or list")
        if setext_block(lines, ctx, i):
            problems.append(f"line {i+1}: `{l.strip()[:60]}` over `{lines[i+1].strip()[:20]}` is a heading on "
                            "GitHub (an underlined heading), which the freeze does not read as a block heading; "
                            "write it as `## <name>` with a blank line above any `---`")
        if c != "text" or not re.match(r"^ {0,3}#{1,6}(\s|$)", l):
            continue
        heads.append(i)
        name, problem = heading_problem(i + 1, l)
        if problem:
            problems.append(problem)
            named.add(name)
        elif name in found:
            problems.append(f"`## {NEW_HEADING[name]}` appears twice in screen one (lines {found[name]+1} and {i+1}); "
                            "one heading per block")
        elif name:
            found[name] = i
    spans = {}
    for name, i in found.items():
        end = next((h for h in heads if h > i), len(lines))
        span, problem = block_body(lines, ctx, i, end, NEW_HEADING[name])
        if problem:
            problems.append(problem)
            continue
        spans[name] = span + (i,)
    for name, head in NEW_HEADING.items():
        if name not in found and name not in named:
            problems.append(f"no `## {head}` block in screen one; every block is required (an empty one is a row `none`)")
    if lines and lines[-1].strip() and not ROW.match(lines[-1]):    # under a table row GitHub draws a rule
        problems.append(f"line {len(lines)}: the `---` fold sits right under a text line, which GitHub reads as a "
                        "heading underline; put a blank line above the fold")
    if problems:
        raise Refused(problems)
    return spans


# ---------- tables and fences -----------------------------------------------------------------

def cells(row):
    """A table row's cells, stripped; `\\|` is a pipe inside a cell, not a column edge."""
    r = row.strip()
    r = r[1:] if r.startswith("|") else r
    r = r[:-1] if r.endswith("|") and not r.endswith("\\|") else r
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", r)]


def table_rows(body, head):
    """(header cells, data rows as cell lists) of a Markdown table."""
    rows = [cells(l) for l in body]
    if len(rows) < 2 or not all(re.fullmatch(r":?-+:?", c) for c in rows[1]):
        fail(f"`## {head}`: a table needs a header row and a `|---|` row")
    if len(rows) < 3:
        fail(f"`## {head}`: the table has a header and no row; an empty block is one row `none`")
    for r in rows[2:]:
        if len(r) != len(rows[0]):
            fail(f"`## {head}`: a table row has {len(r)} cells, the header {len(rows[0])}: {' | '.join(r)}")
    keys = [h.strip("`* ").lower() for h in rows[0]]
    dup = sorted({k for k in keys if keys.count(k) > 1})
    if dup:
        fail(f"`## {head}`: the table has two `{dup[0]}` columns; name each column once")
    return rows[0], rows[2:]


def aligned(rows):
    """Table rows as lines at two spaces: each column padded to its widest cell, two spaces apart."""
    w = [max(len(r[k]) for r in rows) for k in range(len(rows[0]))]
    return ["  " + "  ".join(c.ljust(w[k]) for k, c in enumerate(r)).rstrip() for r in rows]


def table_block(name, header, rows):
    """A Terms or rule table as rules.md lines: id, rule, other columns, [source]; cells' whitespace collapsed."""
    head = NEW_HEADING[name]
    keys = [h.strip("`* ").lower() for h in header]
    want = RULE_COLUMN[name]
    if want not in keys:
        fail(f"`## {head}`: the table has no `{want}` column; the {'definition' if name == 'TERMS' else 'rule'} "
             "goes in a column with that heading")
    rule = keys.index(want)
    ids = [k for k, h in enumerate(keys) if h in ID_COLUMNS]
    src = [k for k, h in enumerate(keys) if h == "source"]
    rows = [[re.sub(r"\s+", " ", c).strip() for c in r] for r in rows]
    empty = lambda r: r[rule].lower() == "none" or [c.lower() for c in r if c] == ["none"]
    if any(empty(r) for r in rows):
        if len(rows) > 1:
            fail(f"`## {head}`: a `none` row means the block is empty; delete it or the other rows")
        return [DEFAULT_HEADING[name], "  none"]
    for r in rows:
        if not r[rule]:
            fail(f"`## {head}`: a row has an empty `{want}` cell: {' | '.join(r)}")
        for k in ids:
            if not ID_CELL.fullmatch(r[k]):
                fail(f"`## {head}`: `{r[k]}` in the `{header[k]}` column is not a row number; write 1, 1., ✔ 1 or D1")
        for k in src:
            if re.fullmatch(r"\[?\s*standing\s*\]?", r[k], re.I) or \
                    re.match(r"\[?\s*retired \d{4}-\d{2}-\d{2} by \d+\b", r[k], re.I):
                fail(f"`## {head}`: the source `{r[k]}` reads as a rules.md tag; name where the row comes from "
                     "(a ticket, a file and line, a dated message)")
        for c in r:
            if TAG.search(c):
                fail(f"`## {head}`: `{c}` holds `[standing]` or `[retired`; the freeze and lead-1's amendments write "
                     "those tags, never the spec")
    if name == "TERMS":
        order = list(range(len(header)))
    else:
        order = ids + [rule] + [k for k in range(len(header)) if k not in ids and k != rule and k not in src] + src
    out = [[f"[{r[k]}]" if k in src and r[k] and not r[k].startswith("[") else r[k] for k in order] for r in rows]
    return [DEFAULT_HEADING[name]] + aligned(out)


def indent(body):
    """A line at the left edge gets two spaces in front; an indented line is copied as is."""
    return [b if b.startswith("  ") else "  " + b for b in body]


def fence_block(name, body):
    """A Terms or rule fence as rules.md lines: its heading line, then its rows at two spaces."""
    head = NEW_HEADING[name]
    body = [b for b in body if b.strip()]
    for b in body:
        if re.match(r"^ *\t", b):
            fail(f"`## {head}`: `{b.strip()[:60]}` is indented with a tab; indent with spaces")
        if TAG.search(b):
            fail(f"`## {head}`: `{b.strip()[:60]}` holds `[standing]` or `[retired`; the freeze and lead-1's "
                 "amendments write those tags, never the spec")
    if body and re.match(rf"^{re.escape(name)}(  |$)", body[0]):
        heading, rows = body[0], body[1:]                      # its own heading line inside the fence
    elif name in CAPTION and body and body[0].strip().rstrip(":").strip().lower() == CAPTION[name]:
        heading, rows = DEFAULT_HEADING[name], body[1:]       # the caption is the heading, never a rule
    elif len(body) > 1 and not body[0].startswith((" ", "\t")) and body[0].rstrip().endswith(":") \
            and all(b.startswith((" ", "\t")) for b in body[1:]):
        heading, rows = f"{name}  {body[0].strip()}", body[1:]  # a caption line: "stop and ask before:"
    else:
        heading, rows = DEFAULT_HEADING[name], body
    if not rows:
        fail(f"`## {head}`: the fence has no row; an empty block is one row `none`")
    if name in CAPTION:
        depth = lambda b: len(b) - len(b.lstrip(" \t"))
        for a, b in zip(rows, rows[1:]):
            if depth(b) > depth(a):
                fail(f"`## {head}`: `{b.strip()[:60]}` is indented deeper than the row above it, as a wrapped rule; "
                     "write each rule on one line")
    return [heading] + indent(rows)


def new_block(spans, name):
    """New shape: the rules.md lines of one block (heading line first)."""
    kind, body, _ = spans[name]
    if kind == "table":
        return table_block(name, *table_rows(body, NEW_HEADING[name]))
    return fence_block(name, body)


def old_block(lines, name, required=True):
    """Old shape: (position, its heading line and the indented lines under it)."""
    hits = [i for i, l in enumerate(lines) if l.startswith(name + "  ")]
    if len(hits) > 1:
        fail(f"{name} appears {len(hits)} times in screen one (lines {', '.join(str(i + 1) for i in hits)}); "
             "one heading per block")
    if not hits:
        if not required:
            return None
        fail(f"no {name} block in screen one")
    i = hits[0]
    out, j = [lines[i]], i + 1
    while j < len(lines) and lines[j].startswith("  "):
        if TAG.search(lines[j]):
            fail(f"{name}: line {j+1} `{lines[j].strip()[:60]}` holds `[standing]` or `[retired`; the freeze and "
                 "lead-1's amendments write those tags, never the spec")
        out.append(lines[j])
        j += 1
    k = j
    while k < len(lines) and not lines[k].strip():
        k += 1
    if k < len(lines) and lines[k][:1] in (" ", "\t"):
        fail(f"{name}: line {k+1} `{lines[k].strip()[:60]}` would not be frozen: a block line after a blank line, or "
             "indented with a tab or one space, ends the block; indent every line two spaces, no blank line inside")
    return i, out


# ---------- the checks ------------------------------------------------------------------------

def code_span(c):
    """The text of a cell that is exactly one code span (`x`, or `` x `y` `` for a command holding a backtick); else None."""
    m = re.fullmatch(r"(`+)(.+?)\1", c, re.S)
    if not m or re.search(rf"(?<!`){m.group(1)}(?!`)", m.group(2)):
        return None
    inner = m.group(2)
    return inner[1:-1] if len(inner) > 2 and inner[0] == inner[-1] == " " else inner


def checks_table(header, rows):
    """A checks table as label lines: one `proves done`, `pass` and `on main` line per row, in row order.

    The columns are named command (or proves done), pass and on main, each once. A cell that is
    one code span is read without its backticks, so a command can be written as code in the table;
    a command cell that starts with a backtick and is not one code span is refused.
    """
    names = {"command": "proves done", "proves done": "proves done", "pass": "pass", "on main": "on main"}
    col = {}
    for k, h in enumerate(header):
        label = names.get(h.strip("`* ").lower())
        if not label:
            fail(f"checks table: column `{h}` is not command, pass or on main")
        if label in col:
            fail(f"checks table: `{header[col[label]]}` and `{h}` are the same column; name it once")
        col[label] = k
    missing = [x for x in GATE_REQUIRED_NEW if x not in col]
    if missing:
        fail(f"checks table has no {', '.join(missing)} column")
    if len(rows) == 1 and rows[0][col["proves done"]].strip("` ").lower() == "none":
        fail("`## Checks` needs at least one command; `none` is not one")
    for r in rows:
        if r[col["proves done"]].startswith("`") and code_span(r[col["proves done"]]) is None:
            fail(f"checks table: the command {r[col['proves done']]} is not one code span; write the whole command "
                 "in one code span (``` `` ``` around a command that holds a backtick), or none")
    unwrap = lambda c: c if code_span(c) is None else code_span(c)
    out = []
    for label in GATE_REQUIRED_NEW:
        for n, r in enumerate(rows):
            out.append(("  " + label).ljust(16) + unwrap(r[col[label]]) if n == 0 else " " * 16 + unwrap(r[col[label]]))
    return out


def checks_items(lines, spans):
    """(body lines, gate_run items, required labels, reader problems) of screen one's checks block, or None
    when an old-shape spec has none."""
    if spans is not None:
        kind, body, _ = spans["GATE"]
        if kind == "table":
            body = checks_table(*table_rows(body, "Checks"))
        else:
            body = [b for b in body if b.strip()]
            body = body[1:] if body and re.match(r"^GATE\b", body[0]) else body
            if any(not b.startswith(" ") for b in body):
                body = ["  " + b for b in body]             # labels at the left edge move to two spaces
        required = GATE_REQUIRED_NEW
    else:
        found = old_block(lines, "GATE", required=False)
        if not found:
            return None
        body, required = found[1][1:], GATE_LABELS
    problems = []
    items = gate_run.gate_lines("\n".join(body), problems)
    return body, items, required, problems


def checks_rows(text):
    """[(command, pass line, on main)] of screen one's checks block, by position; [] when there is none."""
    lines, ctx = screen_one(text)
    spans = scan_new(lines, ctx) if is_new_shape(lines, ctx) else None
    found = checks_items(lines, spans)
    return item_rows(found[1]) if found else []


def item_rows(items):
    """[(command, pass line, on main)] from gate_run items, by position."""
    by = {lab: [v for _, l, v in items if l == lab and v] for lab in GATE_REQUIRED_NEW}
    n = len(by["proves done"])
    pad = lambda xs: (xs + [""] * n)[:n]
    return list(zip(by["proves done"], pad(by["pass"]), pad(by["on main"])))


def unchecked_words(p):
    """A pass line with words and no quoted string; [] otherwise.

    gate_run.py checks only `exit N` and each "quoted string", so `exit 0, 0 failed` goes green on
    exit 0 whatever the run prints. Refused at the freeze only: a hand-written legacy gate.md still runs.
    """
    if '"' in p or not re.search(r"[A-Za-z]", re.sub(r"\bexit\s+\d+\b", "", p, flags=re.I)):
        return []
    return ['words with no "quoted string": gate-run checks only the exit code and quoted strings, so these '
            "words are never checked; quote each output fact as main's run printed it, or write `exit N` alone"]


def gate_block(lines, spans):
    """gate.md's GATE BLOCK lines from screen one's checks block, or None when an old-shape spec has none.

    The lines are read with gate_run's reader, so gate.md holds exactly what gate-run.sh will run.
    The `on main` lines are dropped, every other line is copied as is.
    """
    found = checks_items(lines, spans)
    if not found:
        return None
    body, items, required, problems = found
    reasons = [f"checks: {p}" for p in problems]
    count = Counter(lab for _, lab, val in items if val)
    missing = [k for k in required if count[k] == 0]
    if missing:
        reasons.append(f"checks block has no {', '.join(missing)} line")
    if not count["proves done"] == count["pass"] == count["on main"]:
        reasons.append(f"checks block: {count['proves done']} proves done, {count['pass']} pass, {count['on main']} on main "
                       "lines; each command needs its pass line and main's output at the same position")
    for _, lab, val in items:
        if lab == "pass" and val:
            reasons += [f"checks: pass line `{val}`: {p}" for p in gate_run.pass_problems(val) + unchecked_words(val)]
    if reasons:
        raise Refused(reasons)
    drop = {n for n, lab, _ in items if lab == "on main"}
    return ["GATE BLOCK"] + [l for n, l in enumerate(body, 1) if n not in drop and l.strip()]


# ---------- the whole spec --------------------------------------------------------------------

def parse(text):
    """Screen one, strictly: {"title", "new", "blocks": {name: rules.md lines}, "order": [...], "gate": lines | None}."""
    lines, ctx = screen_one(text)
    title = next((l for l in lines if l.startswith("# ")), None)
    reasons = [] if title else ["no title line (`# <ticket key>: <title>`) in screen one"]
    new = is_new_shape(lines, ctx)
    spans = None
    if new:
        try:
            spans = scan_new(lines, ctx)
        except Refused as e:
            raise Refused(reasons + e.reasons)
    blocks, pos = {}, {}
    for name in ROW_BLOCKS:
        try:
            if new:
                blocks[name], pos[name] = new_block(spans, name), spans[name][2]
            else:
                pos[name], blocks[name] = old_block(lines, name)
        except Refused as e:
            reasons += e.reasons
    gate = None
    try:
        gate = gate_block(lines, spans)
    except Refused as e:
        reasons += e.reasons
    if reasons:
        raise Refused(reasons)
    order = sorted(RULE_BLOCKS, key=lambda b: pos[b])   # the spec's order
    return {"title": title, "new": new, "blocks": blocks, "order": order, "gate": gate}


def standing_block():
    """The fenced standing list of one-way.md: heading line and the [standing] lines, verbatim."""
    text = open(ONE_WAY, encoding="utf-8").read()
    m = re.search(r"\n```\n(ONE-WAY  stop and ask before:\n(?:  .*\n)+)```", text)
    if not m:
        fail(f"no standing block in {ONE_WAY}")
    return m.group(1).rstrip("\n").split("\n")


def lane_of(title):
    """"# ATL-42: retry failed nightly imports" or "# ATL-42 · atlas · …" -> ATL-42."""
    t = title[2:].strip()
    return t.split(" · ")[0].strip() if " · " in t else t.split(":")[0].strip()


def record_folder(text, arg):
    """The record folder: the argument, else the old shape's `record:` line; both must agree."""
    m = re.search(r"^record: (\S+)", text, re.M)
    line = os.path.expanduser(m.group(1)).rstrip("/") if m else None   # a `~/...` still lands outside the worktree
    given = os.path.expanduser(arg).rstrip("/") if arg else None
    if given and line and os.path.abspath(given) != os.path.abspath(line):
        fail(f"record folder {given} is not the spec's `record:` line {line}; pass the same folder")
    record = given or line
    if not record:
        fail("no record folder: run freeze-rules.sh <spec path> <record folder>")
    return record


# ---------- --check against a record folder ---------------------------------------------------

def norm(s):
    return " ".join(s.split())


def records_root():
    """The fleet's record folders: FLEET_RECORDS, else FLEET_HOME/records."""
    return os.environ.get("FLEET_RECORDS") or os.path.join(FLEET_HOME, "records")


def _listed(path):
    """The <project>/<rung> lines of one legacy listing; [] when the file is absent."""
    try:
        return [l.strip().rstrip("/") for l in open(path, encoding="utf-8")
                if l.strip() and not l.lstrip().startswith("#")]
    except OSError:
        return []


def legacy_files():
    """The two legacy listings: the one shipped in shared/records and the one in the settings home
    (settings_fleet_home(), never the environment)."""
    return [LEGACY, os.path.join(settings_fleet_home(), "legacy-records.txt")]


def legacy(record, listing=None):
    """True when the record folder is <records>/<project>/<rung> for a line <project>/<rung> of
    shared/records/legacy-records.txt or of legacy-records.txt in the settings home (or of the listing given
    alone). The same two names under any other folder are not listed."""
    listed = [x for f in ([listing] if listing else legacy_files()) for x in _listed(f)]
    here = os.path.realpath(os.path.expanduser(record))
    return any(os.path.realpath(os.path.join(records_root(), x)) == here for x in listed)


def pre_log(record):
    """True when the record folder froze before stop1.log existed (shared/frozen-before-stop1-log.txt): the
    checks tied to the STOP 1 commit (shared/frozen.py chain_reasons, screen one at the approved commit,
    the dated `## Amendments`, dr-check's spec read) skip it; every other check still runs."""
    return legacy(record, PRE_LOG)


def rules_rows(text):
    """rules.md's rung rows: ([(section, row, line)] required, {(section, row)} optional), whitespace collapsed.

    The standing lines are left out. A row ending in `[retired <date> by <line>]` and a row under an
    `<KIND>  amended <date>:` heading are optional: the spec may carry them or not."""
    required, optional, sec, amended = [], set(), None, False
    for n, l in enumerate(text.split("\n"), 1):
        m = re.match(r"^(TERMS|ONE-WAY|DECIDED|REJECTED)\b(.*)$", l)
        if m:
            sec, amended = m.group(1), bool(re.search(r"\bamended \d{4}-\d{2}-\d{2}", m.group(2)))
            continue
        if not sec or not l.startswith("  ") or not l.strip() or "[standing]" in l:
            continue
        row = norm(RETIRED.sub("", l.rstrip()))
        if amended or RETIRED.search(l.rstrip()):
            optional.add((sec, row))
        else:
            required.append((sec, row, n))
    return required, optional


def history(record):
    """[(kind, was hex, copy file name)] from <record>/frozen.sha256's history lines, oldest first."""
    try:
        text = open(os.path.join(record, "frozen.sha256"), encoding="utf-8").read()
    except OSError:
        return []
    out = []
    for l in text.split("\n"):
        m = re.match(r"^history\s+.*? · (rules|gate) · .* · was ([0-9a-f]{64}) · copy (\S+)\s*$", l)
        if m:
            out.append(m.groups())
    return out


def compare_record(parsed, record):
    """Reasons the spec's rows differ from <record>/rules.md and, when the freeze wrote it, <record>/gate.md."""
    reasons = []
    rules_path = os.path.join(record, "rules.md")
    if os.path.exists(rules_path):
        spec = Counter((name, norm(r)) for name in ROW_BLOCKS for r in parsed["blocks"][name][1:])
        required, optional = rules_rows(open(rules_path, encoding="utf-8").read())
        have = Counter((s, r) for s, r, _ in required)
        where = {(s, r): n for s, r, n in required}
        for (s, r) in (have - spec):
            reasons.append(f"rules.md line {where[(s, r)]} ({s}) is not in the spec: {r}")
        for (s, r) in (spec - have):
            if (s, r) not in optional:
                reasons.append(f"the spec's {s} row is not in rules.md: {r}")
    gate_path = os.path.join(record, "gate.md")
    if parsed["gate"] and os.path.exists(gate_path):
        g = open(gate_path, encoding="utf-8").read()
        if not re.match(r"^gate · .* · frozen at \S+ · ", g):
            print(f"freeze-rules --check: note: {gate_path} was not written by the freeze; Checks not compared",
                  file=sys.stderr)
        else:
            if re.search(r"^\s*#\s*Amended\b", g, re.M):
                # an amended gate.md is checked through the copy the first amendment kept, the gate as it froze
                copies = [c for k, _, c in history(record) if k == "gate"]
                base = os.path.join(record, copies[0]) if copies else None
                if not base:
                    reasons.append(f"{gate_path} has `# Amended` lines and frozen.sha256 has no gate history line: "
                                   "the amendment did not go through shared/amend-frozen.sh")
                    return reasons
                if not os.path.exists(base):
                    reasons.append(f"{base}, the gate as it froze (frozen.sha256's first gate history line), is gone")
                    return reasons
                g = open(base, encoding="utf-8").read()
            sc, sp = gate_run.read_gate("\n".join(parsed["gate"]))
            gc, gp = gate_run.read_gate(g)
            for what, a, b in (("command", sc, gc), ("pass line", sp, gp)):
                if len(a) != len(b):
                    reasons.append(f"gate.md has {len(b)} {what}s, the spec's Checks {len(a)}")
                for n, (x, y) in enumerate(zip(a, b), 1):
                    if norm(x) != norm(y):
                        reasons.append(f"gate.md {what} {n} `{y}` is not the spec's `{x}`")
    return reasons


def check_main(argv):
    """--check <spec|-> [--path <repo path>] [--record <folder>]: exit 0 ok, 2 with one reason per line."""
    opts, args, it = {}, [], iter(argv)
    for a in it:
        if a in ("--path", "--record"):
            opts[a] = next(it, None)
        else:
            args.append(a)
    if len(args) != 1 or None in opts.values():
        print("usage: freeze_rules.py --check <spec|-> [--path <repo path>] [--record <folder>]")
        return 2
    record = opts.get("--record")
    name = opts.get("--path") or args[0]
    if record and legacy(record):
        print(f"freeze-rules --check: note: {record} is listed in {LEGACY}; {name} not checked", file=sys.stderr)
        return 0
    try:
        text = sys.stdin.read() if args[0] == "-" else open(args[0], encoding="utf-8").read()
        parsed = parse(text)
        reasons = compare_record(parsed, os.path.expanduser(record)) if record else []
    except Refused as e:
        reasons = e.reasons
    except OSError as e:
        reasons = [f"cannot read {name}: {e.strerror}"]
    for r in reasons:
        print(r)
    return 2 if reasons else 0


def main(argv):
    if len(argv) > 1 and argv[1] == "--check":
        return check_main(argv[2:])
    if "--chore" in argv[1:]:
        rest = [a for a in argv[1:] if a not in ("--dump", "--chore")]
        if len(rest) != 1:
            print("usage: freeze_rules.py --chore <record folder>/handoff.md [--dump]")
            return 2
        try:
            return chore_freeze(rest[0], "--dump" in argv[1:])
        except Refused as e:
            for r in e.reasons:
                print(f"freeze-rules --chore: {r}", file=sys.stderr)
            return 2
    args, approved, it = [], None, iter(argv[1:])
    for a in it:
        if a == "--approved":
            approved = next(it, None) or "-"
        elif a != "--dump":
            args.append(a)
    if not args or len(args) > 2 or approved == "-":
        print(__doc__)
        return 2
    try:
        return freeze(args[0], args[1] if len(args) > 1 else None, "--dump" in argv, approved)
    except Refused as e:
        for r in e.reasons:
            print(f"freeze-rules: {r}", file=sys.stderr)
        return 2


def screen_change(was_text, now_text):
    """None when screen one reads the same in both texts, line for line; else (line number, was, is)."""
    try:
        was = screen_one(was_text)[0]
    except Refused:
        was = None
    now = screen_one(now_text)[0]
    if was == now:
        return None
    if was is None:
        return (1, "(no `---` fold)", now[0] if now else "(nothing)")
    n = next((i for i, (a, b) in enumerate(zip(was, now)) if a != b), min(len(was), len(now)))
    return (n + 1, was[n] if n < len(was) else "(nothing)", now[n] if n < len(now) else "(nothing)")


def approved_check(spec, text, approved):
    """The spec's repo path; refused when screen one at HEAD is not screen one at the approved commit."""
    git = lambda *a: subprocess.run(["git", *a], capture_output=True, text=True)
    path = git("ls-files", "--full-name", "--", spec).stdout.strip()
    if not path:
        fail(f"{spec} is not in git")
    if git("cat-file", "-e", f"{approved}^{{commit}}").returncode:
        fail(f"--approved {approved} is not a commit in this repo; pass the sha on the STOP 1 report's spec line")
    r = git("show", f"{approved}:{path}")
    if r.returncode:
        fail(f"{path} is not in commit {approved}, the commit the owner approved")
    try:
        screen_one(r.stdout)
    except Refused:
        fail(f"{path} at {approved} has no `---` fold, so it is not the screen one the owner approved")
    change = screen_change(r.stdout, text)
    if change:
        n, a, b = change
        fail(f"screen one changed after {approved}, the commit the owner approved: line {n} was `{a[:60]}`, is "
             f"`{b[:60]}`. An edit above the fold goes back to the owner: a new STOP 1 at the new commit, or a card. "
             "Edits below the fold are free")
    return path


def approved_in_log(record, path, approved):
    """Refused unless <record>/stop1.log, written by the message gate when a STOP 1 report passes, holds
    a line for this spec path whose sha is --approved, and it is the newest line for that path."""
    log = os.path.join(record, "stop1.log")
    full = subprocess.run(["git", "rev-parse", "-q", "--verify", f"{approved}^{{commit}}"], capture_output=True,
                          text=True).stdout.strip()
    try:
        text = open(log, encoding="utf-8").read()
    except OSError:
        text = ""
    clean = lambda s: s[2:] if s.startswith("./") else s
    shas = [m.group(2) for m in re.finditer(r"· STOP 1 · spec (\S+) @ ([0-9a-f]{40}) ·", text) if clean(m.group(1)) == path]
    if not shas:
        fail(f"no STOP 1 for {path} in {log}: the message gate writes that line when a STOP 1 report naming the "
             "record folder and the spec line passes; send STOP 1, then freeze with its sha")
    if shas[-1] != full:
        fail(f"--approved {approved} is not the sha of the newest STOP 1 for {path} ({shas[-1][:7]}, in {log}); "
             "pass the sha on the STOP 1 report the owner answered")


def log_slug(cwd):
    """The session-log folder name Claude Code gives a session started in <cwd>: every character that is
    not a letter or a digit becomes `-` (/home/me/a/.claude/w1 -> -home-me-a--claude-w1)."""
    return re.sub(r"[^A-Za-z0-9]", "-", cwd)


def entry_text(e):
    """The typed text of a user entry: a string, or the text blocks of a list (never a tool result)."""
    c = (e.get("message") or {}).get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "\n".join(b.get("text") or "" for b in c if isinstance(b, dict) and b.get("type") == "text")
    return ""


def stop1_time(record, path):
    """(epoch of the newest stop1.log line for <path>, the line's `YYYY-MM-DD HH:MM`). The message gate
    writes local time to the minute, so the line stands for the whole minute: the owner's word counts from
    the next minute on."""
    log = os.path.join(record, "stop1.log")
    try:
        lines = open(log, encoding="utf-8").read().split("\n")
    except OSError:
        lines = []
    clean = lambda s: s[2:] if s.startswith("./") else s
    newest = None
    for l in lines:
        m = re.match(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}) · STOP 1 · spec (\S+) @ [0-9a-f]{40} ·", l)
        if m and clean(m.group(2)) == path:
            newest = m.group(1)
    if not newest:
        fail(f"no STOP 1 for {path} in {log}, so no time to read the owner's word after")
    return time.mktime(time.strptime(newest, "%Y-%m-%d %H:%M")), newest


def typed_line(line):
    """One line of a typed message as owner_ok and amend_ok match it: stripped, one trailing option tag such
    as "(a)" or "(b)" dropped, then one pair of surrounding straight or curly quotes dropped. The owner often
    answers a card by quoting its line and adding the option: "ATL-42 r1 amend ok ATL-42 C2" (a). Nothing
    else is dropped, so a line with any other word still does not match."""
    s = re.sub(r"\s*\([A-Za-z0-9]\)$", "", line.strip()).strip()
    if len(s) >= 2 and s[0] in "\"'“‘" and s[-1] in "\"'”’":
        s = s[1:-1].strip()
    return s


def human_matches(folders, after, match):
    """(count of entries typed by a person, [{file, line, timestamp, epoch, text}] for each such entry from
    epoch <after> on whose text <match>(text) accepts), over <folder>/*.jsonl. A typed entry is a user entry
    with origin.kind "human"; a relay (origin.kind "peer"), a compact summary, a meta entry and a side chain
    never count. Files are read line by line; a line that is not JSON is skipped. Shared by owner_ok (the
    spec freeze) and amend_ok (a rules.md amendment, or a gate.md amendment that adds a Checks line)."""
    humans, hits = 0, []
    for d in folders:
        for f in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
            try:
                fh = open(f, "rb")
            except OSError:
                continue
            with fh:
                for n, raw in enumerate(fh, 1):
                    if b'"human"' not in raw:
                        continue
                    try:
                        e = json.loads(raw)
                    except ValueError:
                        continue
                    if not isinstance(e, dict):
                        continue
                    o = e.get("origin")
                    if e.get("type") != "user" or not isinstance(o, dict) or o.get("kind") != "human":
                        continue
                    if e.get("isMeta") or e.get("isCompactSummary") or e.get("isSidechain"):
                        continue
                    humans += 1
                    try:
                        ts = datetime.fromisoformat(str(e.get("timestamp")).replace("Z", "+00:00")).timestamp()
                    except ValueError:
                        continue
                    if ts < after:
                        continue
                    text = entry_text(e)
                    if match(text):
                        hits.append({"file": f, "line": n, "timestamp": e.get("timestamp"), "epoch": ts,
                                     "text": text.strip()})
    return humans, hits


def lead_folders(lead_cwd, lead_old_cwd):
    """lead-1's folders to read: the live pair (LEAD_CWD, LEAD_OLD_CWD) when no lead_cwd is passed, else lead_cwd
    and the optional lead_old_cwd (so a test never reads the real home)."""
    if lead_cwd:
        return [lead_cwd] + ([lead_old_cwd] if lead_old_cwd else [])
    return [LEAD_CWD] + ([LEAD_OLD_CWD] if LEAD_OLD_CWD else [])


def owner_ok(record, path, ic_cwd, root=None, lead_cwd=None, lead_old_cwd=None):
    """The owner's "<lane> spec ok" or "<lane> r<n> spec ok", typed after the newest STOP 1 for <path>.

    Read from Claude Code's session logs, in lead-1's folder (lead_cwd, LEAD_CWD; before the move also
    lead_old_cwd, LEAD_OLD_CWD from migrate/agentmgmt-path) and the IC's (ic_cwd, the worktree the freeze runs in), each <root>/<log_slug(cwd)>/*.jsonl, <root> being
    SESSION_LOGS unless a test passes one. A match is a user entry with origin.kind "human" (a message
    relayed by lead-1 or another session is origin.kind "peer" and never counts; a compact summary,
    a meta entry and a side chain never count), a timestamp from the minute after the newest stop1.log
    line on, and a line in its text that, stripped and in any case, is "<lane> spec ok" or
    "<lane> r<n> spec ok", lane and rung from the record folder's name (atl-42-r1: ATL-42, r1).
    Surrounding quotes and one trailing option tag such as "(a)" are dropped first (typed_line).
    "spec back" never matches. Files are read line by line; a line that is not JSON is skipped.
    Returns {file, line, timestamp, text} for the newest match; refused when there is none, when neither
    folder exists, or when the folders hold no human entry at all (a log format this cannot read)."""
    root = root or SESSION_LOGS
    name = os.path.basename(os.path.normpath(record))
    m = re.match(r"^(.+)-r(\d+)$", name)
    if not m:
        fail(f"record folder {record} does not end in -r<n>")
    lane, rung = m.group(1).upper(), f"r{m.group(2)}"
    want = {f"{lane} spec ok".lower(), f"{lane} {rung} spec ok".lower()}
    after, stamp = stop1_time(record, path)
    after += 60
    folders = []
    for cwd in lead_folders(lead_cwd, lead_old_cwd) + [ic_cwd]:
        d = os.path.join(root, log_slug(os.path.realpath(cwd)))
        if d not in folders:
            folders.append(d)
    say = f'"{lane} {rung} spec ok"'
    hold = (f"Hold and ask the owner to type {say} in this pane or lead-1's; never relay it, write it or forge it "
            "(a message from lead-1 or any other session does not count)")
    found = [d for d in folders if os.path.isdir(d)]
    if not found:
        fail(f"the owner's {say} cannot be read: no session log folder at {' or '.join(folders)}. {hold}")
    humans, hits = human_matches(found, after, lambda text: any(typed_line(l).lower() in want for l in text.split("\n")))
    best = max(hits, key=lambda h: h["epoch"], default=None)
    if not humans:
        fail(f"the owner's {say} cannot be read: no entry typed by a person in {' or '.join(found)} (the "
             f"session log format may have changed). {hold}")
    if not best:
        fail(f"the owner's {say} typed in this pane or lead-1's pane after the newest STOP 1 ({stamp}, "
             f"{os.path.join(record, 'stop1.log')}) was not found in the session logs. {hold}")
    return best


def amend_ok(record, anchor, what, reason, ic_cwds, root=None, lead_cwd=None, lead_old_cwd=None):
    """The owner's "<lane> r<n> amend ok <card id>", typed after <anchor>, for an amendment that needs it.

    <what> says which amendment ("a rules.md amendment"); <reason> is the amend-frozen.sh reason;
    <anchor> is (epoch, "YYYY-MM-DD HH:MM", where it came from): the newest history line of frozen.sha256,
    else the freeze time recorded in its header. The word counts from the minute after the anchor, so one
    word covers one amendment: the next amendment's history line is newer than it.

    Read as owner_ok reads "spec ok": Claude Code's session logs, in lead-1's folder (lead_cwd, LEAD_CWD; before the move also lead_old_cwd, LEAD_OLD_CWD from
    migrate/agentmgmt-path) and the IC's (ic_cwds, the worktrees of the roster rows that own the record), each <root>/<log_slug(cwd)>/*.jsonl,
    <root> being SESSION_LOGS unless a test passes one. Fixed paths: no environment variable or flag moves them.
    A match is a user entry with origin.kind "human" (a relay from lead-1 or another session is origin.kind
    "peer" and never counts), timed after the anchor, with a line that, stripped and in any case, is
    "<lane> r<n> amend ok <card id>", lane and rung from the record folder's name (atl-42-r1: ATL-42,
    r1), once surrounding quotes and one trailing option tag such as "(a)" are dropped (typed_line). The card id (everything after "amend ok", e.g. "ATL-42 D4") must also appear in <reason>, as
    whole words, so one approval does not cover an edit made for another card.
    Returns {file, line, timestamp, text, card} for the newest match; refused when there is none, when no
    log folder exists, when the folders hold no human entry, or when no typed card id is in the reason."""
    root = root or SESSION_LOGS
    name = os.path.basename(os.path.normpath(record))
    m = re.match(r"^(.+)-r(\d+)$", name)
    if not m:
        fail(f"record folder {record} does not end in -r<n>")
    lane, rung = m.group(1).upper(), f"r{m.group(2)}"
    after, stamp, source = anchor
    after += 60
    folders = []
    for cwd in lead_folders(lead_cwd, lead_old_cwd) + list(ic_cwds):
        d = os.path.join(root, log_slug(os.path.realpath(cwd)))
        if d not in folders:
            folders.append(d)
    say = f'"{lane} {rung} amend ok <card id>"'
    where = "lead-1's pane" + (" or the IC's pane" if ic_cwds else "")
    hold = (f"The owner types {say} in {where}, after {stamp} ({source}), with the card that ruled this edit; the "
            "same card id goes in the amend-frozen.sh reason. A message relayed by lead-1 or any other session "
            "does not count, so never relay it, write it or forge it. Hold and ask the owner; nothing is re-hashed")
    head = f"{what} needs the owner's typed approval"
    phrase = re.compile(rf"{re.escape(lane)}\s+{re.escape(rung)}\s+amend\s+ok\s+(\S.*)", re.I)

    def cards(text):
        return [" ".join(x.group(1).split()) for x in (phrase.fullmatch(typed_line(l)) for l in text.split("\n")) if x]

    found = [d for d in folders if os.path.isdir(d)]
    if not found:
        fail(f"{head}, and it cannot be read: no session log folder at {' or '.join(folders)}. {hold}")
    humans, hits = human_matches(found, after, cards)
    if not humans:
        fail(f"{head}, and it cannot be read: no entry typed by a person in {' or '.join(found)} (the session log "
             f"format may have changed). {hold}")
    if not hits:
        fail(f"{head}, and {say} was not found in the session logs after {stamp}. {hold}")
    words = " ".join(reason.split()).lower()
    best = None
    for h in hits:
        for card in cards(h["text"]):
            if re.search(rf"(?<![A-Za-z0-9]){re.escape(card.lower())}(?![A-Za-z0-9])", words):
                if not best or h["epoch"] > best["epoch"]:
                    best = dict(h, card=card)
    if not best:
        typed = sorted({c for h in hits for c in cards(h["text"])})
        fail(f"{head}: the owner typed \"{lane} {rung} amend ok\" for {' / '.join(typed)}, and the reason names "
             f"none of them. Put the card id the owner typed in the reason. {hold}")
    return best


def owner_exempt(record):
    """True when the record folder is listed in shared/records/legacy-records.txt or in the settings home's
    legacy-records.txt, under the real records root (LIVE_RECORDS, never FLEET_RECORDS: an IC's environment
    cannot make a folder legacy)."""
    listed = [x for f in legacy_files() for x in _listed(f)]
    here = os.path.realpath(os.path.expanduser(record))
    return any(os.path.realpath(os.path.join(LIVE_RECORDS, x)) == here for x in listed)


def ic_top(spec):
    """The IC's worktree: the repo top level of the spec, else the freeze's cwd."""
    d = os.path.dirname(os.path.abspath(spec))
    top = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    return os.path.realpath(top or os.getcwd())


def freeze(spec, record_arg, dump, approved=None):
    text = open(spec, encoding="utf-8").read()
    parsed = parse(text)
    if not approved and not dump:
        fail("--approved <sha> is required: the sha on the STOP 1 report's spec line, the commit whose screen one "
             "the owner approved")
    lane = lane_of(parsed["title"])
    record = record_folder(text, record_arg)
    if chore_record(record):
        fail(f"{record} is a chore's record (frozen.sha256 has a chore line, or handoff.md has a `## Checks` table): "
             "a chore has no design spec and no STOP 1, and its gate froze from the handoff (freeze-rules.sh "
             "--chore). A spec freeze is never added to it; a rung with a spec gets its own record folder")
    rung = re.search(r"-r(\d+)$", record)
    if not rung:
        fail(f"record folder {record} does not end in -r<n>")
    gate = parsed["gate"]
    sha = spec_sha(spec)
    path = approved_check(spec, text, approved) if approved else \
        subprocess.run(["git", "ls-files", "--full-name", "--", spec], capture_output=True, text=True).stdout.strip()
    now = time.strftime("%Y-%m-%d %H:%M")
    out = [f"rules · {lane} r{rung.group(1)} · frozen at {sha} · {now}", ""] + parsed["blocks"]["TERMS"] + [""] \
        + standing_block() + [""]
    for b in parsed["order"]:
        out += parsed["blocks"][b] + [""]
    content = "\n".join(out)
    rules = os.path.join(record, "rules.md")
    gate_path = os.path.join(record, "gate.md")
    gate_out = [f"gate · {lane} r{rung.group(1)} · frozen at {sha} · {now}", ""] + gate + [""] if gate else None
    no_gate = (f"freeze-rules: WARNING no checks block (GATE) in screen one; {gate_path} was not written "
               "(an old-shape spec, from before the gate moved into the spec)")
    if dump:
        print(content)
        print(f"freeze-rules --dump: would write {rules}")
        if gate_out:
            print("\n".join(gate_out))
            print(f"freeze-rules --dump: would write {gate_path}")
        else:
            print(no_gate, file=sys.stderr)
        return 0
    if os.path.exists(rules):
        fail(f"{rules} exists; the rules are frozen. A change is a card to the owner, then lead-1 appends a dated amendment line, tags the old row [retired <date> by <line>] and runs shared/amend-frozen.sh")
    if gate_out and os.path.exists(gate_path):
        if not re.match(r"^gate · .* · frozen at \S+ · ", open(gate_path, encoding="utf-8").read()):
            fail(f"{gate_path} exists and the freeze did not write it (no `gate · ... · frozen at` header): a gate.md "
                 "is never copied by hand. Delete it, then run the freeze again")
        fail(f"{gate_path} exists; the gate is frozen. A line that cannot pass on origin/main is amended by lead-1 in gate.md, under a dated # Amended header line, then shared/amend-frozen.sh")
    if os.path.exists(os.path.join(record, "frozen.sha256")):
        fail(f"{os.path.join(record, 'frozen.sha256')} exists; the rung is frozen")
    approved_in_log(record, path, approved)
    if not owner_exempt(record):
        owner_ok(record, path, ic_top(spec))
    os.makedirs(record, exist_ok=True)
    open(rules, "w", encoding="utf-8").write(content)
    if gate_out:
        open(gate_path, "w", encoding="utf-8").write("\n".join(gate_out))
    import frozen   # here, not at the top: frozen imports this module
    frozen.write_frozen(record, f"frozen · {lane} r{rung.group(1)} · {now}", path, approved)
    dr = os.path.join(record, "decision-record.md")
    if os.path.exists(dr):
        t = open(dr, encoding="utf-8").read()
        t = re.sub(r"^rules: .*$", f"rules: {sha}  (rules.md, frozen {now})", t, count=1, flags=re.M)
        open(dr, "w", encoding="utf-8").write(t)
    print(out[0])
    print(rules)
    if gate_out:
        print(gate_out[0])
        print(gate_path)
    else:
        print(no_gate, file=sys.stderr)
    print(os.path.join(record, "frozen.sha256"))
    return 0


# ---------- a chore: no spec, no STOP 1; the gate from the handoff's Checks ---------------------

def handoff_lines(path):
    text = open(path, encoding="utf-8").read()
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return text, lines, contexts(lines)


def checks_headings(lines, ctx):
    """[(line index, problem or None)] for each text heading naming the Checks block, well formed or not."""
    out = []
    for i, (l, c) in enumerate(zip(lines, ctx)):
        if c == "text" and re.match(r"^ {0,3}#{1,6}(\s|$)", l):
            name, problem = heading_problem(i + 1, l)
            if name == "GATE":
                out.append((i, problem))
    return out


def chore_record(record):
    """True when the record folder is a chore's: frozen.sha256 has a chore line, or handoff.md has a
    `## Checks` heading written exactly so (a rung's handoff has none: its checks are on the spec's screen
    one; a rung's `### Checks lead-1 ran` or `## Checks and balances` is not one)."""
    try:
        if re.search(r"^chore\s+\S", open(os.path.join(record, "frozen.sha256"), encoding="utf-8").read(), re.M):
            return True
    except OSError:
        pass
    try:
        _, lines, ctx = handoff_lines(os.path.join(record, "handoff.md"))
    except OSError:
        return False
    return any(p is None for _, p in checks_headings(lines, ctx))


def chore_read(handoff):
    """(title, GATE BLOCK lines) of a chore's handoff, read strictly: a title line; one CHAIN block; no line
    anywhere that names a design spec step, STOP 1 or a spec freeze; one `## Checks` heading with one table under it
    (command, pass, on main) read as a spec's Checks table is, with the same pass-line rules; no placeholder
    `on main` cell. Refused with every reason together."""
    text, lines, ctx = handoff_lines(handoff)
    problems = []
    title = lines[0] if lines and lines[0].startswith("# ") else None
    if not title:
        problems.append("the first line is not the handoff's title (`# <LANE> · <project> · chore, <what> · <IC> · "
                        "<date time>`)")
    chains = [i for i, (l, c) in enumerate(zip(lines, ctx)) if c == "text" and re.match(r"^CHAIN\b", l)]
    if not chains:
        problems.append("no CHAIN block: a chore's handoff carries its CHAIN, numbered steps with no design spec "
                        "step and no STOP 1")
    elif len(chains) > 1:
        problems.append(f"CHAIN appears {len(chains)} times (lines {', '.join(str(i + 1) for i in chains)}); one "
                        "CHAIN block")
    heads = [i for i, (l, c) in enumerate(zip(lines, ctx)) if c == "text" and re.match(r"^ {0,3}#{1,6}(\s|$)", l)]
    # every line, not the CHAIN block alone: a blank or tab-indented line inside the CHAIN, a MODE line, the
    # report shape or a fence never hides a spec step or a STOP 1 the IC would read as holding
    chain = (chains[0], next((h for h in heads if h > chains[0]), len(lines))) if len(chains) == 1 else (-1, -1)
    for n, l in enumerate(lines):
        m = SPEC_STEP.search(l)
        if m:
            where = "CHAIN line" if chain[0] <= n < chain[1] else "line"
            problems.append(f"{where} {n + 1} `{l.strip()[:60]}` names `{m.group(0)}`: a chore has no design spec "
                            "and no STOP 1, and its handoff names neither anywhere (MODE, OPEN, the report shape "
                            "included). A rung with a spec freezes from the spec (freeze-rules.sh <spec> <record> "
                            "--approved <sha>), never with --chore")
    found = checks_headings(lines, ctx)
    problems += [p for _, p in found if p]
    good = [i for i, p in found if not p]
    gate = None
    if not found:
        problems.append("no `## Checks` table: a chore's gate is the handoff's `## Checks` table, columns command, "
                        "pass and on main, each command run once by lead-1 on origin/main before the freeze")
    elif len(good) > 1:
        problems.append(f"`## Checks` appears {len(good)} times (lines {', '.join(str(i + 1) for i in good)}); one "
                        "heading")
    elif good:
        i = good[0]
        end = next((h for h in heads if h > i), len(lines))
        span, problem = block_body(lines, ctx, i, end, "Checks")
        if problem:
            problems.append(problem)
        elif span[0] != "table":
            problems.append("`## Checks` in a handoff is one table (command, pass, on main), not a fence")
        else:
            spans = {"GATE": span + (i,)}
            try:
                found_items = checks_items(lines, spans)
                for n, (cmd, _, main) in enumerate(item_rows(found_items[1]), 1):
                    if PLACEHOLDER.match(main or ""):
                        problems.append(f"Checks row {n} `{cmd}`: on main is `{main}`, a placeholder; lead-1 runs the "
                                        "command once on origin/main and writes what it printed")
                gate = gate_block(lines, spans)
            except Refused as e:
                problems += e.reasons
    if problems:
        raise Refused(problems)
    return title, gate


def chore_freeze(handoff, dump):
    """lead-1's freeze of a chore at launch: rules.md (the standing block only), gate.md (the handoff's
    `## Checks`) and frozen.sha256 (a chore line, no spec line), in the handoff's record folder."""
    handoff = os.path.abspath(os.path.expanduser(handoff))
    record = os.path.dirname(handoff)
    if os.path.basename(handoff) != "handoff.md":
        fail(f"{handoff} is not a record folder's handoff.md; pass <record folder>/handoff.md")
    if not os.path.exists(handoff):
        fail(f"no {handoff}: lead-1 saves the chore's handoff in its record folder first")
    import frozen   # here, not at the top: frozen imports this module
    problems = []
    if not dump:
        who = frozen.roster_row(os.getcwd())   # FLEET_HOME/roster.md, never FLEET_ROSTER
        if who != "lead-1":
            where = f"{who}'s worktree" if who else "not lead-1's folder in FLEET_HOME/roster.md"
            fail(f"{os.getcwd()} is {where}: the chore freeze is lead-1's act at launch, run from lead-1's folder. "
                 "An IC never runs it; a change to a frozen chore gate is a card to lead-1")
    if legacy(record):
        fail(f"{record} is listed in {LEGACY}; its frozen files are not checked, so it is not frozen as a chore")
    text = open(handoff, encoding="utf-8").read()
    m = re.search(r"^RECORD\s+(\S+)", text, re.M)
    if not m:
        problems.append("the handoff has no `RECORD  <record folder>` line")
    elif os.path.realpath(os.path.expanduser(m.group(1))) != os.path.realpath(record):
        problems.append(f"the handoff's RECORD line names {m.group(1)}, not {record}, the folder it is saved in")
    if not dump:
        fz = os.path.join(record, "frozen.sha256")
        if os.path.exists(fz) and re.search(r"^spec\s+\S", open(fz, encoding="utf-8").read(), re.M):
            problems.append(f"{fz} has a spec line: this record froze from a design spec; --chore never writes over "
                            "a rung")
        for f in ("rules.md", "gate.md", "frozen.sha256"):
            if os.path.exists(os.path.join(record, f)):
                problems.append(f"{os.path.join(record, f)} exists; this record is frozen. A chore freezes once, "
                                "before launch; a change after is lead-1's amendment (shared/amend-frozen.sh)")
        pre = sorted(glob.glob(os.path.join(record, "*-pre-*.md")))
        if pre:
            problems.append(f"{pre[0]} exists: a frozen file was amended here, so this record was frozen before")
        if os.path.exists(os.path.join(record, SESSIONS)):
            first = open(os.path.join(record, SESSIONS), encoding="utf-8").readline().strip()
            problems.append(f"{os.path.join(record, SESSIONS)} exists ({first}): an IC has worked on this record, "
                            "so it is a rung's. lead-1 freezes a chore before its IC starts; an IC never turns its "
                            "rung into a chore")
        if os.path.exists(os.path.join(record, "stop1.log")):
            problems.append(f"{os.path.join(record, 'stop1.log')} exists: a STOP 1 was logged for a spec here, so "
                            "this is a rung's record; a rung freezes from its spec with --approved")
        dr = os.path.join(record, "decision-record.md")
        if os.path.exists(dr):
            r = re.search(r"^rules:\s*(\S+)", open(dr, encoding="utf-8").read(), re.M)
            if r and r.group(1) != "-":
                problems.append(f"{dr} names rules {r.group(1)} on its `rules:` line: a freeze already ran for this "
                                "record")
    try:
        title, gate = chore_read(handoff)
    except Refused as e:
        raise Refused(problems + e.reasons)
    if problems:
        raise Refused(problems)
    lane = lane_of(title)
    now = time.strftime("%Y-%m-%d %H:%M")
    rules_out = [f"rules · {lane} chore · frozen at handoff.md · {now}", ""] + standing_block() + [""]
    gate_out = [f"gate · {lane} chore · frozen at handoff.md · {now}", ""] + gate + [""]
    rules, gate_path = os.path.join(record, "rules.md"), os.path.join(record, "gate.md")
    if dump:
        print("\n".join(rules_out))
        print(f"freeze-rules --dump: would write {rules}")
        print("\n".join(gate_out))
        print(f"freeze-rules --dump: would write {gate_path}")
        return 0
    open(rules, "w", encoding="utf-8").write("\n".join(rules_out))
    open(gate_path, "w", encoding="utf-8").write("\n".join(gate_out))
    frozen.write_frozen(record, f"frozen · {lane} chore · {now}", None, None, chore="handoff.md")
    dr = os.path.join(record, "decision-record.md")
    if os.path.exists(dr):
        t = open(dr, encoding="utf-8").read()
        t = re.sub(r"^rules: .*$", f"rules: chore  (rules.md, the standing block; gate.md from handoff.md, frozen {now})",
                   t, count=1, flags=re.M)
        open(dr, "w", encoding="utf-8").write(t)
    for l in (rules_out[0], rules, gate_out[0], gate_path, os.path.join(record, "frozen.sha256")):
        print(l)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
