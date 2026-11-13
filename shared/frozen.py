#!/usr/bin/env python3
"""A rung's frozen files, and every check that reads <record>/frozen.sha256.

The freeze (shared/records/freeze_rules.py) writes frozen.sha256 beside rules.md and gate.md:

  frozen · ATL-42 r1 · 2026-09-14 15:40
  spec      docs/superpowers/specs/2026-09-14-atl-42-retry-design.md
  approved  4f1d2c9
  sha256    <64 hex>  rules.md
  sha256    <64 hex>  gate.md
  history   2026-09-20 11:02 · gate · line 2 kind a, main prints 211 · was <64 hex> · copy gate-pre-2026-09-20-1100.md

spec is the spec's repo path; approved is the commit the owner reviewed at STOP 1
(the sha on the report's spec line, given to the freeze as --approved). The two
sha256 lines are the hashes of rules.md and gate.md. A history line is appended
by each amendment, with the hash it replaced.

Beside them, <record>/stop1.log holds one line per STOP 1 report sent to lead-1 that the
message gate passed, written by that hook (never by hand; a hook denies an IC write):

  2026-09-14 15:20 · STOP 1 · spec docs/superpowers/specs/2026-09-14-atl-42-retry-design.md @ <40 hex> · atlas-ic · session <id>

The freeze takes as --approved only the newest sha there for the spec's path, and takes
the owner's spec ok only when it was typed after that line.

A chore's record (no spec, no STOP 1; shared/records/freeze_rules.py --chore, run by lead-1 before launch)
has a `chore     handoff.md` line in place of the spec and approved lines. Its chain leads back to
the handoff instead of a STOP 1 commit: the handoff still reads as a chore's (a CHAIN with no spec
step and no STOP 1, one `## Checks` table), gate.md as frozen holds exactly its Checks, rules.md as
frozen holds the standing block and no rung row. A record whose frozen.sha256 has both lines, a
chore's record with a stop1.log, and a spec line beside a handoff with `## Checks` are reasons;
stop1 and stop1-log refuse a chore's record.

A record folder listed in shared/records/legacy-records.txt was frozen before this file
existed: every check here passes it (exit 0, a note on stderr).

Usage
  frozen.py verify <record>
      rules.md and gate.md match frozen.sha256. Read by shared/records/gate_run.py before a
      run and by shared/hooks/dr_check.py before it reads rules.md.
  frozen.py check <record> [--receipt <receipt.md>] [--repo <dir>] [--worktree <dir>]
      verify, then: the receipt names the frozen gate.md's sha256 (gate_run.py writes
      it). With --repo or --worktree, the chain back to the approved commit: frozen.sha256's
      approved sha is a STOP 1 sha in stop1.log for the spec (a folder listed in
      shared/frozen-before-stop1-log.txt skips this chain); rules.md as frozen
      holds exactly the rows of the spec at that commit, and gate.md as frozen its Checks;
      each history copy hashes to its `was`, and each amendment step passes the amend
      checks below (so a `# Amended` line or a re-hash with no history is a reason). With
      --worktree, also the spec at the worktree's HEAD still reads as it froze: it parses,
      its rows match rules.md and gate.md (freeze_rules.py --check --record), its screen
      one is screen one at the approved commit line for line, and (new shape) it ends in
      `## Amendments` with `none` or dated lines. Read by shared/hooks/message-gate.sh
      (each STOP after STOP 1 with --repo; --worktree at "ready for push"),
      shared/hooks/push-gate.sh (--worktree) and shared/hooks/dr_check.py.
  frozen.py spec <record> [--repo <dir>]
      the spec text on stdin reads as it froze (the --worktree checks above, on that
      text). Read by shared/hooks/artefact-gate.sh at a write of the frozen spec.
  frozen.py stop1 <record> <spec repo path> <sha> [--cwd <dir>]
      the STOP 1 report's checks, before any freeze: the spec at <sha> parses under
      the strict reading; no Checks row has a placeholder `on main` cell (-, TODO,
      tbd, n/a); and <record>/evidence.md has one entry per Checks command whose
      `ran` is the command exactly and whose `where` reads `<cwd> · origin/main · HEAD
      <sha>`, with that sha on origin/main when the repo has the ref. Read by
      shared/hooks/message-gate.sh on a STOP 1 report.
  frozen.py stop1-log <record> <spec repo path> <sha> --cwd <dir> --name <roster name> --session <id>
      append the stop1.log line; run by shared/hooks/message-gate.sh when the whole
      STOP 1 report passed and it is sent to lead-1.
  frozen.py record <roster name>   (the message on stdin)
      the record folder a STOP report is checked against: the folders it names under the
      records root (written as FLEET_RECORDS, ~/.fleet-agent-mgmt/records or $HOME/...)
      that exist; a named open folder of this IC's (handoff.md's first line or a
      decision-record.md line names it; no close.md) wins wherever it stands; an open
      folder of its own the message does not name is exit 3 with the reason; else a named
      folder of its own, else the first named, else nothing.
  frozen.py bash-write <records root> [--name <roster name> --session <id>]   (the command on stdin)
      `chore` for the chore freeze, `act` for an amendment or a stop1.log write, `write` for a
      write form naming a frozen file, handoff.md or ic-sessions.log, `logs` for a write form naming
      Claude Code's session logs (~/.claude/projects/, where the freeze reads the owner's "spec ok"), else empty; read by
      shared/hooks/push-gate.sh. With --name, first the stamp below for the IC's Bash command,
      chores' records left out.
  frozen.py stamp <records root> <roster name> <session id> <where>
      append `<date time> · <where> · <name> · session <id>` to ic-sessions.log in each open record
      folder of this IC's (owns: handoff.md's first line or a decision-record.md line names it; no
      close.md) that has no frozen.sha256, is not in legacy-records.txt and has no file tracked by git
      (the records repo keeps a committed record as it closed), once per session. Run by
      shared/hooks/skill-boot.sh at an IC's session start. The chore freeze refuses a folder that
      holds ic-sessions.log: a record an IC has worked on is a rung's, whoever runs the freeze and from
      wherever, so the IC's own run of it (a quoted flag, a variable, python -c, a cd to lead-1's
      folder) is refused even where the command line hides it from push-gate.sh.
  frozen.py amend <record> <rules|gate> "<reason>"
      re-hash rules.md or gate.md after lead-1's amendment, through shared/amend-frozen.sh.
      Before the edit lead-1 copies the frozen file to <rules|gate>-pre-<stamp>.md in
      the record folder; the copy whose sha256 is the frozen hash is the text the edit
      is checked against:
        rules.md  every earlier line kept; an earlier row may only gain a
                  `[retired <date> by <line>]` suffix, where <line> is an appended row;
                  appended lines are `<KIND>  amended <date>:` headings and rows under them.
        gate.md   the first line kept; every earlier `# Amended` line kept; one new
                  `# Amended <date> <time> by lead-1 (C3): <line n>, <kind a|b>, <source>`
                  line above GATE BLOCK; no proves done line removed; gate_run reads it
                  with no problem.
      The owner's word, checked after the edit above passes (gate_owner_reason, amend_anchor,
      freeze_rules.amend_ok): a rules.md amendment, and a gate.md amendment that ADDS a proves done
      or pass line, are refused unless the owner typed "<LANE> r<n> amend ok <card id>" (lane and
      rung from the record folder's name: atl-42-r1 -> "ATL-42 r1 amend ok ATL-42 D4"), as a
      line of a message typed by a person (origin.kind human, never a relay) in lead-1's session
      log folder or the IC's, after the anchor: the newest history line of frozen.sha256, else the
      freeze time in its first line (else the newest stop1.log line), counted from the next minute.
      The card id must also be in the <reason>. A gate.md amendment that changes existing lines
      only needs no word: a changed pass line with a new `# Amended` line saying `kind a`, a
      changed command with one saying `kind b`; an added line needs it whatever the label says.
      The chain replay (check) does not ask for the word again: it was read when the step ran.
      Then the sha256 line is rewritten and a history line appended. Refused unless the
      cwd is lead-1's row in FLEET_HOME/roster.md (FLEET_ROSTER is not read:
      the caller sets it). shared/hooks/push-gate.sh also denies an IC Bash command that
      names amend-frozen or writes a frozen file.

Exit 0 ok, 2 with one reason per line on stdout. The logic lives here, out of the
shell, so the hooks stay thin and it can be read and debugged.
"""
import glob, hashlib, os, re, subprocess, sys, time
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "records"))
import freeze_rules as fr  # noqa: E402
import gate_run  # noqa: E402

