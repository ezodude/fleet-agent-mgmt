#!/usr/bin/env python3
"""Run the rung's gate block exactly as written and write a receipt.

Called by shared/records/gate-run.sh, which gathers the stamp, HEAD and dirty count
and passes them here. Reads <record folder>/gate.md: the GATE BLOCK frozen
from the spec's Checks (a chore's: from its handoff's `## Checks`) by
shared/records/freeze_rules.py. The reader is strict, and
freeze_rules.py uses the same one, so gate.md holds exactly what runs here:

  - A label line is two spaces, the label (proves done, pass, on main,
    on failure, owner's word, record), then two or more spaces and its value,
    or the end of the line.
  - A line indented deeper than two spaces continues the label above it.
  - A line whose first non-space character is `#` is a comment.
  - A line at the left edge (a header, GATE BLOCK) ends the label above it.
  - A line indented one space or a tab, a two-space line with an unknown
    label, and a continuation under no label are problems.

Each `proves done` line is one command, run with bash -c in the cwd; the
`pass` line at the same position is its pass line. A command is green when:

  - its exit code is the one the pass line names (0 unless it says "exit N");
  - every "quoted string" on the pass line is in the output as a whole token
    (no letter, digit or underscore right before or after it);
  - a string the pass line writes as no "x" or "x" absent is nowhere in the
    output, not even inside a longer word.

Anything else is red. A pass line is a problem when it has curly quotes, an
odd number of quote marks, an exit code worded other than `exit N`, two exit
codes, or an absent condition naming more than one string (no "a" or "b":
write no "a", no "b"). Writes receipts/<stamp>-gate.md (verdict, HEAD, each
command, exit, tail) and the full output beside it, prints the verdict and the
path. Exit 0 green, 1 red, 2 with one reason per line and no receipt when
gate.md has no `proves done` lines, a problem, or a count of pass lines other
than the count of commands.

Before any run, rules.md and gate.md must match <record folder>/frozen.sha256
(shared/frozen.py verify): a frozen file that changed is exit 2, no receipt. A
folder listed in shared/records/legacy-records.txt is not checked. The receipt's `gate`
line names the sha256 of the gate.md it ran; message-gate.sh and push-gate.sh
compare it with frozen.sha256. The logic lives here, out of the shell, so it can
be read and debugged.

Usage
  gate_run.py <record folder> <receipt.md> <receipt.log> "<now>" <head sha> <dirty count> <cwd>
"""
import os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))   # shared/: the frozen module stays there

LABELS = ("proves done", "pass", "on main", "on failure", "owner's word", "record")
LABEL_LINE = re.compile(r"^  (" + "|".join(re.escape(x) for x in LABELS) + r")(?:\s{2,}(.*?)|\s*)$")
CURLY = re.compile(r"[“”‘’]")
NEGATION = r"\b(?:no|not|never|without)\s+"


def gate_lines(text, problems=None):
    """[(line number, label, value)] from gate.md: one item per label line and per continuation line."""
    out, sec = [], None
    for n, l in enumerate(text.replace("\r\n", "\n").split("\n"), 1):
        l = l.rstrip()
        if not l.strip() or l.strip().startswith("#"):
            continue
        if not l[0].isspace():
            sec = None
            continue
        m = LABEL_LINE.match(l)
        if m:
            sec = m.group(1)
            out.append((n, sec, (m.group(2) or "").strip()))
        elif l.startswith("   "):
            if sec:
                out.append((n, sec, l.strip()))
            elif problems is not None:
                problems.append(f"line {n}: `{l.strip()[:60]}` is indented as a continuation, but no label is above it")
        elif problems is not None:
            if l.startswith("  "):
                problems.append(f"line {n}: `{l.strip()[:60]}` is not a label; a label is two spaces, one of "
                                f"{', '.join(LABELS)}, then two or more spaces")
            else:
                problems.append(f"line {n}: `{l.strip()[:60]}` is indented with a tab or one space; a label takes "
                                "two spaces, a continuation more")
    return out


def read_gate(text, problems=None):
    """(commands, pass lines) from gate.md, aligned by position."""
    items = gate_lines(text, problems)
    return ([v for _, lab, v in items if lab == "proves done" and v],
            [v for _, lab, v in items if lab == "pass" and v])


