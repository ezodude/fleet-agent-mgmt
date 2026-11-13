# Filesystem ticket template, personal and non-tracked work, and every research rung.
# Save as <tickets dir>/<KEY-NN>.md beside the specs. Fill every <field>.
# The research shape is at the end. Delete these comment lines.

# <KEY-NN> — <one line, what this rung delivers>

Staged by lead-1, <YYYY-MM-DD>. Committed on the owner's word only.

_Overview._ <Under 10 lines. What, why, the one steer that is easy to miss.>

_Gate block._
  proves done   <outcome, one per line, in outcome words; no commands, the IC writes them in gate.md>
  pass          <exit code / count / summary line, per outcome>
  on failure    do not tick; report the failing line. A fix inside the worktree:
                fix, one DR, re-run, at most 2 re-runs per line; a third red
                goes to the owner. Anything outside the worktree: stop, ask.
  owner's word    <which pane, before which actions>

_Done when_
- [ ] <done-when line> : <its proof>
- [ ] <done-when line> : <its proof>
- [ ] Evidence file complete: $FLEET_HOME/records/<project>/<key-nn>-r<n>/evidence.md, every run with its exit code.

_Standing, every rung on <project>._  (DONE, standing from foundations/definition-of-done.md and PROFILE <project> from $FLEET_HOME/profiles/<project>.md, pasted byte for byte)
<the two blocks>

_Detail._
- Read first: <absolute path> : <why>
- Pre-commit gates: <verbatim from the repo>
- Style source: <absolute path>

# ---- research rung (brief says kind: research) ----

# <KEY-NN> — <the question this rung answers>

Staged by lead-1, <YYYY-MM-DD>. Research: no spec, plan or decision record. Closes on the owner's word.

_Overview._ <Under 10 lines. The question, why it is open now, what the answer decides.>

_Gate block._
  proves done   the analysis at <absolute path, docs/analysis/...>, written with writing-an-analysis
  pass          the analysis answers the question with a recommendation and says what it does not prove
  on failure    stop. Report what could not be answered to lead-1. Do not tick.
  owner's word    <which pane, before which runs, if any touch shared state>

_Done when_
- [ ] The analysis answers the question with a recommendation : screen one of the analysis
- [ ] It says what it does not prove : the OPEN rows of the analysis
- [ ] Evidence file complete: $FLEET_HOME/records/<project>/<key-nn>-r<n>/evidence.md, every run with its exit code.

_Standing, every rung on <project>._  (DONE, standing and PROFILE <project>, pasted byte for byte)
<the two blocks>

_Detail._
- Read first: <absolute path> : <why>
- Not in this rung: the build. The owner's ruling on the analysis becomes the brief of the build rung.
