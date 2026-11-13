# STOP report template, IC side. One row per step, glyph first: ✔ done,
# ✖ failed gate, ● in progress, ○ not started. Expected beside actual.
# Then the facts lead-1 needs, one line each: stakes, options with cost and
# no recommendation, anything believed but unproven, new fact, word, files.
# Save the message to $FLEET_HOME/checks/<ic>/stop-<n>.md, send it, end the turn.
# lead-1's haiku check reads that file, not the message.
# A red gate line is not ticked. A fix inside the worktree is re-run without
# the word, one DR each, at most 2 per line; a third red on the line, or a
# fix outside the worktree that the profile's sandbox (cap 2) does not
# cover, is reported here and held.
# Example values are INVENTED (birch-sbx, SBOX-71 rung 1). Replace all of them.

birch-sbx · SBOX-71 r1 · STOP 3 · 11:08 · holding: step 4 red, the re-run touches the space outside the worktree, needs the word

  ✔ 1  space rebuilt        10:12   exit 0 · "0 errors"       = pass
  ✔ 2  instructions loaded  10:30   -
  ✔ 3  dry run              10:41   exit 0 · 5 answers        = pass
  ✖ 4  benchmark            11:05   "4 of 5 correct"          ≠ pass "5 of 5"      not ticked
  ○ 5  write-up             -       blocked by 4

  stakes     client demo 2026-10-06; no regulated control, money or prod touched
  options    a) add the variant to the instructions, rerun    ~20m, instructions file changes
             b) rerun as is, treat 4 of 5 as pass              needs a dated DoD line from the owner
  unverified that the miss is a wording variant and not a reasoning gap: my reading of one answer
  new fact   the missed question is a wording variant of benchmark 3; the instructions never name it
  word       the owner's, in this pane, before each run: 10:10, 10:40, 11:05
  files      stop $FLEET_HOME/checks/birch-sbx/stop-3.md · evidence …/sbox-71-evidence.md · STATE 11:08

# STOP 1 variant: screen one of the spec is up for the owner's direction review.
# The spec is a public repo doc (foundations/public-docs.md), so the lines it does
# not carry go here: spec (repo path @ sha, nothing after the sha), source (the
# handoff path and its time), record (the record folder), one card line per open
# item (id · question · the plan task it blocks · options · rec · its reply words),
# reply (the two strings). `reply` stands for options; `new fact` and `word` only
# when there is one. Rows: the spec commit with the count (N content lines + Terms t
# + Checks c), then each Checks command run once on origin/main.
# STOP 1 comes before the freeze: no receipt. The send is checked instead: the spec
# at the spec line's sha freezes as written, no `on main` cell is a placeholder, and
# evidence.md has one entry per Checks command run at origin/main (recording-evidence).
# The sha on the spec line is the one the freeze takes as --approved.
# Example values are INVENTED (atlas-ic, ATL-42 rung 1). Replace all of them.
# A real report writes each path in full; the STOP gate reads the record folder.
atlas-ic · ATL-42 r1 · STOP 1 · 15:10 · holding: screen one for the owner's direction review

  ✔ 1  spec committed    15:02   4f1d2c9 · 20 content lines + Terms 2 + Checks 2   = pass "under 45"
  ✔ 2  make test, main   14:40   E1 exit 0 · "212 passed, 0 failed"           = pass
  ✖ 3  dry run, main     14:48   E2 exit 2 · "No rule to make target"         red, the rung builds it   not ticked

  spec       docs/superpowers/specs/2026-09-14-atl-42-retry-design.md @ 4f1d2c9
  source     …/atl-42-r1/handoff.md @ 2026-09-14 10:20
  record     $FLEET_HOME/records/atlas/atl-42-r1/
  card       ? ATL-42 D1 · where the 21 minute wait runs · blocks plan task 1 · a) sleep on the thread b) reschedule · rec b, schedule_at() exists · reply "ATL-42 D1 b"
  reply      "ATL-42 spec ok" approves screen one and freezes the rules · "ATL-42 spec back: <line>" sends it back
  stakes     none beyond the rung; the shared dev database is touched only with the word
  unverified that importer.run() returns a short count on a partial file: read at lines 40-58, not run
  files      stop $FLEET_HOME/checks/atlas-ic/stop-1.md · evidence.md in record · STATE 15:10
