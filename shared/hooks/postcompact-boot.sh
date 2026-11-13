#!/bin/bash
# SessionStart hook, matcher "compact". Runs AFTER a compaction, manual or
# auto, in every session on this machine (installed at user level).
# Prints a SHORT brief (~600 tokens) that Claude Code adds to the new context:
#   1. the session's STATE (lead: the ```state block at the top of its
#      LEDGER.md; ic: ~/.fleet-agent-mgmt/checks/<roster name>/STATE.md, else the newest
#      lead-1 ledger entry naming it; solo: none),
#   2. one git line for cwd,
#   3. the ONE in-flight user prompt (the last real one; compaction summaries,
#      skill bodies, interrupt notices and harness rows are skipped),
#   4. a role-specific FIRST ACTION.
# Role comes from FLEET_HOME/roster.md (the fenced fleet block): the lead-1 row
# = lead; any other row = ic; no row = solo. Never types into a pane, never
# writes state: durable state is written BEFORE compaction (STATE, ledger,
# rung handoff, git) and read FIRST after. A copy of the brief is kept under
# $HANDOFF_ROOT/<cwd slug>/ as evidence that the hook fired. Exits 0 always,
# even on an internal error (the error is printed instead of the brief).
set -uo pipefail
HANDOFF_ROOT="${HANDOFF_ROOT:-$HOME/.claude/handoffs/auto}"
. "$(cd -P "$(dirname "$0")" && pwd)/../lib/paths.sh"
ROSTER="${FLEET_ROSTER:-$FLEET_HOME/roster.md}"
LEAD_LEDGER="${LEAD_LEDGER:-$FLEET_HOME/Leads/lead-1/LEDGER.md}"
CHECKS="${STATE_CHECKS:-$FLEET_HOME/checks}"
PROMPT_CAP="${HANDOFF_PROMPT_CAP:-700}"
HOOK_JSON="$(cat 2>/dev/null || true)"
export HOOK_JSON ROSTER LEAD_LEDGER CHECKS PROMPT_CAP HANDOFF_ROOT
python3 - <<'PY' || echo "postcompact-boot.sh: internal error (see stderr); boot per CLAUDE.md from files."
import json, os, re, sys, datetime, pathlib, subprocess, traceback

