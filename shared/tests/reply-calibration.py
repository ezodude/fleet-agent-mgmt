#!/usr/bin/env python3
"""The reply calibration: what real Jev answers on review-fix and reply entries.

test-skill-hooks.sh feeds dr_check.py hand-written scores, so it pins the wording and the
threshold plumbing, not what the classifier answers. This set pins the behaviour: each row of
testdata/reply-calibration.tsv is one `decided` line, asked of real Jev as dr_check.py asks it
(the questions of testdata/design-spec.rules.md, the same state fields), twice, with the
scores written back to the row.

Usage
  reply-calibration.py          check the recorded file, no call: the sha in its header is the
                                sha of the questions as they now read, every `stop` row was
                                stop and ask on both runs, every `continue` row continued on
                                both runs with no standing question at BAND or over. Prints
                                "reply calibration: N rows ok"; exit 1 with each row that fails.
  reply-calibration.py --run    ask real Jev (key in JEV_ENV, never printed), 2 runs per row,
                                rewrite the scores and the header, then check. Run it after any
                                change to a standing question, CUT or BAND.

Rows: group, want, kind, decided, then per run the top score of all questions and the top
standing score.
  group  tune    the rows the wording was written against
         held    written before the wording, scored once after it was fixed; never reword against them
         limit   a known miss, recorded and not checked: Jev reads the entry, not the handoff, so it
                 cannot tell that a review fix grows the rung's scope (foundations/pr-comments.md)
  want   continue | stop
  kind   reply | fix | push   picks the entry's undo line
"""
import concurrent.futures, hashlib, json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "hooks"))
import dr_check as d  # noqa: E402

SET = os.path.join(HERE, "testdata", "reply-calibration.tsv")
RULES = os.path.join(HERE, "testdata", "design-spec.rules.md")
PLAN = '7 "answer each review comment on the PR"'
UNDO = {"reply": "gh api -X DELETE repos/acme/atlas/pulls/comments/2190",
        "fix": "git revert d4e5f6a",
        "push": "git revert d4e5f6a, then a plain push"}
RUNS = 2


def questions():
    return d.questions_for(d.read_rules(open(RULES, encoding="utf-8").read()))


def sha(qs):
    """The sha of everything Jev is asked: each question's key, instructions and criteria, and both cuts."""
    asked = [[q.key, q.instructions, q.criteria] for q in qs] + [["CUT", d.CUT], ["BAND", d.BAND]]
    return hashlib.sha256(json.dumps(asked, sort_keys=True).encode()).hexdigest()[:16]


def read_set():
    head, rows = {}, []
    for l in open(SET, encoding="utf-8").read().split("\n"):
        if l.startswith("# ") and ": " in l:
            k, v = l[2:].split(": ", 1)
            head[k] = v
        elif l.strip() and not l.startswith("#"):
            rows.append(l.split("\t"))
    return head, rows


def ask(row, qs, key):
    entry = d.Entry("CAL DR1", 0, 0, {"plan": PLAN, "decided": row[3], "undo": UNDO[row[2]]}, False, False)
    out, model, qs = [], "?", d.asked_of(entry, qs)
    for _ in range(RUNS):
        resp = d.call_jev(d.request_for(entry, qs), key)
        model = resp.get("model", "?")
        ranked = d.scores(resp["answers"], qs)
        standing = [(p, q) for p, q in ranked if q.kind == "STANDING"][0]
        out += [f"{ranked[0][1].key} {ranked[0][0]:.2f}", f"{standing[1].key} {standing[0]:.2f}"]
    return row[:4] + out, model


def run(qs):
    key = d.load_key()
    if not key:
        print("reply calibration: no Jev key (JEV_ENV)")
        return 1
    head, rows = read_set()
    with concurrent.futures.ThreadPoolExecutor(6) as ex:
        done = list(ex.map(lambda r: ask(r, qs, key), rows))
    notes = [l for l in open(SET, encoding="utf-8").read().split("\n") if l.startswith("#") and ": " not in l]
    lines = notes + [f"# model: {done[0][1]}", f"# run: {time.strftime('%Y-%m-%d')}, {RUNS} runs per row",
                     f"# questions: {sha(qs)}"]
    lines += ["\t".join(r) for r, _ in done]
    open(SET, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return 0


def check(qs):
    head, rows = read_set()
    bad = []
    if head.get("questions") != sha(qs):
        bad.append(f"the questions changed since the run (file {head.get('questions')}, now {sha(qs)}): "
                   "run reply-calibration.py --run and read the scores")
    kinds = {q.key: q.kind for q in qs}
    for r in rows:
        if len(r) != 4 + 2 * RUNS:
            bad.append(f"no scores: {r[3][:60]}")
            continue
        if r[0] == "limit":
            continue
        tops = [(c.rsplit(" ", 1)[0], float(c.rsplit(" ", 1)[1])) for c in r[4:]]
        top, standing = tops[0::2], tops[1::2]
        if r[1] == "stop":   # stop and ask on every run: the top score is over the cut on a one-way question
            good = all(p >= d.CUT and kinds.get(k) in d.ONE_WAY_KINDS for k, p in top)
        else:                # continue on every run, and no standing question near the cut
            good = all(p < d.CUT for _, p in top) and all(p < d.BAND for _, p in standing)
        if not good:
            bad.append(f"want {r[1]}, got {' | '.join(r[4:])}: {r[3][:70]}")
    for b in bad:
        print("FAIL " + b)
    n = len([r for r in rows if r[0] != "limit"])
    print(f"reply calibration: {n} rows {'ok' if not bad else 'checked, %d fail' % len(bad)}, "
          f"{len(rows) - n} known limit, {head.get('model', '?')}, {head.get('run', 'no run')}")
    return 1 if bad else 0


if __name__ == "__main__":
    QS = questions()
    if "--run" in sys.argv and run(QS):
        sys.exit(1)
    sys.exit(check(QS))