NAME = "frozen.sha256"
STOP1_LOG = "stop1.log"
FILES = ("rules.md", "gate.md")
AMEND_HOW = "only lead-1 amends it, with shared/amend-frozen.sh; stop and ask lead-1 in the pane"
PLACEHOLDER = fr.PLACEHOLDER
CHORE_NO_STOP1 = ("is a chore's record (frozen.sha256 has a chore line, or handoff.md has a `## Checks` table): a "
                  "chore has no design spec and no STOP 1; its gate froze from the handoff before launch")
MAIN_WHERE = re.compile(r"·\s*origin/main\s*·\s*HEAD\s+([0-9a-f]{7,40})\b")
AMENDED_GATE = re.compile(r"^# Amended \d{4}-\d{2}-\d{2} \d{2}:\d{2} by lead-1 \(C3\): \S.*$")
AMENDED_HEAD = re.compile(r"^(TERMS|ONE-WAY|DECIDED|REJECTED)\s+amended \d{4}-\d{2}-\d{2}\b.*$")
RETIRED_TAG = re.compile(r"^(.*?)\s*\[retired (\d{4}-\d{2}-\d{2}) by (\d+)\]$")


def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def folder(record):
    return os.path.expanduser(record).rstrip("/")


def note(msg):
    print(f"frozen: note: {msg}", file=sys.stderr)


def read_frozen(record):
    """{"spec", "approved", "chore", "sha256": {file: hex}, "lines"} from <record>/frozen.sha256, or None."""
    path = os.path.join(record, NAME)
    if not os.path.exists(path):
        return None
    out = {"spec": None, "approved": None, "chore": None, "sha256": {},
           "lines": open(path, encoding="utf-8").read().split("\n")}
    for l in out["lines"]:
        m = re.match(r"^sha256\s+([0-9a-f]{64})\s+(\S+)\s*$", l)
        if m:
            out["sha256"][m.group(2)] = m.group(1)
            continue
        m = re.match(r"^(spec|approved|chore)\s+(\S.*?)\s*$", l)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def write_frozen(record, header, spec, approved, chore=None):
    """The freeze's frozen.sha256: header, spec path, approved sha (a chore: the chore line naming its
    handoff, no spec and no approved line), the hash of each frozen file present."""
    lines = [header, f"chore     {chore}"] if chore else [header, f"spec      {spec}", f"approved  {approved or '-'}"]
    for f in FILES:
        p = os.path.join(record, f)
        if os.path.exists(p):
            lines.append(f"sha256    {sha256(p)}  {f}")
    open(os.path.join(record, NAME), "w", encoding="utf-8").write("\n".join(lines) + "\n")


def git(cwd, *a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)


# ---------- verify, receipt, drift ------------------------------------------------------------

def verify(record):
    """Reasons rules.md or gate.md do not match frozen.sha256; [] when they do or the folder is legacy."""
    record = folder(record)
    if fr.legacy(record):
        note(f"{record} is listed in {fr.LEGACY}; frozen hashes not checked")
        return []
    f = read_frozen(record)
    chore = fr.chore_record(record)
    if f is None and chore:
        return [f"no {NAME} in {record}: the chore freeze has not run. lead-1 runs shared/records/freeze-rules.sh --chore "
                f"{record}/handoff.md before launch; rules.md and gate.md are never written by hand; stop and ask lead-1"]
    if f is None:
        return [f"no {NAME} in {record}: the freeze has not run. On \"spec ok\" the IC runs shared/records/freeze-rules.sh "
                f"<spec> <record> --approved <sha> (writing-a-design-spec step 5); a chore is frozen by lead-1 with "
                "shared/records/freeze-rules.sh --chore <record>/handoff.md before launch; rules.md and gate.md are never "
                "written by hand"]
    reasons = []
    if f["spec"] and f["chore"]:
        reasons.append(f"{NAME} in {record} has a spec line and a chore line: a record is a rung's or a chore's, never "
                       "both; stop and ask lead-1")
    elif f["spec"] and chore:
        reasons.append(f"{NAME} in {record} has a spec line, and handoff.md has a `## Checks` table: a chore's record "
                       "never takes a spec freeze; stop and ask lead-1")
    elif not f["spec"] and not f["chore"]:
        reasons.append(f"{NAME} in {record} has no spec line (and no chore line); it was not written by the freeze")
    if f["chore"] and os.path.exists(os.path.join(record, STOP1_LOG)):
        reasons.append(f"{record} is a chore's record and holds {STOP1_LOG}: a chore has no STOP 1; stop and ask lead-1")
    for name in FILES:
        h = f["sha256"].get(name)
        p = os.path.join(record, name)
        if not h:
            reasons.append(f"{NAME} names no {name}: the freeze wrote none, so the rung has no frozen "
                           f"{'rules' if name == 'rules.md' else 'gate'}; stop and ask lead-1")
        elif not os.path.exists(p):
            reasons.append(f"{p} is gone; it was frozen with sha256 {h[:12]}; {AMEND_HOW}")
        elif sha256(p) != h:
            reasons.append(f"{name} does not match {NAME} (sha256 {sha256(p)[:12]}, frozen {h[:12]}): it changed "
                           f"after the freeze; {AMEND_HOW}")
    return reasons


