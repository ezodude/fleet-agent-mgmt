#!/usr/bin/env python3
"""Write test/fixtures.gen.ts from test/fixtures/invented/: the fake file tree the tests serve.

Every fixture is invented: invented ICs, projects, tickets and text, in the
shapes the mod reads. Nothing here reads a live folder (no ~/.claude, no
~/.fleet-agent-mgmt): every input is a file under test/fixtures/invented/,
and every mtime the mod sees comes from a json file there, never from disk.
Run again after a fixture changes:
    python3 test/make-fixtures.py

What it writes:
  FILES       the board's tree: session files, each IC's checks folder (STATE.md
              and the names beside it, from newest.json), the record folders
              (names and mtimes only, from records.json), lead-1's workflows
  CARD_FILES  lead-1's decision card files (cards/*.md), served by the card tests
              on top of FILES at <home>/.fleet-agent-mgmt/checks/lead-1/cards/
  EXPECTED    the IC rows of expected.json
  BASELINE    the render snapshots in baseline/*.txt, by file name without .txt
"""
import json
import os
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, 'fixtures', 'invented')
HOME = '/Users/owner'
NOW = '2026-10-21T16:55:00+01:00'  # just after the newest fixture file


def ms(iso):
    return int(datetime.fromisoformat(iso.replace('Z', '+00:00')).timestamp() * 1000)


def text(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def load(name):
    with open(os.path.join(FIX, name), encoding='utf-8') as f:
        return json.load(f)


mtimes = load('mtimes.json')
newest = load('newest.json')['dirs']
expected = load('expected.json')
files = {}

for name in sorted(os.listdir(os.path.join(FIX, 'sessions'))):
    files[f'{HOME}/.claude/sessions/{name}'] = {
        'text': text(os.path.join(FIX, 'sessions', name)),
        'mtimeMs': ms(mtimes[f'sessions/{name}']),
    }

checks = f'{HOME}/.fleet-agent-mgmt/checks'
for name, d in newest.items():
    files[f'{checks}/{name}/STATE.md'] = {
        'text': text(os.path.join(FIX, 'states', f'{name}.STATE.md')),
        'mtimeMs': ms(d['state_mtime']),
    }
    for other in d['others']:
        files[f'{checks}/{name}/{other["name"]}'] = {'text': '', 'mtimeMs': ms(other['mtime'])}

# Record folders: names and mtimes only, never contents.
RECORDS = f'{HOME}/.fleet-agent-mgmt/records'
for rel, listed in load('records.json')['folders'].items():
    if not listed:
        files[f'{RECORDS}/{rel}/'] = {'text': '', 'mtimeMs': 0}  # a folder with nothing in it: listed, empty
    for name, mtime in listed.items():
        files[f'{RECORDS}/{rel}/{name}'] = {'text': '', 'mtimeMs': ms(mtime)}

lead = expected['lead_1']
slug = ''.join(c if c.isalnum() else '-' for c in lead['cwd'])
base = f"{HOME}/.claude/projects/{slug}/{lead['sessionId']}"
wf_root = os.path.join(FIX, 'workflows', lead['sessionId'])
for root, _, names in os.walk(wf_root):
    for name in sorted(names):
        p = os.path.join(root, name)
        rel = os.path.relpath(p, wf_root)
        if rel.startswith('workflows/wf_') and rel.endswith('.json'):
            mtime = ms(json.loads(text(p))['timestamp'])  # a run record is written when the run ends
        else:
            mtime = ms(mtimes[f'workflows/{lead["sessionId"]}/{rel}'])
        files[f'{base}/{rel}'] = {'text': text(p), 'mtimeMs': mtime}

cards = {}
cards_dir = os.path.join(FIX, 'cards')
for name in sorted(os.listdir(cards_dir)) if os.path.isdir(cards_dir) else []:
    cards[f'{checks}/lead-1/cards/{name}'] = {'text': text(os.path.join(cards_dir, name)), 'mtimeMs': ms(mtimes[f'cards/{name}'])}

baseline = {}
base_dir = os.path.join(FIX, 'baseline')
for name in sorted(os.listdir(base_dir)) if os.path.isdir(base_dir) else []:
    if name.endswith('.txt'):
        baseline[name[:-4]] = text(os.path.join(base_dir, name))

out = [
    '// Written by test/make-fixtures.py from test/fixtures/invented/. Do not edit by hand.',
    f'export const HOME = {json.dumps(HOME)}',
    f'export const NOW = Date.parse({json.dumps(NOW)})',
    'export const FILES: Record<string, { text: string; mtimeMs: number }> = ' + json.dumps(files, indent=1, ensure_ascii=False),
    'export const CARD_FILES: Record<string, { text: string; mtimeMs: number }> = ' + json.dumps(cards, indent=1, ensure_ascii=False),
    'export const EXPECTED = ' + json.dumps(expected['ic_rows'], indent=1, ensure_ascii=False),
    'export const BASELINE: Record<string, string> = ' + json.dumps(baseline, indent=1, ensure_ascii=False),
    '',
]
with open(os.path.join(HERE, 'fixtures.gen.ts'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
print(f'{len(files)} files, {len(cards)} card files, {len(expected["ic_rows"])} expected rows, {len(baseline)} baseline snapshots')
