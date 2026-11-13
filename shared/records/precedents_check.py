"""The precedents check: a record's precedents.json against the schema and the gatherer's output.

    shared/records/precedents-check.sh [--schema <schema>] <record dir>

<record dir> is <root>/<project>/<record>; the check reads <record dir>/precedents.json (the haiku agent's reply,
saved by the lead, or the lead's pick after it), takes the project and the root from the path, and runs the
gatherer (shared/records/precedents_gather.py) itself.

The shape is the schema's: shared/skills/sweeping-precedents/templates/sweep.schema.json (or --schema) is read
here as the single statement of it, by a small reader of the JSON Schema keywords that file uses (no jsonschema
dependency). A schema keyword this reader does not know is refused (exit 2), so the file cannot say more than
the check enforces. shared/tests/test-precedents.sh compares the verdicts with jsonschema on its fixtures.

Then, when the shape holds, against the gatherer's output:
- every reference the gatherer printed is placed exactly once, in one P row's sources or in not_carried;
- no reference the gatherer did not print;
- project, rows_read and records are the gatherer's;
- a row the gatherer marks "(same text as X)" is placed where X is (the same P row, or not_carried);
- P ids run P1..Pn in order; an owner_quote is verbatim in the text of its row's sources;
- the none form {"none": "<reason>"} only when the gatherer printed "none: no close report for <project>",
  and the rows form only when it did not.

Exit 0 with one pass line; exit 1 with one line per fault, naming the reference or the field (a missing or
unparsable precedents.json is one such line); exit 2 with a plain reason on stderr for usage, a record folder
that is not there, the gatherer refusing, or a schema keyword not read.

What it does not prove: that a rule says what its sources say, that fits or status is right, that a row left in
not_carried should not bind the rung, or that the brief carries the kept rows.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "..", "skills", "sweeping-precedents", "templates", "sweep.schema.json")
GATHER = os.path.join(HERE, "precedents_gather.py")
USAGE = "usage: precedents-check.sh [--schema <schema>] <record dir>"
KEYWORDS = {"$schema", "$id", "$comment", "title", "description", "$defs", "$ref", "oneOf", "type", "enum", "const",
            "pattern", "minLength", "maxLength", "minimum", "minItems", "uniqueItems", "items", "required",
            "properties", "additionalProperties"}
ROW = re.compile(r"^  (\S+ · (?:CHANGED|LEARNED|OWED) · row [0-9]+)   (.*)$")
SAME = re.compile(r"^(.*)   \(same text as (.+)\)$")
NONE = re.compile(r"^none: no close report for (.+)$")


def die(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(2)


# ---- the schema, read as the statement of shape

def load_schema(path):
    try:
        with open(path, encoding="utf-8") as f:
            schema = json.load(f)
    except (OSError, ValueError) as e:
        die(f"precedents-check: cannot read the schema {path}: {e}")

    def walk(node):
        if not isinstance(node, dict):
            return
        for k, v in node.items():
            if k not in KEYWORDS:
                die(f"precedents-check: the schema uses {k}, which precedents_check.py does not read")
            if k in ("$defs", "properties"):
                for sub in v.values():
                    walk(sub)
            elif k == "oneOf":
                for sub in v:
                    walk(sub)
            elif k in ("items", "additionalProperties"):
                walk(v)
    walk(schema)
    return schema


def resolve(root, ref):
    if not ref.startswith("#/"):
        die(f"precedents-check: the schema's $ref {ref} is not local")
    node = root
    for part in ref[2:].split("/"):
        node = node[part]
    return node


def is_type(v, t):
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool)
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    return isinstance(v, {"string": str, "array": list, "object": dict, "null": type(None), "boolean": bool}[t])


def ecma(pattern):
    # an ECMA pattern's $ (no m flag) is the end of the input, which in Python is \Z ($ also matches before a final \n)
    return re.compile(re.sub(r"(?<!\\)\$$", r"\\Z", pattern))


def show(v):
    return json.dumps(v, ensure_ascii=False)


def child(path, key):
    return f"{path}.{key}" if path else str(key)


def type_fits(s, v, root):
    while "$ref" in s and "type" not in s:
        s = resolve(root, s["$ref"])
    t = s.get("type")
    return t is None or any(is_type(v, x) for x in (t if isinstance(t, list) else [t]))


def shape(s, v, path, root):
    """The fault lines of value v against schema node s."""
    out = []
    if "$ref" in s:
        out += shape(resolve(root, s["$ref"]), v, path, root)
    if "oneOf" in s:
        res = [shape(b, v, path, root) for b in s["oneOf"]]
        passed = sum(1 for r in res if not r)
        if passed == 0:   # the branch nearest the value: its type fits, then the fewest faults
            best = min(range(len(res)), key=lambda i: (not type_fits(s["oneOf"][i], v, root), len(res[i])))
            out += res[best]
        elif passed > 1:
            out.append(f"{path or '(root)'}: matches more than one form")
    if "type" in s:
        ts = s["type"] if isinstance(s["type"], list) else [s["type"]]
        if not any(is_type(v, t) for t in ts):
            return out + [f"{path or '(root)'}: {show(v)} is not of type {' or '.join(ts)}"]
    if "enum" in s and v not in s["enum"]:
        out.append(f"{path}: {show(v)} is not one of {', '.join(str(e) for e in s['enum'])}")
    if "const" in s and v != s["const"]:
        out.append(f"{path}: {show(v)} is not {show(s['const'])}")
    if isinstance(v, str):
        if "pattern" in s and not ecma(s["pattern"]).search(v):
            out.append(f"{path}: does not match {s['pattern']}")
        if "minLength" in s and len(v) < s["minLength"]:
            out.append(f"{path}: shorter than {s['minLength']} characters")
        if "maxLength" in s and len(v) > s["maxLength"]:
            out.append(f"{path}: longer than {s['maxLength']} characters")
    if is_type(v, "number") and "minimum" in s and v < s["minimum"]:
        out.append(f"{path}: {v} is less than {s['minimum']}")
    if isinstance(v, list):
        if "minItems" in s and len(v) < s["minItems"]:
            out.append(f"{path}: fewer than {s['minItems']} items")
        if s.get("uniqueItems") and len({show(x) for x in v}) < len(v):
            out.append(f"{path}: has duplicate items")
        if "items" in s:
            for i, x in enumerate(v):
                out += shape(s["items"], x, f"{path}[{i}]", root)
    if isinstance(v, dict):
        props = s.get("properties", {})
        for r in s.get("required", []):
            if r not in v:
                out.append(f"{path or '(root)'}: missing {r}")
        for k, x in v.items():
            if k in props:
                out += shape(props[k], x, child(path, k), root)
            elif s.get("additionalProperties") is False:
                out.append(f"{child(path, k)}: not allowed")
            elif isinstance(s.get("additionalProperties"), dict):
                out += shape(s["additionalProperties"], x, child(path, k), root)
    return out


# ---- the gatherer's output

def read_gather(text, where):
    lines = text.replace("\r\n", "\n").split("\n")
    m = NONE.match(lines[0]) if lines else None
    g = {"none": bool(m), "project": m.group(1) if m else "", "records": [], "rows": {}, "order": [], "same": {}}
    if m:
        return g
    if not lines[0].startswith("precedents · "):
        die(f"precedents-check: {where} is not the gatherer's output (no precedents · header, no none: line)")
    g["project"] = lines[0].split(" · ")[1]
    for line in lines[1:]:
        if line.startswith("== "):
            g["records"].append(line[3:].split(" · ")[0])
            continue
        r = ROW.match(line)
        if r:
            ref, text = r.group(1), r.group(2)
            s = SAME.match(text)
            if s:
                text, g["same"][ref] = s.group(1), s.group(2)
            g["rows"][ref] = text
            g["order"].append(ref)
    return g


def squash(s):
    return re.sub(r"\s+", " ", s).strip().lower()


def cross(d, g):
    """The fault lines of a document whose shape holds, against the gatherer's output g."""
    if g["none"]:
        if "none" in d:
            return []
        return [f'the gatherer printed none: no close report for {g["project"]}; write {{"none": "<reason>"}}']
    if "none" in d:
        return [f'none: the gatherer printed {len(g["order"])} rows; the none form is only for '
                f'none: no close report for {g["project"]}']
    out = []
    if d["project"] != g["project"]:
        out.append(f'project: {d["project"]}; the gatherer printed {g["project"]}')
    if d["rows_read"] != len(g["order"]):
        out.append(f'rows_read: {d["rows_read"]}, the gatherer printed {len(g["order"])} rows')
    if d["records"] != g["records"]:
        out.append(f'records: {", ".join(d["records"])}; the gatherer printed {", ".join(g["records"])}')
    for i, r in enumerate(d["rows"]):
        if r["id"] != f"P{i + 1}":
            out.append(f'rows[{i}].id: {r["id"]}, expected P{i + 1}')
    places = {}
    for r in d["rows"]:
        for ref in r["sources"]:
            places.setdefault(ref, []).append(r["id"])
    for n in d["not_carried"]:
        places.setdefault(n["reference"], []).append("not_carried")
    for ref in places:
        if ref not in g["rows"]:
            out.append(f"{ref}: the gatherer did not print it")
    for ref in g["order"]:
        p = places.get(ref, [])
        if not p:
            out.append(f"{ref}: the gatherer printed it; it is in no P row's sources and not in not_carried")
        elif len(p) > 1:
            out.append(f"{ref}: placed {len(p)} times ({', '.join(p)}); every row goes in exactly one place")
    for dup, first in g["same"].items():
        a, b = places.get(dup, []), places.get(first, [])
        if len(a) == 1 and len(b) == 1 and a != b:
            out.append(f"{dup}: same text as {first}, so it goes where that row goes ({b[0]}); it is in {a[0]}")
    for i, r in enumerate(d["rows"]):
        q = r.get("owner_quote")
        if q is not None and not any(squash(q) in squash(g["rows"].get(s, "")) for s in r["sources"]):
            out.append(f'rows[{i}].owner_quote: not verbatim in the text of {r["id"]}\'s sources')
    return out