def receipt_reasons(record, receipt):
    """The receipt names the frozen gate.md's sha256: the run used the frozen gate, not a rewritten one."""
    f = read_frozen(record) or {"sha256": {}}
    want = f["sha256"].get("gate.md")
    try:
        text = open(receipt, encoding="utf-8").read()
    except OSError as e:
        return [f"cannot read the receipt {receipt}: {e.strerror}"]
    m = re.search(r"^gate\s+sha256\s+([0-9a-f]{64})\b", text, re.M)
    if not m:
        return [f"the receipt {os.path.basename(receipt)} names no gate.md sha256: shared/records/gate-run.sh did not write "
                "it; run shared/records/gate-run.sh <record> again from the worktree"]
    if want and m.group(1) != want:
        return [f"the receipt {os.path.basename(receipt)} ran a gate.md with sha256 {m.group(1)[:12]}, the frozen "
                f"gate.md is {want[:12]}; run shared/records/gate-run.sh <record> again on the frozen gate"]
    return []


DATED = re.compile(r"^\s*([-*]\s+)?(\*\*)?\d{4}-\d{2}-\d{2}\b")


def amendments_reasons(text):
    """A new-shape spec ends in `## Amendments`, the last `##` heading below the fold: `none`, or one dated
    line per amendment. A renamed or missing section, or an undated line, is a reason."""
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ctx = fr.contexts(lines)
    heads = [i for i, (l, c) in enumerate(zip(lines, ctx)) if c == "text" and re.match(r"^ {0,3}##\s", l)]
    if not heads or lines[heads[-1]].rstrip() != "## Amendments":
        last = lines[heads[-1]].strip()[:60] if heads else "none"
        return [f"the last `##` heading is `{last}`, not `## Amendments`: the spec ends in `## Amendments`, "
                "`none` or one dated line per new fact after approval (writing-a-design-spec step 8); "
                "restore the section and its dated lines"]
    body = [(i, l) for i, l in enumerate(lines[heads[-1] + 1:], heads[-1] + 2) if l.strip()]
    if [l.strip() for _, l in body] == ["none"]:
        return []
    if not body:
        return ["`## Amendments` is empty; write `none`, or one dated line per amendment"]
    return [f"`## Amendments` line {i} `{l.strip()[:60]}` is not a dated line: each amendment is one line "
            "starting with its date (YYYY-MM-DD)" for i, l in body if not DATED.match(l)]


def spec_reasons(record, text, repo):
    """Reasons a text of the frozen spec no longer reads as it froze: it does not parse, its rows differ
    from rules.md or gate.md, its screen one is not screen one at the approved commit line for line, or
    (new shape) its `## Amendments` section is renamed, gone or undated."""
    f = read_frozen(record) or {}
    try:
        parsed = fr.parse(text)
        reasons = fr.compare_record(parsed, record)
    except fr.Refused as e:
        parsed, reasons = None, list(e.reasons)
    if fr.pre_log(folder(record)):   # froze before stop1.log: the rows only, as when it froze
        return reasons
    ap, spec = f.get("approved"), f.get("spec")
    if ap and ap != "-" and spec:
        r = git(repo, "show", f"{ap}:{spec}")
        if r.returncode:
            reasons.append(f"{spec} at the approved commit {ap} cannot be read in {repo}, so screen one cannot be "
                           "compared with what the owner approved")
        else:
            try:
                change = fr.screen_change(r.stdout, text)
            except fr.Refused as e:
                change = None
                reasons += [x for x in e.reasons if x not in reasons]
            if change:
                n, a, b = change
                reasons.append(f"screen one changed after {ap}, the commit the owner approved: line {n} was "
                               f"`{a[:60]}`, is `{b[:60]}`. Screen one does not change after the freeze: a new fact "
                               "is one dated line under `## Amendments`, a rule change is a card to lead-1")
    if parsed and parsed["new"]:
        reasons += amendments_reasons(text)
    return reasons


def drift_reasons(record, worktree):
    """The spec at the worktree's HEAD still reads as it froze (spec_reasons)."""
    f = read_frozen(record)
    if not f or not f["spec"]:
        return []
    spec = f["spec"]
    r = git(worktree, "show", f"HEAD:{spec}")
    if r.returncode:
        return [f"spec drift: {spec}, the frozen spec, is not in HEAD of {worktree} (deleted or moved after the "
                "freeze); restore it at its path"]
    return [f"spec drift: {spec} at HEAD: {x}" for x in spec_reasons(record, r.stdout, worktree)]



def disk_reasons(record, worktree):
    """The spec on disk in the worktree (committed or not) still reads as it froze (spec_reasons)."""
    f = read_frozen(record)
    if not f or not f["spec"]:
        return []
    path = os.path.join(worktree, f["spec"])
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return [f"spec drift: {f['spec']}, the frozen spec, is not on disk in {worktree}; restore it at its path"]
    return [f"spec drift: {f['spec']} on disk: {x}" for x in spec_reasons(record, text, worktree)]

def log_shas(record, spec):
    """The full shas of <record>/stop1.log's lines for this spec path, oldest first."""
    try:
        text = open(os.path.join(record, STOP1_LOG), encoding="utf-8").read()
    except OSError:
        return []
    clean = lambda s: s[2:] if s.startswith("./") else s
    return [m.group(2) for m in re.finditer(r"· STOP 1 · spec (\S+) @ ([0-9a-f]{40}) ·", text)
            if clean(m.group(1)) == clean(spec)]


def rung_rows(text):
    """rules.md's rung rows as written (tags kept, whitespace collapsed): the standing lines and `none` left out."""
    out, sec = [], None
    for l in text.split("\n"):
        m = re.match(r"^(TERMS|ONE-WAY|DECIDED|REJECTED)\b", l)
        if m:
            sec = m.group(1)
            continue
        if sec and l.startswith("  ") and l.strip() and "[standing]" not in l and fr.norm(l) != "none":
            out.append((sec, fr.norm(l)))
    return out


