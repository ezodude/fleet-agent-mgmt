#!/bin/bash
# Tests for shared/records/precedents-gather.sh, shared/records/precedents_gather.py and shared/records/precedents-check.sh, against invented close
# reports in a temp dir (project atlas, lane ATL-4x). Never touches ~/.fleet-agent-mgmt.
#   shared/tests/test-precedents.sh            prints one line per case, then "N pass, M fail"; exit 1 on any fail
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok    $1"; else fail=$((fail+1)); echo "FAIL  $1"; echo "      got:  $2"; echo "      want: $3"; fi; }
G="$HERE/records/precedents-gather.sh"
ROOT="$T/records"; A="$ROOT/atlas"
mkdir -p "$A/atl-40-r1" "$A/atl-41-r1/sources" "$A/atl-42-r1" "$A/atl-43-r1" "$A/sources" "$ROOT/beacon/atl-50-r1"

# atl-40-r1: the template's shape. A section title at the left edge, a table under it; screen one ends at ---,
# so the appendix's "### CHANGED, every entry" table is never read. OWED's table sits at the left edge.
cat > "$A/atl-40-r1/close.md" <<'EOF'
close · atlas-ic · ATL-40 rung 1 · retry failed nightly imports · 2026-09-16 15:40 · merged 7c1e2a9

Verdict: ✔ shipped as designed. Reply `ATL-40 close ok` or `ATL-40 close back: <line>`.

PROVED, every gate in the ticket

  | GATE        | PASS LINE  | ACTUAL OUTPUT | DOES NOT PROVE |
  |-------------|------------|---------------|----------------|
  | ✔ make test | exit 0     | exit 0        | the wait       |

CHANGED, decisions taken after the handoff (from decision-record.md)

  | ID          | QUESTION             | DECIDED                           | CONSEQUENCE IN THE CODE | BY, REVIEW   |
  |-------------|----------------------|-----------------------------------|-------------------------|--------------|
  | ATL-40 DR1  | what the retry wraps | scheduler.nightly(), not importer | retry.py wraps the call | atlas-ic, ok |
  | ATL-40 D2   | where the wait runs  | b) reschedule the job             | no sleep                | owner        |

```
NUMBERS  DRs 2 · jev rework 0 · band 0
PROFILE  unchanged
```

LEARNED, what bites the next rung

  | KIND       | FACT                                                               | EVIDENCE             |
  |------------|--------------------------------------------------------------------|----------------------|
  | went wrong | the grill assumed a sleep was safe; the scheduler thread is shared | scheduler.py line 30 |
  | got lucky  | a second failing file in the same minute would have been swallowed | alerts.py line 22    |

OWED, what this rung leaves behind

| ITEM                                | OWNER  | STATE            |
|-------------------------------------|--------|------------------|
| partial-file format from the vendor | ATL-44 | filed 2026-09-16 |

---
## Appendix

### CHANGED, every entry

  | ID         | QUESTION       | DECIDED      |
  |------------|----------------|--------------|
  | ATL-40 DR9 | APPENDIX-ONLY  | never read   |
EOF

# atl-41-r1: the compact shape. The section is the first cell of the table's header row ("| LEARNED: KIND");
# no blank line between tables; PROVED's table is not a section the sweep reads. LEARNED row 2 says the same
# thing as atl-40-r1 LEARNED row 1, in other spacing and case.
cat > "$A/atl-41-r1/close.md" <<'EOF'
close · atlas-ic · ATL-41 rung 1 · alert names the file · 2026-09-20 11:00 · merged 1a2b3c4
Verdict: ✔ shipped as designed.
SHIPPED   designed   scheduler ──▶ retry ──▶ alert
  | PROVED: GATE   | PASS LINE | ACTUAL OUTPUT |
  | ✔ 1 make test  | exit 0    | exit 0        |
  not proved by any gate: the alert reaches a phone
  | CHANGED: ID    | QUESTION           | DECIDED            |
  | ATL-41 DR1     | alert text         | names the file     |
