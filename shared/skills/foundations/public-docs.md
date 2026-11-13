# Public docs

Any doc an IC commits to a product repo is public: a design spec, a plan,
an ADR, an analysis, a README or doc. The team, PR reviewers and anyone
with repo access read it on GitHub, as rendered markdown. It is written for
them. It never names the fleet. The design spec's shape is in
`writing-a-design-spec`.

This rule exists because one design spec shipped record paths, a Reply:
line, STOP 1 and the IC's name into a publicly viewable file, and
rendered as a mess on GitHub. The owner: "the design spec is
publicly viewable, we cannot mention the fleet or handoffs in it".

## Never in a committed doc

```
  paths          any absolute local path: a home-folder path, ~/..., /private/tmp, /tmp
  fleet files    .fleet-agent-mgmt, ~/.claude, checks/, records/<project>/...
                 a record-folder file named as a fleet artefact: handoff.md, brief.md,
                 decision-record.md, evidence.md, rules.md, gate.md, close.md, receipts/
  fleet names    lead-1, any IC roster name (the fleet block of $FLEET_HOME/roster.md),
                 "the IC", "the fleet", "the owner"
  process words  STOP n, "screen one", "spec ok", "Reply:", "handoff", PROFILE,
                 "gate block", jev, band
  fleet ids      DR<n>, UAT<n>, E<n> evidence ids, lane-prefixed decision ids (ATL-42 D2)
  skill files    one-way.md, foundations/, writing-a-design-spec, superpowers:...
```

Write the person's role in the team instead of "the owner" (the product
owner), or cite the source ticket. A Jira key on its own (ATL-42) is fine;
it is the team's ticket. Sources cite what the team can open: the Jira
ticket, a repo file and line, an incident id, a dated team channel
message, a PR. Never the brief, the handoff or the record.

## Always renders

- A blank line between every block: after the title, between paragraphs,
  before and after every heading, list, table and fence, and before a
  `---` rule. A `---` straight under text turns that text into a heading.
- Section titles are `##` headings, not ALL-CAPS lines.
- Rows of facts (terms, one-way, decided, rejected, the checks) are
  Markdown tables; a `|` inside a cell is written `\|`. Diagrams and
  other column-aligned text sit inside ``` fences, so alignment and line
  breaks survive. Prose and lists stay outside fences.
- Before commit: no line of text directly above a `---`; every fence
  opened is closed.

## The two hook checks

```
  the IC writes a doc                          the IC runs git push or gh pr create
        │                                               │
  artefact-gate.sh (Write, Edit, MultiEdit)      push-gate.sh, leak gate
    path */specs/*.md, */plans/*.md,               the added lines of the diff from
    */adr/*.md, */analysis/*.md, not under         the merge-base with origin's default
    ~/.fleet-agent-mgmt, ~/.claude or /tmp         branch, every file
    the text after the edit, for:                  paths and names only:
      home paths  ~/  .fleet-agent-mgmt              home paths  .fleet-agent-mgmt
      .claude/checks  lead-1  roster IC names        .claude/checks  lead-1
      STOP <n>  "screen one"  "spec ok"              roster IC names
      ^Reply:  ^style:  ^source:  ^record:         no DR or E ids: code may use them
      DR<n>  UAT<n>  E<n>  "the IC"
      decision-record  evidence.md  handoff.md
    specs only: text directly above `---`,
      an odd count of ``` fence lines
        │                                               │
  a hit ──▶ deny: each hit with its line, and    a hit ──▶ deny with file:line
            how to rewrite it (cite the ticket,            catches a doc written
            a repo file, or drop it)                       through Bash
```

The hooks catch common patterns; they do not prove a doc clean. "the
owner", a skill name or "handoff" pass both and are still leaks.

## What stays a fleet document

The record folder, the STOP reports, the decision record, the evidence,
rules.md, gate.md and the close keep their fleet words. They are never
committed to a product repo. What a spec used to carry for the fleet (the
style, source and record lines, the reply words) goes in the STOP 1 report.
