# Writing rules, every artefact

The owner's words: "always provide citations and links";
"tabular data based comparison or confirmations should use tables not
diagrams"; "brevity, clarity, cohesion and no text walls that block
understanding"; a glossary "if we're presenting info to a CTO or Lead not
familiar with the subject matter".

## Table or diagram

| CONTENT | SHAPE | EXAMPLE |
|---|---|---|
| options differing in attributes: cost, identity, grants, time | table, one row per option, one column per attribute | ADR template, the options table |
| a checklist, a confirmation list, a status per item | table, one row per item, owner and state columns | ADR template, Confirmation |
| findings with their proof | table or aligned rows, proof beside each | analysis FOUND rows |
| a flow with a fork, gate or failure path | diagram | ADR template, Problem |
| topology, what connects to what | diagram | design spec `## Building` |
| two candidate shapes side by side, when they differ in flow | diagram | two flows that fork differently |
| a single fact, or under two lines | prose | |

A diagram never carries a comparison of numbers. A table never carries a
sequence. When both apply, the table holds the attributes and the diagram
holds the flow, each once.

## Citations and links

Every fact from outside the artefact carries its source on the same line:
a URL, a ticket key, a file path with lines, a meeting with a date, a
person with a date. A section `More information` at the end collects the
links a reader may follow. A claim with no source is marked `unverified`.

## Glossary

When the reader may not know the subject (a CTO, a lead from another
team, a new IC), a `Glossary` section sits before `More information`: one
line per term, the term first, no more than ten. Terms the artefact
defines inline on first use do not repeat there.

## Text walls

No paragraph over five lines. No section over one screen without a table
or diagram in it. Prose annotates the table or diagram; it does not restate
it. Verdict before detail, in every section.

## Docs committed to a product repo

A spec, plan, ADR or analysis committed to a product repo is public: the
team reads it on GitHub. It follows `foundations/public-docs.md`: no fleet
terms, and it renders as markdown.

## Publish, then read back

The owner: "I expect these checks after creating docs or prose".
ADR-013 went to Confluence with its paragraphs merged: single
newlines in the markdown became one paragraph, and nobody read it back.

After every create or update of a doc outside the repo (Confluence, Jira,
a PR body), before reporting it done:

1. Read the published version back, as HTML where the tool offers it.
   Markdown read-back hides how the page was built.
2. Check the markup: no raw newline inside a paragraph (two lines merged),
   tables are tables, code blocks intact, zero em-dashes.
3. Check each section against Table or diagram above: a comparison drawn
   as a diagram is a miss, even when the rule was known.
4. Report the version number, what the read-back showed, and what it did
   not check: how the page looks in a browser needs a screenshot or the
   owner's eyes.