def chain_reasons(record, repo):
    """The frozen files lead back to the commit the owner approved. Reasons when: frozen.sha256 has no
    approved sha; that sha is not a STOP 1 sha in stop1.log for the spec (the message gate writes it; the
    freeze itself takes only the newest); the spec at that commit cannot be read or would not freeze; rules.md as frozen (the copy on the
    first rules history line, else rules.md) does not hold exactly the approved spec's rows; gate.md as
    frozen (the same for gate) is not the approved spec's Checks or has a `# Amended` line; a history copy
    is gone or does not hash to its `was`; or an amendment step is not an amendment (rules_edit, gate_edit)."""
    record = folder(record)
    if fr.legacy(record) or fr.pre_log(record):
        return []
    f = read_frozen(record)
    if f and f["chore"]:
        return chore_chain_reasons(record)
    if not f or not f["spec"]:
        return []
    ap, spec = f["approved"], f["spec"]
    if not ap or ap == "-":
        return [f"{NAME} in {record} has no approved sha: the freeze ran without the STOP 1 sha; stop and ask lead-1"]
    full = git(repo, "rev-parse", "-q", "--verify", f"{ap}^{{commit}}").stdout.strip()
    if not full:
        return [f"the approved commit {ap} named in {NAME} is not in {repo}; stop and ask lead-1"]
    if full not in log_shas(record, spec):
        return [f"the approved commit {ap} is not a STOP 1 sha for {spec} in {record}/{STOP1_LOG} (the message "
                "gate writes it when STOP 1 passes): the freeze took a commit the owner did not review, or "
                f"{NAME} was rewritten; stop and ask lead-1"]
    r = git(repo, "show", f"{full}:{spec}")
    if r.returncode:
        return [f"{spec} is not in the approved commit {ap}; stop and ask lead-1"]
    try:
        parsed = fr.parse(r.stdout)
    except fr.Refused as e:
        return [f"the spec at the approved commit {ap} would not freeze: {x}" for x in e.reasons]
    reasons, hist = [], fr.history(record)
    for kind in ("rules", "gate"):
        if kind == "gate" and not parsed["gate"]:
            continue
        texts = history_texts(record, kind, hist, reasons)
        if texts is None:
            continue
        base = texts[0]
        if kind == "rules":
            want = Counter((n, fr.norm(x)) for n in fr.ROW_BLOCKS for x in parsed["blocks"][n][1:]
                              if fr.norm(x) != "none")
            have = Counter(rung_rows(base))
            for s, x in sorted(have - want):
                reasons.append(f"rules.md as frozen has a {s} row the approved spec ({ap}) does not: {x}")
            for s, x in sorted(want - have):
                reasons.append(f"the approved spec ({ap}) has a {s} row rules.md as frozen does not: {x}")
        else:
            reasons += gate_reasons(parsed["gate"], base, f"the approved spec's Checks ({ap})", "the spec")
        reasons += steps_reasons(kind, texts)
    return reasons


def history_texts(record, kind, hist, reasons):
    """The texts of rules.md or gate.md as frozen (the copy on the first history line of that kind, else the
    file), each amendment's copy, and the file now, oldest first; None, with the reason added, when a copy is
    gone or no longer hashes to its `was`, or the file is gone."""
    steps, broken = [], False
    for k, was, copy in hist:
        if k != kind:
            continue
        p = os.path.join(record, copy)
        if not os.path.exists(p):
            reasons.append(f"{copy}, named on a {kind} history line of {NAME}, is gone")
            broken = True
        elif sha256(p) != was:
            reasons.append(f"{copy} does not hash to the `was` of its {kind} history line: it changed after the "
                           "amendment")
            broken = True
        steps.append(p)
    steps.append(os.path.join(record, kind + ".md"))
    if broken or not os.path.exists(steps[-1]):
        return None
    return [open(p, encoding="utf-8").read() for p in steps]


def gate_reasons(source, base, what, short):
    """gate.md as frozen (base) holds exactly the source's GATE BLOCK lines and no `# Amended` line."""
    reasons = []
    if re.search(r"^\s*#\s*Amended\b", base, re.M):
        reasons.append(f"gate.md has a `# Amended` line and {NAME} has no gate history line for it: an "
                       "amendment goes through shared/amend-frozen.sh")
    sc, sp = gate_run.read_gate("\n".join(source))
    gc, gp = gate_run.read_gate(base)
    if [fr.norm(x) for x in sc] != [fr.norm(x) for x in gc] or \
            [fr.norm(x) for x in sp] != [fr.norm(x) for x in gp]:
        reasons.append(f"gate.md as frozen is not {what}: {len(gc)} commands and {len(gp)} pass lines, {short} "
                       f"{len(sc)} and {len(sp)}, or a line differs")
    return reasons


def steps_reasons(kind, texts):
    """Each step from the frozen text to the file now is an amendment (rules_edit, gate_edit)."""
    out = []
    for n, (a, b) in enumerate(zip(texts, texts[1:]), 1):
        probs = rules_edit(a, b) if kind == "rules" else gate_edit(a, b)
        out += [f"{kind}.md amendment {n} is not an amendment: {x}" for x in probs]
    return out


def chore_chain_reasons(record):
    """A chore's frozen files lead back to its handoff: the handoff still reads as a chore's (freeze_rules
    chore_read: no line naming a spec step or STOP 1, one `## Checks` table, no placeholder); gate.md as
    frozen holds exactly its Checks; rules.md as frozen holds the standing block and no rung row; no
    stop1.log; each history copy hashes to its `was`; each amendment step is an amendment."""
    hand = os.path.join(record, "handoff.md")
    if not os.path.exists(hand):
        return [f"{record} is a chore's record and has no handoff.md, the source of its frozen gate; stop and ask lead-1"]
    try:
        _, gate = fr.chore_read(hand)
    except fr.Refused as e:
        return [f"the chore's handoff.md no longer reads as it froze: {x}" for x in e.reasons]
    except OSError as e:
        return [f"cannot read {hand}: {e.strerror}"]
    reasons, hist = [], fr.history(record)
    if os.path.exists(os.path.join(record, STOP1_LOG)):
        reasons.append(f"{record} is a chore's record and holds {STOP1_LOG}: a chore has no STOP 1")
    for kind in ("rules", "gate"):
        texts = history_texts(record, kind, hist, reasons)
        if texts is None:
            continue
        base = texts[0]
        if kind == "rules":
            for s, x in rung_rows(base):
                reasons.append(f"rules.md as frozen has a {s} row, and a chore's rules.md is the standing block only: {x}")
            if "[standing]" not in base:
                reasons.append("rules.md as frozen has no [standing] lines: the chore freeze writes the standing block")
        else:
            reasons += gate_reasons(gate, base, "the handoff's `## Checks`", "the handoff")
        reasons += steps_reasons(kind, texts)
    return reasons