def load_doc(path):
    """(document, faults)"""
    if not os.path.isfile(path):
        return None, [f"{path}: missing"]
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f), []
    except UnicodeDecodeError:
        return None, [f"{path}: not UTF-8 text"]
    except json.JSONDecodeError as e:
        return None, [f"{path}: not JSON (line {e.lineno} column {e.colno}: {e.msg})"]
    except OSError as e:
        return None, [f"{path}: unreadable ({e.strerror})"]


def gather(rec):
    root, project = os.path.dirname(os.path.dirname(rec)), os.path.basename(os.path.dirname(rec))
    p = subprocess.run([sys.executable, "-I", GATHER, "--root", root, project], capture_output=True, text=True)
    if p.returncode != 0:
        die(f"precedents-check: the gatherer refused: {p.stderr.strip()}")
    return p.stdout


def main(argv):
    args, schema = list(argv), SCHEMA
    if args[:1] == ["--schema"]:
        if len(args) < 2:
            die(USAGE)
        schema, args = args[1], args[2:]
    if len(args) != 1 or not args[0] or args[0].startswith("-"):
        die(USAGE)
    root = load_schema(schema)
    rec = os.path.normpath(os.path.abspath(args[0]))
    if not os.path.isdir(rec):
        die(f"precedents-check: no record folder {rec}")
    g = read_gather(gather(rec), f"the gatherer's output for {rec}")
    d, faults = load_doc(os.path.join(rec, "precedents.json"))
    if not faults:
        faults = shape(root, d, "", root)
    if not faults:
        faults = cross(d, g)
    if faults:
        print("\n".join(faults))
        return 1
    if "none" in d:
        print(f"precedents-check: pass · none: {d['none']}")
    else:
        print(f"precedents-check: pass · {d['project']} · {d['rows_read']} rows read · "
              f"{len(d['rows'])} carried, {len(d['not_carried'])} not carried")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