def pass_problems(p):
    """Reasons a pass line cannot be read for certain; [] when it can."""
    out = []
    if CURLY.search(p):
        out.append("curly quotes; write straight quotes")
    if p.count('"') % 2:
        out.append("an odd number of \" marks; each string needs a quote on both sides")
    bare = re.sub(r'"[^"]*"', '""', p)
    for m in re.finditer(r"(?<![\w-])exit\w*(?![\w-])(\s+\S+)?", bare, re.I):
        if not re.fullmatch(r"exit\s+\d+[.,;:)]*", m.group(0), re.I):
            out.append(f"`{m.group(0).strip()}` names an exit code another way; write `exit N`")
    if len(set(re.findall(r"\bexit\s+(\d+)\b", bare, re.I))) > 1:
        out.append("two exit codes; a command has one")
    if re.search(NEGATION + r'"[^"]*"\s*(?:,|\bor\b|\band\b|\bnor\b)\s*"', p) \
            or re.search(r'"[^"]*"\s*(?:,|\bor\b|\band\b|\bnor\b)\s*"[^"]*"\s+(?:absent|missing)\b', p):
        out.append('an absent condition names more than one string; write no "a", no "b"')
    return out


def passes_line(pass_line, returncode, output):
    """Green when the exit code and every quoted string match what the pass line says."""
    p = CURLY.sub('"', pass_line)
    m = re.search(r"\bexit\s+(\d+)\b", re.sub(r'"[^"]*"', '""', p), re.I)
    want = int(m.group(1)) if m else 0
    ok = returncode == want
    for q in re.findall(r'"([^"]+)"', p):
        e = re.escape(q)
        absent = re.search(NEGATION + f'"{e}"', p) or re.search(rf'"{e}"\s+(?:absent|missing)\b', p)
        if absent:
            if q in output:
                ok = False
        elif not re.search(rf"(?<![A-Za-z0-9_]){e}(?![A-Za-z0-9_])", output):
            ok = False
    return ok


def run_gate(rec, out, log, now, head, dirty, cwd):
    import frozen   # here, not at the top: frozen imports freeze_rules, which imports this module
    changed = frozen.verify(rec)
    if changed:
        for x in changed:
            print(f"gate-run: {x}")
        print("gate-run: gate.md not run, no receipt")
        return 2
    problems = []
    gate_hex = frozen.sha256(f"{rec}/gate.md")
    cmds, passes = read_gate(open(f"{rec}/gate.md", encoding="utf-8").read(), problems)
    if not cmds:
        problems.append("no `proves done` lines in gate.md")
    if len(cmds) != len(passes):
        problems.append(f"{len(cmds)} commands and {len(passes)} pass lines; each command needs its pass line "
                        "at the same position")
    for p in passes:
        problems += [f"pass line `{p}`: {x}" for x in pass_problems(p)]
    if problems:
        for x in problems:
            print(f"gate-run: {x}")
        print("gate-run: gate.md not run, no receipt; lead-1 amends gate.md under a dated # Amended line")
        return 2
    rows, red = [], 0
    with open(log, "w", encoding="utf-8") as logf:
        for i, c in enumerate(cmds):
            p = passes[i]
            r = subprocess.run(["bash", "-c", c], capture_output=True, text=True, cwd=cwd)
            outp = (r.stdout or "") + (r.stderr or "")
            logf.write(f"### {i+1}  {c}\nexit {r.returncode}\n{outp}\n")
            ok = passes_line(p, r.returncode, outp)
            if not ok: red += 1
            tail = [t for t in outp.rstrip("\n").split("\n") if t.strip()][-10:]
            rows.append((i+1, "green" if ok else "red", r.returncode, c, p, tail))
    verdict = "green" if red == 0 else f"red: {red} of {len(cmds)}"
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"receipt · {os.path.basename(rec)} · {now} · HEAD {head} · dirty {dirty} · {cwd}\n")
        f.write(f"verdict  {verdict}\n")
        f.write(f"gate     sha256 {gate_hex}\n")
        for n, v, code, c, p, tail in rows:
            f.write(f"  {n}  {v:<5}  exit {code}  {c}\n")
            f.write(f"     pass   {p}\n")
            for t in tail: f.write(f"     tail   {t}\n")
        f.write(f"log      {os.path.basename(log)}\n")
    print(f"gate-run: {verdict} · HEAD {head[:7]} · {out}")
    print(f"evidence entry:  ran {os.path.relpath(out, rec)} · exit {' '.join(str(r[2]) for r in rows)} · output \"{verdict}\"")
    return 0 if red == 0 else 1


if __name__ == "__main__":
    rec, out, log, now, head, dirty, cwd = sys.argv[1:8]
    sys.exit(run_gate(rec, out, log, now, head, dirty, cwd))