def check(record, receipt=None, worktree=None, repo=None):
    record = folder(record)
    if fr.legacy(record):
        note(f"{record} is listed in {fr.LEGACY}; not checked")
        return []
    reasons = verify(record)
    if receipt:
        reasons += receipt_reasons(record, receipt)
    if (repo or worktree) and read_frozen(record):
        reasons += chain_reasons(record, repo or worktree)
    if worktree and read_frozen(record):
        reasons += drift_reasons(record, worktree)
    return reasons


# ---------- STOP 1 ----------------------------------------------------------------------------

def evidence_entries(path):
    """[{"id", "ran", "where"}] from evidence.md: each `## E<n>` heading and its first ran and where lines."""
    out, cur = [], None
    for l in open(path, encoding="utf-8").read().split("\n"):
        m = re.match(r"^## (E\d+)\b", l)
        if m:
            cur = {"id": m.group(1), "ran": None, "where": None}
            out.append(cur)
            continue
        if cur is None:
            continue
        if l.strip() and not l.startswith(" "):
            cur = None
            continue
        m = re.match(r"^  (ran|where)\s{2,}(.*?)\s*$", l)
        if m and cur[m.group(1)] is None:
            cur[m.group(1)] = m.group(2)
    return out


def stop1(record, spec, sha, cwd):
    """Reasons a STOP 1 report is not ready: the spec at <sha> does not freeze, or main's runs are not in evidence."""
    record = folder(record)
    if fr.legacy(record):
        note(f"{record} is listed in {fr.LEGACY}; STOP 1 not checked")
        return []
    if fr.chore_record(record):
        return [f"{record} {CHORE_NO_STOP1}. Its first report is STOP 2 \"ready for push\", after shared/records/gate-run.sh"]
    if git(cwd, "cat-file", "-e", f"{sha}^{{commit}}").returncode:
        return [f"the spec line's sha {sha} is not a commit in {cwd}; the line is `spec  <repo path> @ <sha>`, the "
                "commit that holds screen one as the owner will read it"]
    path = spec[2:] if spec.startswith("./") else spec
    r = git(cwd, "show", f"{sha}:{path}")
    if r.returncode:
        return [f"{spec} is not in commit {sha}; the spec line names the spec by its repo path"]
    text = r.stdout
    try:
        fr.parse(text)
        rows = fr.checks_rows(text)
    except fr.Refused as e:
        return [f"the spec at {sha} would not freeze: {x}" for x in e.reasons]
    reasons = []
    for n, (cmd, _, main) in enumerate(rows, 1):
        if PLACEHOLDER.match(main or ""):
            reasons.append(f"Checks row {n} `{cmd}`: on main is `{main}`, a placeholder; run the command once on "
                           "origin/main and write what it printed")
    ev = os.path.join(record, "evidence.md")
    if not os.path.exists(ev):
        return reasons + [f"no evidence.md in {record}: each Checks command runs once on origin/main before STOP 1, "
                          "one entry each (recording-evidence), `where` reading `<cwd> · origin/main · HEAD <sha>`"]
    entries = evidence_entries(ev)
    main_ref = git(cwd, "rev-parse", "-q", "--verify", "refs/remotes/origin/main").stdout.strip()
    for n, (cmd, _, _) in enumerate(rows, 1):
        hits = [e for e in entries if e["ran"] is not None and fr.norm(e["ran"]) == fr.norm(cmd)]
        if not hits:
            reasons.append(f"Checks row {n} `{cmd}`: no entry in evidence.md whose `ran` is this command exactly; run "
                           "it once on origin/main and record it (recording-evidence)")
            continue
        at_main = [(e, MAIN_WHERE.search(e["where"] or "")) for e in hits]
        at_main = [(e, m.group(1)) for e, m in at_main if m]
        if not at_main:
            reasons.append(f"Checks row {n} `{cmd}`: {', '.join(e['id'] for e in hits)} did not run at origin/main; "
                           "`where` reads `<cwd> · origin/main · HEAD <sha>`")
            continue
        if main_ref and not any(git(cwd, "merge-base", "--is-ancestor", s, main_ref).returncode == 0 for _, s in at_main):
            reasons.append(f"Checks row {n} `{cmd}`: {', '.join(e['id'] + ' HEAD ' + s for e, s in at_main)} is not a "
                           "commit on origin/main; run it again on origin/main")
    return reasons


def stop1_log(record, spec, sha, cwd, name, session):
    """Append the STOP 1 line the freeze's --approved is checked against; run by the message gate only when
    the whole STOP 1 report passed."""
    record = folder(record)
    if fr.legacy(record):
        return []
    if fr.chore_record(record):
        return [f"stop1.log not written: {record} {CHORE_NO_STOP1}"]
    full = git(cwd, "rev-parse", "-q", "--verify", f"{sha}^{{commit}}").stdout.strip()
    if not full or not os.path.isdir(record):
        return [f"stop1.log not written: {sha} is not a commit in {cwd}, or {record} is not a folder"]
    path = spec[2:] if spec.startswith("./") else spec
    line = f"{time.strftime('%Y-%m-%d %H:%M')} · STOP 1 · spec {path} @ {full} · {name} · session {session}\n"
    with open(os.path.join(record, STOP1_LOG), "a", encoding="utf-8") as fh:
        fh.write(line)
    return []


# ---------- the record folder a STOP report names -----------------------------------------------

def owns(d, name):
    """True when the folder is this IC's: handoff.md's first line names it (`· <name> ·`), or a line of
    decision-record.md ends `· <name>`."""
    try:
        first = open(os.path.join(d, "handoff.md"), encoding="utf-8").readline().rstrip("\n")
        if f"· {name} ·" in first or first.endswith(f"· {name}"):
            return True
    except OSError:
        pass
    try:
        return any(l.rstrip("\n").endswith(f"· {name}") for l in open(os.path.join(d, "decision-record.md"),
                                                                       encoding="utf-8"))
    except OSError:
        return False