def main():
    env = os.environ
    try:
        hook = json.loads(env.get("HOOK_JSON") or "{}")
    except Exception:
        hook = {}
    cwd = os.path.realpath(hook.get("cwd") or os.getcwd())
    tpath = hook.get("transcript_path", "")
    source = hook.get("source") or "unknown"
    sid = (hook.get("session_id") or "nosession")[:8]
    now_l = datetime.datetime.now().astimezone()
    now_u = now_l.astimezone(datetime.timezone.utc)
    stamp = f"{now_l:%a %Y-%m-%d %H:%M %Z} ({now_u:%H:%M}Z)"

    # --- role from the roster's fenced fleet block -------------------------
    role, name = "solo", ""
    try:
        txt = pathlib.Path(env["ROSTER"]).read_text(errors="replace")
        block = txt.split("```fleet", 1)[1].split("```", 1)[0]
        for line in block.strip().splitlines():
            parts = line.split("\t")
            if len(parts) >= 2 and os.path.realpath(parts[1].strip()) == cwd:
                name = parts[0].strip()
                role = "lead" if name == "lead-1" else "ic"
                break
    except Exception:
        pass

    # --- git line ---------------------------------------------------------
    def git(*a):
        try:
            return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True, timeout=10).stdout.strip()
        except Exception:
            return "?"
    branch, head = git("rev-parse", "--abbrev-ref", "HEAD"), git("rev-parse", "--short", "HEAD")
    dirty = len(git("status", "--short").splitlines()) if head != "?" else "?"
    up = git("rev-parse", "--abbrev-ref", "@{u}")
    if up and not up.startswith("fatal") and up != "?":
        ab = git("rev-list", "--left-right", "--count", f"{up}...HEAD").split()
        pushed = f"upstream {up}, behind {ab[0]} ahead {ab[1]}" if len(ab) == 2 else f"upstream {up}"
    else:
        pushed = "NO UPSTREAM (unpushed)" if branch != "HEAD" else "detached"
    gitline = f"{branch} @ {head}; dirty {dirty}; {pushed}" if head and head != "?" else "not a git repository"

    # --- state ------------------------------------------------------------
    state, state_src = "", ""
    if role == "lead":
        p = pathlib.Path(cwd) / "LEDGER.md"
        try:
            t = p.read_text(errors="replace")
            state = t.split("```state", 1)[1].split("```", 1)[0].strip()
            state_src = f"{p} (```state block)"
        except Exception:
            state_src = f"{p}: NO ```state block found"
    elif role == "ic":
        p = pathlib.Path(env["CHECKS"]) / name / "STATE.md"
        if p.exists():
            state = re.split(r"(?m)^## log", p.read_text(errors="replace"), maxsplit=1)[0].strip()
            state_src = str(p)
        else:
            state_src = f"{p} MISSING; derived from lead-1's ledger"
            try:
                lines = pathlib.Path(env["LEAD_LEDGER"]).read_text(errors="replace").splitlines()
                entries, cur = [], []
                for l in lines:
                    if re.match(r"^\+\d+ \(", l):
                        if cur: entries.append(cur)
                        cur = [l]
                    elif cur:
                        cur.append(l)
                if cur: entries.append(cur)
                for e in entries:
                    if name in "\n".join(e):
                        state = "\n".join(e[:20]); break
                if not state:
                    state = f"(no lead-1 ledger entry names {name})"
            except Exception as ex:
                state = f"(lead-1 ledger unreadable: {ex})"
    handoff = ""
    m = re.search(r"^handoff:\s*(\S+)", state, re.M)
    if m: handoff = m.group(1)

    # --- the one in-flight prompt ----------------------------------------
    prompt, ptag, pts = "", "", ""
    if tpath and os.path.exists(tpath):
        with open(tpath, errors="replace") as fh:
            for line in fh:
                try: o = json.loads(line)
                except Exception: continue
                if o.get("type") != "user" or o.get("isSidechain") or o.get("isCompactSummary"):
                    continue
                c = o.get("message", {}).get("content")
                t = c if isinstance(c, str) else "\n".join(b.get("text", "") for b in (c or []) if isinstance(b, dict) and b.get("type") == "text")
                s = t.strip()
                if (not s or s.startswith("<") or "Base directory for this skill" in s
                        or s.startswith("[Request interrupted") or s.startswith("[Cross-session idle notice]")
                        or s.startswith("Stop hook feedback:") or re.match(r"/[a-z][\w-]*(\s|$)", s)):
                    continue  # harness rows, the gate's own bounce, slash commands (/compact, /clear)
                m2 = re.search(r'<cross-session-message[^>]*?from-name="([^"]*)"[^>]*>(.*?)</cross-session-message>', s, re.S)
                if m2:  # harness wrapper around a peer's message: keep the body, tag the sender
                    ptag, s = f"cross-session message from {m2.group(1)}", m2.group(2).strip()
                elif "<cross-session-message" in s:
                    ptag, s = "cross-session message", s.split("<cross-session-message", 1)[1].split(">", 1)[-1].strip()
                else:
                    ptag = "typed in this session's pane"
                prompt, pts = s, o.get("timestamp", "")
    if len(prompt) > int(env["PROMPT_CAP"]):
        prompt = prompt[: int(env["PROMPT_CAP"])] + " … [clipped]"

    # --- first action -----------------------------------------------------
    hp = f" named in the state ({handoff})" if handoff else ""
    if role == "lead":
        action = (f"You are lead-1. Do NOT write a handoff now. Boot per CLAUDE.md (files win over this brief), open the "
                  f"handoff{hp}, re-verify the state's anchors with your own reads, read the clock before stamping, "
                  "then state in ONE message the goal of the current work and your next step, and WAIT for the owner: "
                  "do not launch, dispatch or send anything.")
    elif role == "ic":
        action = (f"You are {name}. Do NOT write a handoff now. Re-orient from your rung handoff{hp} and the state above, "
                  "verify git with your own reads, state in one line the goal and your next step, then CONTINUE the "
                  "rung where you were. If the state says you were holding at a STOP, re-send that report to lead-1 "
                  "and hold again. Do not wait for a human.")
    else:
        action = ("No fleet row for this directory. Re-orient from git and the in-flight prompt above, state in one "
                  "line the goal and your next step, then continue.")

    parts = [f"# Post-compaction brief — {stamp} — source: {source} — role: {role}{(' ' + name) if name else ''}",
             "MECHANICAL, from files on disk, nothing re-verified. Files win over this brief; this brief wins over the summary.",
             f"- cwd: {cwd}", f"- git: {gitline}", f"- transcript on disk: {tpath or '?'}",
             f"- state source: {state_src or 'none (solo)'}"]
    if state:
        parts += ["", "## STATE", state]
    parts += ["", f"## In-flight prompt ({ptag or 'none found'}{(' @ ' + pts) if pts else ''})", prompt or "(none)",
              "", "## FIRST ACTION", action]
    out = "\n".join(parts) + "\n"
    try:
        slug = re.sub(r"[^A-Za-z0-9._-]+", "-", cwd.strip("/")).strip("-")[-80:]
        d = pathlib.Path(env["HANDOFF_ROOT"]) / slug
        d.mkdir(parents=True, exist_ok=True)
        f = d / f"{now_l:%Y-%m-%d-%H%M}-{sid}-{source}-brief.md"
        f.write_text(out)
        latest = d / "LATEST.md"
        if latest.exists() or latest.is_symlink(): latest.unlink()
        latest.symlink_to(f.name)
        out = f"A compaction just happened. Brief (copy at {f}):\n\n" + out
    except Exception:
        out = "A compaction just happened. Brief (copy not written):\n\n" + out
    sys.stdout.write(out)

try:
    main()
except Exception:
    traceback.print_exc(file=sys.stderr)
    print("postcompact-boot.sh: internal error; boot per CLAUDE.md from files (ledger, rung handoff, git).")
sys.exit(0)
PY
exit 0