NUMBERS  DRs 1 · jev rework 0
  | LEARNED: KIND  | FACT                                                               | EVIDENCE |
  | went well      | the dry run caught the missing file name before the merge          | E12      |
  | went wrong     | The grill assumed a sleep was safe;  the scheduler thread is shared | scheduler.py line 30 |

  | OWED: ITEM     | OWNER  | STATE     |
  | ops dashboard tile for retries | owner | to decide |
  | page ops on the third failure  | owner | to decide |
---
EOF
printf 'SENTINEL-SOURCES-IN-RECORD\nLEARNED, x\n  | KIND | FACT |\n  |---|---|\n  | went wrong | SENTINEL-ROW |\n' > "$A/atl-41-r1/sources/close.md"
printf '# ATL-41 rung 1 · decision record · atlas-ic\nSENTINEL-DECISION-RECORD\n' > "$A/atl-41-r1/decision-record.md"

# atl-42-r1: no close.md yet (the rung being briefed, or one still open)
printf '# ATL-42 · atlas · brief\n' > "$A/atl-42-r1/brief.md"

# a sources/ folder at the project level is never read, even with a close.md inside that has a LEARNED row
mkdir -p "$A/sources/x-r1"; printf 'close · SENTINEL-SOURCES-PROJECT\n\nLEARNED, x\n\n  | KIND | FACT |\n  |---|---|\n  | went wrong | SENTINEL-SOURCES-ROW |\n' > "$A/sources/close.md"; printf 'LEARNED, x\n  | went wrong | SENTINEL-SOURCES-DEEP |\n' > "$A/sources/x-r1/close.md"

# atl-43-r1: CRLF line ends, a LEARNED section that says none, no OWED section, a bullet row
printf 'close · atlas-ic · ATL-43 rung 1 · research on vendor formats · 2026-09-25 09:00 · closed\r\n\r\nCHANGED, rulings taken after the handoff\r\n\r\n  - the owner ruled the vendor format out of scope\r\n\r\nLEARNED, what bites the next rung\r\n\r\n  none\r\n\r\n---\r\n' > "$A/atl-43-r1/close.md"