def pick_record(name, message):
    """(folder or "", refusal or "") for a STOP report: the record folders the message names (written under
    the records root, `~/.fleet-agent-mgmt/records` or `$HOME/...`), that exist. A named open (no close.md)
    folder of this IC's that is not in legacy-records.txt wins, wherever it stands in the message; with such
    a folder the message does not name, the report is refused (a legacy folder named first never skips the
    live one's gate); then the same for a legacy folder; else a named folder of its own, else the first named."""
    root = fr.records_root()
    forms = {root, "~/.fleet-agent-mgmt/records", "$HOME/.fleet-agent-mgmt/records", "${HOME}/.fleet-agent-mgmt/records",
             os.path.expanduser("~/.fleet-agent-mgmt/records")}
    alt = "|".join(re.escape(x.rstrip("/")) for x in sorted(forms, key=len, reverse=True))
    named = []
    for m in re.finditer(r"(?:" + alt + r")/([^\s·/`'\")]+)/([^\s·/`'\")]+)", message):
        d = os.path.join(root, m.group(1), m.group(2))
        if os.path.isdir(d) and d not in named:
            named.append(d)
    mine = [d for d in sorted(glob.glob(os.path.join(root, "*", "*"))) if os.path.isdir(d) and owns(d, name)]
    is_open = lambda d: not os.path.exists(os.path.join(d, "close.md"))
    open_mine = [d for d in mine if is_open(d)]
    live = [d for d in open_mine if not fr.legacy(d)]   # a listed (legacy) folder never shields a live one
    for d in named:
        if d in live:
            return d, ""
    unnamed = [d for d in live if d not in named] or [d for d in open_mine if d not in named]
    if unnamed:
        return "", (f"this IC has an open record folder ({unnamed[0]}) and the message does not name it. Put the "
                    "folder on the files line; a STOP from a rung with a record folder is checked against it.")
    for d in named:
        if d in open_mine:
            return d, ""
    for d in named:
        if d in mine:
            return d, ""
    return (named[0] if named else ""), ""


# ---------- amend -----------------------------------------------------------------------------

def roster_rows(roster=None):
    """[(name, cwd)] of the fleet block of <settings FLEET_HOME>/roster.md (or <roster>)."""
    try:
        text = open(roster or os.path.join(fr.settings_fleet_home(), "roster.md"), encoding="utf-8").read()
    except OSError:
        return []
    m = re.search(r"^```fleet\n(.*?)^```", text, re.M | re.S)
    rows = (l.split("\t") for l in (m.group(1).split("\n") if m else []))
    return [(p[0], p[1]) for p in rows if len(p) >= 2 and p[1]]


def roster_row(cwd, roster=None):
    """The roster name whose fleet row is cwd, read from the settings home's roster.md (fr.settings_fleet_home(), never os.environ); else None."""
    here = os.path.realpath(cwd)
    return next((n for n, d in roster_rows(roster) if os.path.realpath(d) == here), None)


def record_ic_cwds(record, roster=None):
    """The worktrees of the ICs of this record, for the folders the owner's amend word is read from: the roster
    rows (not lead-1's) that own the record folder (owns), and the roster names on its stop1.log lines."""
    try:
        logged = set(re.findall(r" · (\S+) · session ", open(os.path.join(record, STOP1_LOG), encoding="utf-8").read()))
    except OSError:
        logged = set()
    return [d for n, d in roster_rows(roster) if n != "lead-1" and (n in logged or owns(record, n))]


def rules_edit(old, new):
    """Reasons the edit of rules.md is not an amendment: earlier lines kept, retired tags, appended amended rows."""
    o, n = old.rstrip("\n").split("\n"), new.rstrip("\n").split("\n")
    if len(n) < len(o):
        return [f"rules.md has {len(n)} lines, the frozen copy {len(o)}: an amendment never removes a line"]
    problems, retire = [], []
    for i, (a, b) in enumerate(zip(o, n), 1):
        if a == b:
            continue
        m = RETIRED_TAG.match(b)
        if m and m.group(1).rstrip() == a.rstrip() and a.startswith("  ") and "[standing]" not in a \
                and "[retired" not in a:
            retire.append((i, int(m.group(3))))
            continue
        problems.append(f"rules.md line {i} changed: `{a.strip()[:70]}` is now `{b.strip()[:70]}`; an earlier line "
                        "only gains a `[retired <date> by <line>]` suffix")
    under, live = False, set()
    for k, l in enumerate(n[len(o):], len(o) + 1):
        if not l.strip():
            continue
        if AMENDED_HEAD.match(l):
            under = True
        elif under and l.startswith("  "):
            if re.search(r"\[standing\]|\[retired\b", l):
                problems.append(f"rules.md line {k}: an amended row never carries `[standing]` or `[retired`")
            live.add(k)
        else:
            problems.append(f"rules.md line {k} `{l.strip()[:70]}` is not a `<KIND>  amended <date>:` heading or a "
                            "row under one; amendments are appended under that heading")
    for i, by in retire:
        if by not in live:
            problems.append(f"rules.md line {i} is retired by line {by}, which is not an appended row under an "
                            "amended heading")
    if not problems and not retire and not live:
        problems.append("rules.md changed, and no amendment row or retired tag was found")
    return problems


def gate_edit(old, new):
    """Reasons the edit of gate.md is not an amendment under C3."""
    o, n = old.split("\n"), new.split("\n")
    problems = []
    if n[0] != o[0]:
        problems.append(f"gate.md's first line changed (`{o[0][:60]}`); the freeze header stays")
    for l in o:
        if re.match(r"^\s*#\s*Amended\b", l) and l not in n:
            problems.append(f"an earlier amendment line was removed: `{l.strip()[:70]}`")
    gb = next((i for i, l in enumerate(n) if l.strip() == "GATE BLOCK"), None)
    if gb is None:
        problems.append("gate.md has no GATE BLOCK line")
    added = [i for i, l in enumerate(n) if AMENDED_GATE.match(l) and l not in o]
    if not added:
        problems.append("no new `# Amended <date> <time> by lead-1 (C3): <line n>, <kind a|b>, <source>` line")
    elif gb is not None and any(i > gb for i in added):
        problems.append("the new `# Amended` line sits below GATE BLOCK; it goes at the top, above GATE BLOCK")
    oc, _ = gate_run.read_gate(old)
    probs = []
    nc, np_ = gate_run.read_gate(new, probs)
    if len(nc) < len(oc):
        problems.append(f"gate.md has {len(nc)} proves done lines, the frozen copy {len(oc)}: an amendment never "
                        "removes a line")
    if len(nc) != len(np_):
        probs.append(f"{len(nc)} commands and {len(np_)} pass lines")
    for p in np_:
        probs += [f"pass line `{p}`: {x}" for x in gate_run.pass_problems(p)]
    return problems + [f"gate.md: {p}" for p in probs]


AMEND_KIND = re.compile(r"\bkind\s+([ab])\b", re.I)


