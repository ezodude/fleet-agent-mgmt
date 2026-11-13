# Artifact caps

Every artifact answers the questions its reader has, in the reader's order,
and stops. Everything else goes below a fold the reader chooses to open, or
into a pointer. The reason is output volume, and the owner's ruling: review
may replace deep dives only once these caps hold.

## The table

```
  artifact      reader          the reader's questions, in order            cap
  IC rollup     owner, mid-day  what changed / what is blocked /            5 lines
                                what do you need from me
  recap box     owner, every    one line per live IC: rung, stop,           1 line per IC,
                message         awaiting, next, gates, since                down ICs collapsed
  design spec   owner, review   what are we building / what did we          1 screen, then
                                decide / what is still open, each open      one section per
                                item with a recommendation                  component, no cap
  analysis      owner, review   what did you find / what does it decide /   1 screen, then
                                what is still open                          appendix
  ADR           anyone, later   what we decided / why / what we rejected /  no line cap;
                                what it costs                               fleet ADR form,
                                                                            no repetition
  handoff §0    the IC, cold    what is done when / what was decided /      fits screen 1,
                                how do I start                              before the task
  handoff body  the IC, cold    why each ruling / what was rejected /       one section per
                                what constrains the design                  ruling, no cap
  STOP report   lead-1          todo block / pass line beside actual        todo block +
                                output / what the design missed             one line per gate
  close report  owner, cold     shipped as ruled / proved / changed /       1 screen, tables
                                learned / owed                              aligned, appendix
```

One screen is about 45 lines. A fold is a heading the reader has to
scroll to. ADRs have no line cap (the reference ADR ran ~200 lines); their
cap is on repetition and hops, see writing-an-adr.

## Rules

- The cap is measured, not felt. Over the cap is a failed artifact, returned
  with the count.
- Style, headings and depth come from the fleet template of the skill. A
  document in the repo is the style source only when the owner names it as
  vetted in the grill; the ticket carries that path (the existing specs
  "have become complicated - hence this work", in the owner's words).
- Below screen one the cap is on repetition, not lines: each fact once,
  with its source.
- New facts and gotchas patch a spec as dated amendments at the end, never as
  a rewrite of the body. The reader who has already read the body reads only
  the amendment.
- Verdict before detail, in every artifact, including corrections.
- The reader's questions are the section headings. If a section does not
  answer one of them, it is below the fold.

## Why

fournier-tech-lead.md: a lead who must hold every detail personally has not
scaled. The caps are what let review stand in for a deep dive. Until they
hold, the deep dive stays.