out="$("$G" --root "$ROOT" atlas 2>&1)"; rc=$?
printf '%s\n' "$out" > "$T/out.txt"
check "gather: exit 0" "$rc" 0
check "gather: header names the project, the count and the folder" "$(head -1 "$T/out.txt")" "precedents · atlas · 3 close reports · $A"
check "gather: records in order, each with its title line" "$(grep '^== ' "$T/out.txt" | cut -d' ' -f1-8)" "$(printf '== atl-40-r1 · close · atlas-ic · ATL-40\n== atl-41-r1 · close · atlas-ic · ATL-41\n== atl-43-r1 · close · atlas-ic · ATL-43')"
check "gather: template shape, CHANGED rows referenced" "$(grep -c '^  atl-40-r1 · CHANGED · row [0-9]' "$T/out.txt")" 2
check "gather: template shape, a row's cells joined" "$(grep '^  atl-40-r1 · CHANGED · row 2 ' "$T/out.txt")" "  atl-40-r1 · CHANGED · row 2   ATL-40 D2 | where the wait runs | b) reschedule the job | no sleep | owner"
check "gather: template shape, LEARNED row 1" "$(grep '^  atl-40-r1 · LEARNED · row 1 ' "$T/out.txt")" "  atl-40-r1 · LEARNED · row 1   went wrong | the grill assumed a sleep was safe; the scheduler thread is shared | scheduler.py line 30"
check "gather: template shape, OWED row 1" "$(grep '^  atl-40-r1 · OWED · row 1 ' "$T/out.txt")" "  atl-40-r1 · OWED · row 1   partial-file format from the vendor | ATL-44 | filed 2026-09-16"
check "gather: the column names print once per section, not as a row" "$(grep -c '^LEARNED   KIND | FACT | EVIDENCE$' "$T/out.txt"):$(grep -c '· row [0-9]*   KIND | FACT' "$T/out.txt")" "2:0"
check "gather: separator rows are not rows" "$(grep -c '· row [0-9]*   -' "$T/out.txt")" 0
check "gather: nothing after --- is read (the appendix table)" "$(grep -c 'APPENDIX-ONLY' "$T/out.txt")" 0
check "gather: PROVED, SHIPPED and NUMBERS are not swept" "$(grep -c -e '· PROVED ·' -e 'make test' -e 'NUMBERS' -e 'SHIPPED' "$T/out.txt")" 0
check "gather: compact shape, the header cell names the section" "$(grep '^  atl-41-r1 · CHANGED · row 1 ' "$T/out.txt")" "  atl-41-r1 · CHANGED · row 1   ATL-41 DR1 | alert text | names the file"
check "gather: compact shape, a left-edge line ends the section" "$(grep -c '^  atl-41-r1 · CHANGED · row' "$T/out.txt")" 1
check "gather: compact shape, the column names without the section word" "$(grep -c '^LEARNED   KIND | FACT | EVIDENCE$' "$T/out.txt")" 2
check "gather: compact shape, OWED after a blank line" "$(grep -c '^  atl-41-r1 · OWED · row [12] ' "$T/out.txt")" 2
check "gather: a duplicate row is printed and points at the first one" "$(grep '^  atl-41-r1 · LEARNED · row 2 ' "$T/out.txt" | sed 's/.*   (/(/')" "(same text as atl-40-r1 · LEARNED · row 1)"
check "gather: only the duplicate is marked" "$(grep -c 'same text as' "$T/out.txt")" 1
check "gather: a record with no close.md is named once at the end" "$(tail -1 "$T/out.txt")" "no close.md   atl-42-r1"
check "gather: no sources/ folder is read, in a record or the project" "$(grep -c 'SENTINEL' "$T/out.txt")" 0
check "gather: only close.md is read in a record" "$(grep -c -e 'decision record' -e 'brief' "$T/out.txt")" 0
check "gather: CRLF read, no carriage return printed" "$(grep -c $'\r' "$T/out.txt")" 0
check "gather: a bullet line is a row" "$(grep '^  atl-43-r1 · CHANGED · row 1 ' "$T/out.txt")" "  atl-43-r1 · CHANGED · row 1   the owner ruled the vendor format out of scope"
check "gather: a section that says none prints none" "$(awk '/^== atl-43-r1/{f=1} f && /^LEARNED/' "$T/out.txt")" "LEARNED   none"
check "gather: a missing section says so" "$(awk '/^== atl-43-r1/{f=1} f && /^OWED/' "$T/out.txt")" "OWED      none: no OWED section"
check "gather: the same input prints the same output" "$("$G" --root "$ROOT" atlas | cmp -s - "$T/out.txt" && echo same || echo changed)" same
check "gather: FLEET_RECORDS is the default root" "$(FLEET_RECORDS="$ROOT" "$G" atlas | cmp -s - "$T/out.txt" && echo same || echo changed)" same

# no close report at all: a first rung on a project
out="$("$G" --root "$ROOT" beacon 2>&1)"; rc=$?
check "none: a project with no close report prints the none line, exit 0" "$rc:$out" "0:none: no close report for beacon"
mkdir -p "$ROOT/comet"
check "none: an empty project folder too" "$("$G" --root "$ROOT" comet 2>&1; echo "rc=$?")" "$(printf 'none: no close report for comet\nrc=0')"

# refusals: a plain reason, non-zero, nothing on stdout
out="$("$G" --root "$ROOT" nope 2>"$T/err")"; rc=$?
check "refuse: a missing project exits 2, stdout empty" "$rc:$out" "2:"
check "refuse: the reason names the project and lists the ones there" "$(cat "$T/err")" "precedents-gather: no project nope under $ROOT (projects: atlas, beacon, comet)"
check "refuse: a missing records root" "$("$G" --root "$T/none" atlas 2>&1; echo "rc=$?")" "$(printf 'precedents-gather: no records root %s\nrc=2' "$T/none")"
check "refuse: no project given" "$("$G" --root "$ROOT" 2>&1 >/dev/null | head -1; "$G" --root "$ROOT" >/dev/null 2>&1; echo "rc=$?")" "$(printf 'usage: precedents-gather.sh [--root <records root>] <project>\nrc=2')"
check "refuse: a project that is a path" "$("$G" --root "$ROOT" ../records/atlas 2>&1; echo "rc=$?")" "$(printf 'precedents-gather: a project is one folder name, not ../records/atlas\nrc=2')"
check "refuse: sources is not a project" "$("$G" --root "$A" sources >/dev/null 2>&1; echo "rc=$?")" "rc=2"

