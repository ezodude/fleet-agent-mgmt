#!/usr/bin/env python3
"""Write one entry to lead-1's ledger, with the state and held changes that go with it.

Called by shared/ledger/ledger-add.sh, which gathers the title, the body (stdin), the
stamp, the entry number and HEAD, and commits afterwards. Everything that
touches the file is here, so it can be read, dumped and tested.

Usage
  ledger_add.py <ledger> [--dump] key=value ...
  env  LA_TITLE  LA_BODY  LA_NOW ("YYYY-MM-DD HH:MM")  LA_Z ("HH:MMZ")  LA_N (entry number)  LA_HEAD (short sha)

What it does, in order
  1  the entry   "### +N (<now> BST, <z>) <title>", a blank, the body, a blank; inserted after "## Log (newest first)"
  2  state keys  every plain key=value rewrites the line "key: ..." in the fenced state block (first match);
                 head: and updated: are always rewritten
  3  held keys   held+=<row>     one row inserted directly under the header row ("  TIME   IC ...") of "## held"
                                 (newest first); two leading spaces added when the row has none
                 held-=<text>    the one row of the held table containing <text> is removed; 0 or 2+ matches: exit 1, no write
                 held-note=<t>   the heading becomes "## held  (<t>)"; empty <t> gives "## held"
  4  the guard   before writing: the "### +" count went up by exactly one and the line count changed by exactly
                 the lines added minus the lines removed. Either off: exit 1, nothing written.
                 After writing: the file is read back and the same two counts checked again.
                 (A silent replace once dropped 9401 lines; this is the fence against the next one.)
  --dump         print the entry, the key rewrites and the held changes as they would land, and the expected
                 line delta; no write

Exit  0 written · 1 a check failed (message on stderr, file untouched) · 2 usage
LEDGER_ADD_FAULT=drop  test only: truncates the text after the checks, before the write, so the read-back
                       guard can be shown to abort. Never set outside shared/tests/test-ledger-add.sh.
"""
import os, re, sys

ANCHOR = "## Log (newest first)\n\n"
HELD_HEAD = re.compile(r"^## held(?:  \((.*)\))?[ \t]*$", re.M)
HELD_ROW_HEAD = re.compile(r"^  TIME\s+IC\b")


def fail(msg):
    print(f"ledger_add: {msg}", file=sys.stderr)
    sys.exit(1)


def held_section(lines):
    """(heading index, row header index, index after the last table line) of the ## held section."""
    try:
        h = next(i for i, l in enumerate(lines) if HELD_HEAD.match(l))
    except StopIteration:
        fail("no '## held' section")
    end = next((i for i in range(h + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    try:
        rh = next(i for i in range(h + 1, end) if HELD_ROW_HEAD.match(lines[i]))
    except StopIteration:
        fail("no '  TIME   IC' header row under '## held'")
    last = rh
    for i in range(rh + 1, end):
        if lines[i].strip():
            last = i
    return h, rh, last + 1


def apply(text, env, args):
    """The new text, the dump lines and the expected line delta. Raises SystemExit(1) on a bad key."""
    out, delta = [], 0
    if ANCHOR not in text:
        fail("no log anchor '## Log (newest first)'")
    entry = f"### +{env['LA_N']} ({env['LA_NOW']} BST, {env['LA_Z']}) {env['LA_TITLE']}\n\n{env['LA_BODY'].rstrip()}\n\n"
    text = text.replace(ANCHOR, ANCHOR + entry, 1)
    delta += entry.count("\n")
    out.append(f"entry       +{env['LA_N']} {env['LA_TITLE']} ({entry.count(chr(10))} lines)")

    kv = {"head": f"{env['LA_HEAD']} (ledger commit follows)", "updated": f"{env['LA_NOW']} BST"}
    held = []
    for a in args:
        k, sep, v = a.partition("=")
        if not sep:
            fail(f"not key=value: {a!r}")
        if k in ("held+", "held-", "held-note"):
            held.append((k, v))
        else:
            kv[k] = v
    for k, v in kv.items():
        text, c = re.subn(rf"^{re.escape(k)}:.*$", lambda m: f"{k}: {v}", text, count=1, flags=re.M)
        if c != 1:
            fail(f"state key not found: {k}")
        out.append(f"state       {k}: {v}")

    for k, v in held:
        lines = text.split("\n")
        h, rh, end = held_section(lines)
        if k == "held+":
            row = v if v[:1].isspace() else "  " + v
            lines.insert(rh + 1, row)
            delta += 1
            out.append(f"held +      {row.strip()}")
        elif k == "held-":
            hits = [i for i in range(rh + 1, end) if v in lines[i]]
            if len(hits) != 1:
                fail(f"held-= matches {len(hits)} rows, not 1: {v!r}")
            out.append(f"held -      {lines[hits[0]].strip()}")
            del lines[hits[0]]
            delta -= 1
        else:
            lines[h] = f"## held  ({v})" if v else "## held"
            out.append(f"held note   {lines[h]}")
        text = "\n".join(lines)
    return text, out, delta


def check(before, after, delta, where):
    """The two counts, or exit 1."""
    n0, n1 = before.count("\n### +"), after.count("\n### +")
    if n1 != n0 + 1:
        fail(f"{where}: entry count went {n0} -> {n1}, expected +1")
    l0, l1 = before.count("\n"), after.count("\n")
    if l1 - l0 != delta:
        fail(f"{where}: line count went {l0} -> {l1} ({l1 - l0:+d}), expected {delta:+d}")


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    path, rest = argv[1], argv[2:]
    dump = "--dump" in rest
    rest = [a for a in rest if a != "--dump"]
    for k in ("LA_TITLE", "LA_BODY", "LA_NOW", "LA_Z", "LA_N", "LA_HEAD"):
        if k not in os.environ:
            fail(f"env {k} not set")
    before = open(path, encoding="utf-8").read()
    after, out, delta = apply(before, os.environ, rest)
    check(before, after, delta, "before the write")
    if dump:
        print("\n".join(out))
        print(f"lines       {delta:+d} (dump: nothing written)")
        return 0
    if os.environ.get("LEDGER_ADD_FAULT") == "drop":
        after = after[: len(after) // 2]
    open(path, "w", encoding="utf-8").write(after)
    back = open(path, encoding="utf-8").read()
    check(before, back, delta, "after the write (the file is NOT as computed; restore it from git before anything else)")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