def gate_owner_reason(old, new):
    """Why the gate.md edit needs the owner's typed approval; "" when it stays lead-1's own act.

    Lead-1 alone may amend an existing line: kind a (a pass line, set to what origin/main prints) or kind
    b (a command, set to CI's exact form). Told apart by the diff shape, not the label: a proves done or
    pass line ADDED (more of either than the frozen copy) always needs the owner, whatever the label says;
    a pass line changed needs a new `# Amended` line saying `kind a`, a command changed one saying `kind b`.
    Not decided here: whether the new line is what main prints or what CI runs (lead-1's guard, in evidence.md)."""
    oc, op = gate_run.read_gate(old)
    nc, np_ = gate_run.read_gate(new)
    if len(nc) > len(oc) or len(np_) > len(op):
        return "a gate.md amendment that adds a proves done line"
    old_lines = old.split("\n")
    kinds = {m.group(1).lower() for l in new.split("\n") if AMENDED_GATE.match(l) and l not in old_lines
             for m in AMEND_KIND.finditer(l)}
    if any(a != b for a, b in zip(op, np_)) and "a" not in kinds:
        return "a gate.md amendment that changes a pass line with no `kind a` # Amended line"
    if any(a != b for a, b in zip(oc, nc)) and "b" not in kinds:
        return "a gate.md amendment that changes a command with no `kind b` # Amended line"
    return ""


def amend_anchor(f, record):
    """(epoch, "YYYY-MM-DD HH:MM", where it came from): the time the owner's amend word must follow.
    The newest history line of frozen.sha256 (the last amendment); with none, the freeze time in its header
    (`frozen · <lane> r<n> · <date> <time>`); a header with no time falls back to the newest stop1.log line.
    All are written to the minute, in local time. None when none of them holds a time."""
    stamps = lambda lines, rx: [m.group(1) for m in (re.match(rx, l) for l in lines) if m]
    d, t = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2})", NAME
    for src, times in (("the newest history line of " + t, stamps(f["lines"], rf"^history\s+{d}\b")),
                       ("the freeze time in " + t, stamps(f["lines"][:1], rf"^frozen\s.*{d}\s*$"))):
        if times:
            at = max(times)
            return time.mktime(time.strptime(at, "%Y-%m-%d %H:%M")), at, src
    try:
        log = open(os.path.join(record, STOP1_LOG), encoding="utf-8").read().split("\n")
    except OSError:
        log = []
    times = stamps(log, rf"^{d} · STOP 1 ·")
    if times:
        at = max(times)
        return time.mktime(time.strptime(at, "%Y-%m-%d %H:%M")), at, "the newest line of " + STOP1_LOG
    return None