# ---- precedents-check.sh <record dir>: the record's precedents.json (the haiku agent's reply, saved by the lead),
# against the schema and the gatherer's output, which the check runs itself (atlas: 11 rows over atl-40-r1,
# atl-41-r1, atl-43-r1; atl-41-r1 LEARNED row 2 has the same text as atl-40-r1 LEARNED row 1). Each case copies one
# fixture into a record folder and checks that folder.
C="$HERE/records/precedents-check.sh"
SCHEMA="$HERE/skills/sweeping-precedents/templates/sweep.schema.json"
J="$T/json"; mkdir -p "$J"
F="$A/atl-44-r1"; NB="$ROOT/beacon/bcn-1-r1"; mkdir -p "$F" "$NB"
cat > "$J/good.json" <<'EOF'
{
  "project": "atlas",
  "rows_read": 11,
  "records": ["atl-40-r1", "atl-41-r1", "atl-43-r1"],
  "rows": [
    {"id": "P1", "rule": "A wait inside the nightly job reschedules it; it never sleeps on the shared scheduler thread.",
     "sources": ["atl-40-r1 · LEARNED · row 1", "atl-41-r1 · LEARNED · row 2", "atl-40-r1 · CHANGED · row 2"],
     "fits": "constraint", "why": "the new retry runs inside the same nightly job", "status": "live"},
    {"id": "P2", "rule": "An alert names the file it is about.", "sources": ["atl-41-r1 · CHANGED · row 1"],
     "fits": "gate pass line", "why": "the new rung adds an alert", "status": "live"},
    {"id": "P3", "rule": "The vendor's partial-file format is unconfirmed and out of scope.",
     "sources": ["atl-40-r1 · OWED · row 1", "atl-43-r1 · CHANGED · row 1"],
     "owner_quote": "the owner ruled the vendor format out of scope",
     "fits": "open", "why": "the parser waits on the vendor", "status": "stale-after the vendor's format reply"}
  ],
  "not_carried": [
    {"reference": "atl-40-r1 · CHANGED · row 1", "reason": "the retry wrapper is built; nothing for this rung"},
    {"reference": "atl-40-r1 · LEARNED · row 2", "reason": "a lesson about the alert path, not this rung"},
    {"reference": "atl-41-r1 · LEARNED · row 1", "reason": "went well; nothing to change"},
    {"reference": "atl-41-r1 · OWED · row 1", "reason": "the ops dashboard tile is not in this rung"},
    {"reference": "atl-41-r1 · OWED · row 2", "reason": "paging ops is the owner's call, not this rung"}
  ]
}
EOF
jx(){ jq "$1" "$J/good.json" > "$J/$2.json"; }   # a fixture: good.json with one change
# sw: check fixture $1 in the atlas record folder (or $2); 2>/dev/null on the echo: a head -1 after it closes the pipe
sw(){ local d="${2:-$F}"; cp "$J/$1.json" "$d/precedents.json"; "$C" "$d" 2>&1; echo "rc=$?" 2>/dev/null; }
check "check: the good precedents.json passes, exit 0" "$(sw good | tail -1)" "rc=0"
check "check: the pass line names the counts" "$(sw good | head -1)" "precedents-check: pass · atlas · 11 rows read · 3 carried, 5 not carried"
check "check: another spelling of the record folder" "$(cp "$J/good.json" "$F/precedents.json"; "$C" "$A/./atl-44-r1/" >/dev/null 2>&1; echo "rc=$?")" "rc=0"
check "check: the schema file is JSON, draft 2020-12" "$(jq -r '."$schema"' "$SCHEMA")" "https://json-schema.org/draft/2020-12/schema"
# shape faults, from the schema: one line each, naming the field
jx '.rows[0].fits="maybe"' fits;              check "shape: fits outside the enum" "$(sw fits)" "$(printf '%s\n%s' "rows[0].fits: \"maybe\" is not one of constraint, gate pass line, one-way, open" rc=1)"
jx 'del(.rows[1].why)' nowhy;                 check "shape: a row missing a field" "$(sw nowhy)" "$(printf '%s\n%s' "rows[1]: missing why" rc=1)"
jx '.rows[0].colour="red"' extra;             check "shape: a field the schema does not name" "$(sw extra)" "$(printf '%s\n%s' "rows[0].colour: not allowed" rc=1)"
jx '.rows[0].brief="constraints 4"' brief;    check "shape: a brief field is not part of the shape" "$(sw brief)" "$(printf '%s\n%s' "rows[0].brief: not allowed" rc=1)"
jx '.rows[2].status="maybe live"' status;     check "shape: a status that is not live or stale-after" "$(sw status | grep -c '^rows\[2\].status: does not match ')" 1
jx '.rows[1].status="superseded by atl-43-r1 · CHANGED · row 1"' sup; check "shape: a superseded row is not a P row" "$(sw sup | grep -c '^rows\[1\].status: does not match ')" 1
jx '.rows[1].rule="An alert names the file.\nIt fires once."' twolines; check "shape: a rule on two lines" "$(sw twolines | grep -c '^rows\[1\].rule: does not match ')" 1
jx '.rows[1].sources=["atl-41-r1 close.md CHANGED row 1"]' respelt; check "shape: a reference not copied as printed" "$(sw respelt | grep -c '^rows\[1\].sources\[0\]: does not match ')" 1
jx '.rows[1].sources=[]' nosrc;               check "shape: a row with no source" "$(sw nosrc | head -1)" "rows[1].sources: fewer than 1 items"
jx '.rows_read="11"' rrstr;                   check "shape: rows_read a string" "$(sw rrstr | head -1)" "rows_read: \"11\" is not of type integer"
jx '.not_carried[0]={"reference":"atl-40-r1 · CHANGED · row 1"}' noreason; check "shape: a not_carried entry with no reason" "$(sw noreason | head -1)" "not_carried[0]: missing reason"
printf '{"project": "atlas",' > "$J/broken.json"; check "shape: not JSON, exit 1 naming the file" "$(sw broken | head -1 | cut -d: -f1-2)" "$F/precedents.json: not JSON (line 1 column 21"
printf '```json\n{}\n```\n' > "$J/fenced.json"; check "shape: a reply saved with its markdown fence is not JSON" "$(sw fenced | tail -1)" "rc=1"
check "shape: a shape fault stops the cross-checks (one line)" "$(sw fits | grep -c .)" 2
# cross-checks against the gatherer's output: one line each, naming the reference or the field
jx 'del(.not_carried[4])' miss;               check "cross: a printed row left out" "$(sw miss)" "$(printf '%s\n%s' "atl-41-r1 · OWED · row 2: the gatherer printed it; it is in no P row's sources and not in not_carried" rc=1)"
jx '.not_carried+=[{"reference":"atl-40-r1 · OWED · row 1","reason":"x"}]' twice; check "cross: a row in two places" "$(sw twice | head -1)" "atl-40-r1 · OWED · row 1: placed 2 times (P3, not_carried); every row goes in exactly one place"
jx '.not_carried+=[{"reference":"atl-41-r1 · OWED · row 3","reason":"x"}]' unknown; check "cross: a reference the gatherer did not print" "$(sw unknown | head -1)" "atl-41-r1 · OWED · row 3: the gatherer did not print it"
jx '.rows[1].sources+=["atl-42-r1 · LEARNED · row 1"]' unknown2; check "cross: an unknown reference in a P row's sources" "$(sw unknown2 | head -1)" "atl-42-r1 · LEARNED · row 1: the gatherer did not print it"
jx '.rows_read=10' rr;                        check "cross: rows_read is the gatherer's count" "$(sw rr)" "$(printf '%s\n%s' "rows_read: 10, the gatherer printed 11 rows" rc=1)"
jx '.records=["atl-40-r1","atl-41-r1"]' recs; check "cross: records are the gatherer's" "$(sw recs | head -1)" "records: atl-40-r1, atl-41-r1; the gatherer printed atl-40-r1, atl-41-r1, atl-43-r1"
jx '.project="beacon"' proj;                  check "cross: project is the gatherer's" "$(sw proj | head -1)" "project: beacon; the gatherer printed atlas"
jx '.rows[0].sources-=["atl-41-r1 · LEARNED · row 2"] | .not_carried+=[{"reference":"atl-41-r1 · LEARNED · row 2","reason":"x"}]' split
check "cross: a same-text row split from its first" "$(sw split)" "$(printf '%s\n%s' "atl-41-r1 · LEARNED · row 2: same text as atl-40-r1 · LEARNED · row 1, so it goes where that row goes (P1); it is in not_carried" rc=1)"
jx '.rows[0].sources-=["atl-41-r1 · LEARNED · row 2"] | .rows[1].sources+=["atl-41-r1 · LEARNED · row 2"]' split2
check "cross: a same-text row in another P row" "$(sw split2 | head -1)" "atl-41-r1 · LEARNED · row 2: same text as atl-40-r1 · LEARNED · row 1, so it goes where that row goes (P1); it is in P2"
jx '.rows[0].sources-=["atl-40-r1 · LEARNED · row 1","atl-41-r1 · LEARNED · row 2"] | .not_carried+=[{"reference":"atl-40-r1 · LEARNED · row 1","reason":"x"},{"reference":"atl-41-r1 · LEARNED · row 2","reason":"x"}]' bothout
check "cross: a same-text pair both not carried passes" "$(sw bothout | tail -1)" "rc=0"
jx '.rows[1].id="P3" | .rows[2].id="P2"' ids; check "cross: P ids run P1..Pn in order" "$(sw ids | head -1)" "rows[1].id: P3, expected P2"
jx '.rows[2].owner_quote="the owner ruled it out"' quote; check "cross: an owner quote not verbatim in its sources" "$(sw quote)" "$(printf '%s\n%s' "rows[2].owner_quote: not verbatim in the text of P3's sources" rc=1)"
jx 'del(.rows[1]) | .rows[1].id="P2" | .not_carried+=[{"reference":"atl-41-r1 · CHANGED · row 1","reason":"the lead disagrees: no alert in this rung"}]' moved
check "cross: a row the lead moves to not_carried, P ids renumbered, passes" "$(sw moved | head -1)" "precedents-check: pass · atlas · 11 rows read · 2 carried, 6 not carried"
jx 'del(.not_carried[4]) | .rows_read=12' many; check "cross: every fault, one line each" "$(sw many | grep -c .)" 3
# the none form
printf '{"none": "no close report for beacon"}\n' > "$J/none.json"
check "none: valid when the gatherer printed none" "$(sw none "$NB")" "$(printf '%s\n%s' "precedents-check: pass · none: no close report for beacon" rc=0)"
check "none: refused when the gatherer printed rows" "$(sw none)" "$(printf '%s\n%s' "none: the gatherer printed 11 rows; the none form is only for none: no close report for atlas" rc=1)"
check "none: the rows form refused when the gatherer printed none" "$(sw good "$NB" | head -1)" "the gatherer printed none: no close report for beacon; write {\"none\": \"<reason>\"}"
printf '{"none": "  "}\n' > "$J/none-blank.json"; check "none: a blank reason" "$(sw none-blank "$NB" | head -1)" 'none: does not match ^[^\n]*\S[^\n]*$'
printf '{"none": "x", "rows": []}\n' > "$J/none-extra.json"; check "none: with rows beside it" "$(sw none-extra "$NB" | head -1)" "rows: not allowed"
# usage, exit 2; a missing precedents.json is a fault, exit 1
U="usage: precedents-check.sh [--schema <schema>] <record dir>"
check "usage: no arguments, exit 2" "$("$C" 2>&1; echo "rc=$?")" "$(printf '%s\n%s' "$U" rc=2)"
check "usage: two record folders, exit 2" "$("$C" "$F" "$NB" >/dev/null 2>&1; echo "rc=$?")" "rc=2"
for f in --sweep --final --shape --input; do check "usage: $f is gone, exit 2" "$("$C" $f "$F" >/dev/null 2>&1; echo "rc=$?")" "rc=2"; done
check "usage: a record folder that is not there, exit 2" "$("$C" "$A/atl-99-r1" 2>&1; echo "rc=$?")" "$(printf '%s\n%s' "precedents-check: no record folder $A/atl-99-r1" rc=2)"
rm -f "$F/precedents.json"; check "check: no precedents.json, exit 1" "$("$C" "$F" 2>&1; echo "rc=$?")" "$(printf '%s\n%s' "$F/precedents.json: missing" rc=1)"
# the schema is the statement of shape: the check reads it, and refuses a keyword it does not read
jq '.["$defs"].row.properties.fits.enum+=["maybe"]' "$SCHEMA" > "$T/schema-maybe.json"
check "schema: the check reads the schema (an enum widened in a copy lets fits maybe through)" "$(cp "$J/fits.json" "$F/precedents.json"; "$C" --schema "$T/schema-maybe.json" "$F" >/dev/null; echo "rc=$?")" "rc=0"
jq '.["$defs"].row.maxProperties=9' "$SCHEMA" > "$T/schema-kw.json"
check "schema: a keyword the check does not read, exit 2" "$("$C" --schema "$T/schema-kw.json" "$F" 2>&1; echo "rc=$?")" "$(printf '%s\n%s' "precedents-check: the schema uses maxProperties, which precedents_check.py does not read" rc=2)"
# the skill's templates: the example has the schema's shape; the prompt takes the pasted output and names the schema
TPL="$HERE/skills/sweeping-precedents/templates"
shape_only(){ python3 -I -c 'import json, sys
sys.path.insert(0, sys.argv[1]); import precedents_check as c
s = c.load_schema(c.SCHEMA); f = c.shape(s, json.load(open(sys.argv[2], encoding="utf-8")), "", s)
print("\n".join(f) or "shape ok")' "$HERE/records" "$1"; }
check "template: precedents.example.json has the schema's shape" "$(shape_only "$TPL/precedents.example.json")" "shape ok"
check "template: the example carries no brief field" "$(jq '[.rows[] | select(has("brief"))] | length' "$TPL/precedents.example.json")" 0
check "template: the sweep prompt names the schema file" "$(grep -c '/shared/skills/sweeping-precedents/templates/sweep.schema.json$' "$TPL/sweep-prompt.md")" 1
check "template: the sweep prompt has a slot for the pasted gatherer output" "$(grep -c '^<paste the output of shared/records/precedents-gather.sh <project> here>$' "$TPL/sweep-prompt.md")" 1
check "template: the sweep prompt asks for no file" "$(grep -c -i -e 'write your result to' -e 'output path' -e 'input file' "$TPL/sweep-prompt.md")" 0
check "template: no precedents.md template left" "$([ -e "$TPL/precedents.md" ] && echo there || echo gone)" gone
# the two agree: each fixture's verdict in a record folder matches a reference JSON Schema validator (jsonschema, from
# uv's offline cache) on the fixtures whose cross-checks pass whenever the shape holds. Skipped, not counted, without it.
oracle(){ uv run --offline --no-project --with jsonschema python -c 'import json, sys, jsonschema
s = json.load(open(sys.argv[1]))
try:
    d = json.load(open(sys.argv[2]))
except ValueError:
    print("invalid"); sys.exit()
print("valid" if jsonschema.Draft202012Validator(s).is_valid(d) else "invalid")' "$SCHEMA" "$1" 2>/dev/null; }
if command -v uv >/dev/null 2>&1 && [ "$(oracle "$J/good.json")" = valid ]; then
  for f in good bothout moved none none-blank none-extra fits nowhy extra brief status sup twolines respelt nosrc rrstr noreason broken fenced; do
    case "$f" in none*) d="$NB" ;; *) d="$F" ;; esac
    want="$(oracle "$J/$f.json")"
    mine="$(sw "$f" "$d" | tail -1 | sed 's/^rc=0$/valid/; s/^rc=1$/invalid/')"
    check "agree: $f.json is $want to jsonschema and to the check" "$mine" "$want"
  done
  check "agree: the example is $(oracle "$TPL/precedents.example.json") to jsonschema too" "$(oracle "$TPL/precedents.example.json")" valid
else
  echo "skip  agree: no jsonschema in uv's offline cache"
fi

echo "$pass pass, $fail fail"
[ "$fail" -eq 0 ]
