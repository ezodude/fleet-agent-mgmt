<!--
ADR template. This file IS the form; no external reference is needed.
Sections in this order. Rows marked (when it exists) and sections marked
(situational) are omitted, never left blank. Example values INVENTED
(ROW-12). Replace every value; keep the order. Delete this comment and
strip every (situational) and (when it exists) marker before publishing.
-->

# ADR-007: Cession vocabulary is a closed enum

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-09-14 |
| **Drivers** | product owner; treaty ingest team |
| **Approver** | head of reinsurance data (when it exists) |
| **Epic** | ROW-10 Treaty ingest (when it exists) |
| **Discovery** | ROW-11 vocabulary spike (when it exists) |
| **Relates to** | ADR-006 (treaty identifier) |

## Decision

The treaty cession vocabulary is a **closed enum of 41 terms, version v1**. A term outside it fails ingest loudly.

The cost of a new term is paid once, by us, at a known moment, on the record. Everything below follows from that.

## Problem

Reinsurance treaties name their cession type in free text. The 2025 pilot stored that text as received and produced 9 spellings of "quota share"; reconciliation took 3 days (ROW-4, 2025-11-20).

```
   TODAY                                   WHAT IS MISSING
   treaty file ──▶ cession text stored     +----------------------------------+
   as received                             |  ONE SPELLING PER TERM           |
       │                                   |    a known list, versioned       |
       ▼                                   |    a new term is a decision,     |
   reconciliation finds 9 spellings,       |    not a typo                    |
   3 days to map by hand                   +----------------------------------+
```

## Options

**A — Closed enum (chosen).** 41 terms from 3 treaty documents and the 2024 Lloyd's minimum standards glossary; 0 unmapped after review on 2026-09-14. A new term is a dated amendment and a version bump.

**B — Free text (not chosen).** What the pilot did.

**C — Enum with an `other` member (not chosen).** Reopens the list by the back door; nobody fixes a mapping once `other` exists.

| | A CLOSED ENUM | B FREE TEXT | C ENUM + OTHER |
|---|---|---|---|
| spellings per term | 1 | 9 in the pilot | 1, plus an open bucket |
| new term | amendment + version bump, one PR | nothing | lands in `other`, silent |
| reconciliation | none | 3 days in the pilot | grows with `other` |
| ingest of an unknown term | fails, names the term | accepted | accepted as `other` |

## Decision outcome

Adopt A. Two facts back it.

**Cost lands once.** A new term costs one amendment and one PR, at a known moment, by us. Free text and `other` push the same cost to reconciliation, every quarter, on whoever is reconciling.

**The record shows the decision.** The amendment line says who added the term and when. A mapping fixed by hand in a spreadsheet does not.

## Evidence (situational)

Dry run 2026-09-13 on the 3 treaty documents with the 41-term enum:

| INPUT | ROWS | UNMAPPED | RESULT |
|---|---|---|---|
| treaty T-2026-101 | 212 | 0 | ingested |
| treaty T-2026-104 | 88 | 0 | ingested |
| treaty T-2026-118 | 140 | 1 (`stop loss, aggregate`) | failed, term named |

The one failure is the mechanism working; the term went to the amendment queue. Probe repo torn down after the run.

## Consequences

- **Positive.** One spelling per term; consumers treat the vocabulary as total, 41 cases, no unknown branch.
- **Cost.** A counterparty sending a new term breaks its ingest visibly until someone rules on the term.
- **Watch.** Amendment latency: if a ruling takes more than a day, the ingest queue backs up. Review at the first amendment.

## Confirmation

| ITEM | OWNER | STATE |
|---|---|---|
| product owner approves option A | product owner | done, ROW-12 comment 2026-09-14 |
| enum v1 committed with the 41 terms | treaty ingest team | open |
| ingest allowlist reads the enum, fails loudly | treaty ingest team | open |
| first amendment exercised end to end | treaty ingest team | open |

## Glossary (situational)

- **cession**: the share of a risk a cedant passes to a reinsurer under a treaty.
- **quota share**: a cession where the reinsurer takes a fixed percentage of every risk.
- **allowlist**: the set of values ingest accepts; anything else is rejected.

## More information

- Lloyd's minimum standards glossary, 2024 edition: https://www.lloyds.com/conducting-business/requirements-and-standards
- ROW-4 pilot reconciliation notes, 2025-11-20: https://github.com/example-org/rowan/issues/4
- Decision: ROW-12, product owner comment, 2026-09-14: "keep the enum closed".
- ADR-006 treaty identifier: docs/adr/0006-treaty-identifier.md