def amend(record, kind, reason, cwd):
    """Re-hash rules.md or gate.md after lead-1's amendment; (exit code, lines to print). The edit is checked
    against the frozen copy (rules_edit, gate_edit); then a rules.md amendment, or a gate.md amendment that
    adds a line, needs the owner's typed "<lane> r<n> amend ok <card id>" after amend_anchor, with the card
    id in <reason> (freeze_rules.amend_ok)."""
    record = folder(record)
    if kind not in ("rules", "gate") or not reason.strip():
        return 2, ['usage: amend-frozen.sh <record folder> <rules|gate> "<reason>"']
    who = roster_row(cwd)   # FLEET_HOME/roster.md, never FLEET_ROSTER: the caller sets the env
    if who != "lead-1":
        where = f"{who}'s worktree" if who else "not lead-1's folder in FLEET_HOME/roster.md"
        return 2, [f"amend-frozen: {cwd} is {where}; an amendment is lead-1's act, run from lead-1's folder. "
                   "Raise a card to lead-1"]
    if fr.legacy(record):
        return 0, [f"amend-frozen: {record} is listed in {fr.LEGACY}; it has no {NAME}, nothing re-hashed"]
    f = read_frozen(record)
    if f is None:
        return 2, [f"amend-frozen: no {NAME} in {record}; the freeze has not run"]
    name = kind + ".md"
    path = os.path.join(record, name)
    was = f["sha256"].get(name)
    if not was or not os.path.exists(path):
        return 2, [f"amend-frozen: {NAME} names no {name}, or {path} is gone"]
    now_hex = sha256(path)
    if now_hex == was:
        return 0, [f"amend-frozen: {name} matches {NAME}; nothing to re-hash"]
    copies = sorted((p for p in glob.glob(os.path.join(record, f"{kind}-pre-*.md")) if sha256(p) == was),
                    key=os.path.getmtime)
    if not copies:
        return 2, [f"amend-frozen: no {kind}-pre-*.md in {record} matches the frozen {name} (sha256 {was[:12]}). "
                   f"Copy the frozen file before the edit (cp {path} {record}/{kind}-pre-<stamp>.md), then edit, then "
                   "run this again; when the edit came first, restore the frozen text and start over"]
    pre = copies[-1]
    old, new = open(pre, encoding="utf-8").read(), open(path, encoding="utf-8").read()
    problems = rules_edit(old, new) if kind == "rules" else gate_edit(old, new)
    if problems:
        return 2, [f"amend-frozen: {p}" for p in problems] + [f"amend-frozen: nothing re-hashed; {name} still differs "
                                                               f"from {NAME}, so the gate, the hooks and the push refuse"]
    why = "a rules.md amendment" if kind == "rules" else gate_owner_reason(old, new)
    if why:   # the owner's typed word, read from the session logs; lead-1 never supplies it
        anchor = amend_anchor(f, record)
        if not anchor:
            return 2, [f"amend-frozen: {why} needs the owner's typed approval, and {NAME} holds no time to read it "
                       "after (no history line, no freeze time, no stop1.log line). Hold and ask the owner"]
        try:
            fr.amend_ok(record, anchor, why, reason, record_ic_cwds(record))
        except fr.Refused as e:
            return 2, [f"amend-frozen: {r}" for r in e.reasons] + [f"amend-frozen: {name} still differs from {NAME}"]
    stamp = time.strftime("%Y-%m-%d %H:%M")
    lines = [re.sub(rf"^sha256\s+{was}\s+{re.escape(name)}\s*$", f"sha256    {now_hex}  {name}", l)
             for l in f["lines"]]
    while lines and not lines[-1].strip():
        lines.pop()
    clean = " ".join(reason.split()).replace("·", "-")
    lines.append(f"history   {stamp} · {kind} · {clean} · was {was} · copy {os.path.basename(pre)}")
    open(os.path.join(record, NAME), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return 0, [f"amend-frozen: {name} re-hashed, sha256 {now_hex[:12]} (was {was[:12]}); history line appended to "
               f"{os.path.join(record, NAME)}"]


# ---------- an IC's session on an open record folder ---------------------------------------------

def tracked(d):
    """True when git tracks any file in the folder: the records repo (~/.fleet-agent-mgmt) holds it as
    committed at the record's close. Not in a git repo: False."""
    return bool(git(d, "ls-files", "--", ".").stdout.strip())


def stamp(records, name, session, where, chores=True):
    """Append this IC session's line to ic-sessions.log in each open record folder of its own that has no
    frozen.sha256 (chores=False: a chore's record left out too), once per session; the folders stamped.
    A folder git already tracks is left as it was committed, close.md or not."""
    out = []
    for d in sorted(glob.glob(os.path.join(records, "*", "*"))):
        if not os.path.isdir(d) or any(os.path.exists(os.path.join(d, f)) for f in ("close.md", NAME)):
            continue
        if fr.legacy(d) or not owns(d, name) or (not chores and fr.chore_record(d)) or tracked(d):
            continue
        log = os.path.join(d, fr.SESSIONS)
        try:
            if os.path.exists(log) and f"· session {session}\n" in open(log, encoding="utf-8").read():
                continue
            with open(log, "a", encoding="utf-8") as fh:
                fh.write(f"{time.strftime('%Y-%m-%d %H:%M')} · {where} · {name} · session {session}\n")
            out.append(d)
        except OSError:
            pass
    return out


# ---------- an IC's Bash command that writes a frozen file ----------------------------------------

def bash_write(cmd, records):
    """'chore' when the command runs the chore freeze (freeze-rules with --chore anywhere in the command, the
    quotes and backslashes taken out, or chore_freeze), 'act' when it runs an amendment or a stop1.log
    write, 'write' when it names a frozen file, handoff.md or ic-sessions.log with a write form, 'logs' when
    it names Claude Code's session logs (.claude/projects, or .claude and projects/ apart, as after a cd)
    with a write form (a redirect into a .claude path or a .jsonl, any redirect after a cd there, tee, cp,
    mv, rm, ln, truncate, dd, install, rsync, chmod, sed -i, or a python, perl, ruby or node run), else ''.
    Best effort: the hashes, the chain and ic-sessions.log catch what a command hides; a session log line
    forged in a way this misses is the same class as a stop1.log line forged that way."""
    flat = re.sub(r"[\"'\\]", "", cmd)
    if re.search(r"chore_freeze", flat) or (re.search(r"freeze[-_]rules", flat) and re.search(r"--chore\b", flat)):
        return "chore"
    if re.search(r"amend-frozen|frozen\.py\b[^;&|\n]*\s(amend|stop1-log)\b|frozen\.(amend|stop1_log|write_frozen)\b", cmd):
        return "act"
    tool = re.search(r"(^|[\s;&|(`'\"])(tee|cp|mv|rm|ln|truncate|dd|install|rsync|chmod|python[\d.]*|perl|ruby|node)(\s|$)"
                     r"|\bsed\s+(-[a-zA-Z]*i|--in-place)", cmd)
    if re.search(r"\.claude/+projects\b", flat) or (re.search(r"\.claude\b", flat) and re.search(r"\bprojects/", flat)):
        into = re.search(r">>?\|?\s*[^\s;|&]*(\.claude|\.jsonl\b)", flat) or (
            re.search(r"\bcd\s+[^;&|]*\.claude", flat) and re.search(r"(^|[^&\d])>>?\|?\s*(?!/dev/null|&)", flat))
        if tool or into:
            return "logs"
    strict = re.search(r"frozen\.sha256|stop1\.log|ic-sessions\.log|\b(rules|gate)-pre-[^\s/'\"]*\.md", cmd)
    loose = re.search(r"\b(rules|gate|handoff)\.md\b", cmd) and any(
        x and x in cmd for x in (".fleet-agent-mgmt", records, "FLEET_RECORDS"))
    if not (strict or loose):
        return ""
    into = re.search(r">>?\|?\s*['\"]?[^\s;|&'\"]*(frozen\.sha256|stop1\.log|ic-sessions\.log|rules\.md|gate\.md|handoff\.md|"
                     r"-pre-[^\s/'\"]*\.md)", cmd)
    return "write" if tool or into else ""


# ---------- the command line ------------------------------------------------------------------

def opts(argv, names):
    o, args, it = {}, [], iter(argv)
    for a in it:
        if a in names:
            o[a] = next(it, None)
        else:
            args.append(a)
    return o, args


def main(argv):
    cmd, rest = (argv[1], argv[2:]) if len(argv) > 1 else (None, [])
    if cmd == "verify" and len(rest) == 1:
        reasons = verify(rest[0])
    elif cmd == "check":
        o, args = opts(rest, ("--receipt", "--worktree", "--repo"))
        if len(args) != 1 or None in o.values():
            print(__doc__)
            return 2
        reasons = check(args[0], o.get("--receipt"), o.get("--worktree"), o.get("--repo"))
    elif cmd == "spec":
        o, args = opts(rest, ("--repo",))
        if len(args) != 1 or None in o.values():
            print(__doc__)
            return 2
        record = folder(args[0])
        reasons = [] if fr.legacy(record) or not read_frozen(record) else \
            spec_reasons(record, sys.stdin.read(), o.get("--repo") or os.getcwd())
    elif cmd == "stop1-log":
        o, args = opts(rest, ("--cwd", "--name", "--session"))
        if len(args) != 3 or None in o.values():
            print(__doc__)
            return 2
        reasons = stop1_log(*args, o.get("--cwd") or os.getcwd(), o.get("--name") or "-", o.get("--session") or "-")
    elif cmd == "record" and len(rest) == 1:
        d, refusal = pick_record(rest[0], sys.stdin.read())
        print(refusal or d)
        return 3 if refusal else 0
    elif cmd == "bash-write":
        o, args = opts(rest, ("--name", "--session"))
        if len(args) != 1:
            print(__doc__)
            return 2
        text = sys.stdin.read()
        if o.get("--name"):
            stamp(args[0], o["--name"], o.get("--session") or "-", "Bash", chores=False)
        print(bash_write(text, args[0]))
        return 0
    elif cmd == "stamp" and len(rest) == 4:
        for d in stamp(*rest):
            print(d)
        return 0
    elif cmd == "stop1":
        o, args = opts(rest, ("--cwd",))
        if len(args) != 3 or None in o.values():
            print(__doc__)
            return 2
        reasons = stop1(*args, o.get("--cwd") or os.getcwd())
    elif cmd == "amend" and len(rest) == 3:
        code, out = amend(*rest, os.getcwd())
        for l in out:
            print(l)
        return code
    else:
        print(__doc__)
        return 2
    for r in reasons:
        print(r)
    return 2 if reasons else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
