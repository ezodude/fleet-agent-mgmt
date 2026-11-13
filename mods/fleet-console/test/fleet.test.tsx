import { expect, mock, test } from 'claude-code/testing'

import {
  LETTERS,
  breakLong,
  breakPath,
  cardParts,
  cardsOf,
  clauses,
  doneGlyph,
  doneLine,
  doneOf,
  header,
  headerParts,
  icRow,
  optionParts,
  parseCard,
  parseState,
  recordFolderOf,
  sinceShort,
  splitPath,
  ymdhm,
} from '../hooks/parse'
import * as parse from '../hooks/parse'
import { register } from '../hooks/register'
import type { Row } from '../types'
import { BASELINE, CARD_FILES, EXPECTED, FILES, HOME, NOW } from './fixtures.gen'
import { WIDTHS, snapshot } from './layout'

// `kind` stands in for a link ('other'); `fail` makes the read refused, as for a file over the read limit.
// A key ending in "/" is a folder with nothing in it: it lists as empty, not as missing.
type Files = Record<string, { text: string; mtimeMs: number; kind?: string; fail?: boolean }>
type Trace = { reads: string[]; runs: string[][]; lists: string[]; opens: Record<string, unknown>[] }

const MOUNT = {
  plugin: 'fleet-console',
  component: 'Pane',
  requestId: 'fleet',
  props: {
    title: 'fleet · read-only',
    isFocused: true,
    bodyColumns: 120,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 60 },
    view: {},
  },
} as const

/** An IC's expected row, by name; its letter comes from the names in order, so a test names the IC, not the letter. */
const want = (name: string) => EXPECTED.find(w => w.name === name)!
const L = (name: string) => want(name).letter

/** The card's done line for a fixture record folder closed at `iso` (the time shown is local, as the pane draws it). */
const closedLine = (folder: string, iso: string) => `✔ DONE · ${folder} closed ${ymdhm(Date.parse(iso))} · close report in the record`
const DONE_42 = closedLine('atl-42-r1', '2026-10-22T10:36:03+01:00')
const DONE_43 = closedLine('atl-43-r1', '2026-10-22T10:58:07+01:00')

/** Serves `files` as the disk, records every read and every process, then opens /fleet. */
async function openFleet(
  $: any,
  on: any,
  files: Files,
  surface: 'terminal' | 'desktop' = 'terminal',
  bodyColumns = 120,
  isFocused = true,
) {
  const trace: Trace = { reads: [], runs: [], lists: [], opens: [] }
  // `world.isEnvDown` makes $.env.get refused, so a whole refresh fails (as a read that throws would).
  const world = { isEnvDown: false }
  on('env.get', (_: unknown, e: { name: string }) =>
    world.isEnvDown ? { deny: 'env unavailable' } : { value: e.name === 'HOME' ? HOME : undefined },
  )
  const clock = mock.clock(on, { now: NOW })
  on('fs.list', (_: unknown, e: { path: string }) => {
    const dir = e.path.replace(/\/$/, '')
    trace.lists.push(dir)
    const seen = new Map<string, object>()
    let isThere = false
    for (const [path, f] of Object.entries(files)) {
      if (!path.startsWith(`${dir}/`)) continue
      isThere = true
      const [name = '', ...deeper] = path.slice(dir.length + 1).split('/')
      if (!name) continue // the key "<dir>/" itself: the folder is there, with nothing in it
      seen.set(
        name,
        deeper.length
          ? { name, kind: 'dir', size: 0, mtimeMs: 0, isLink: false }
          : f.kind
            ? { name, kind: f.kind, size: 0, mtimeMs: 0, isLink: true }
            : { name, kind: 'file', size: f.text.length, mtimeMs: f.mtimeMs, isLink: false },
      )
    }
    return isThere ? { value: [...seen.values()] } : { deny: 'ENOENT' }
  })
  on('fs.read', (_: unknown, e: { path: string }) => {
    trace.reads.push(e.path)
    const f = files[e.path]
    if (f?.fail) return { deny: 'EFBIG: over the read limit' }
    return f ? { value: f.text } : { deny: 'ENOENT' }
  })
  on('process.run', (_: unknown, e: { argv: string[] }) => {
    trace.runs.push([...e.argv])
    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'fleet' } }))
  on('ui.open', (_: unknown, e: Record<string, unknown>) => {
    trace.opens.push({ ...e })
    return { value: { isPlaced: true } }
  })

  await $.session.start({ cwd: '/w', surface, isInteractive: true })
  await $.command.run({ command: 'fleet', args: '' })
  const ui = await $.ui.mount({ ...MOUNT, surface, props: { ...MOUNT.props, bodyColumns, isFocused } })
  return { ui, trace, clock, world }
}

const texts = async (ui: any): Promise<string[]> => (await ui.findAll({ type: 'Text' })).map((t: any) => t.text)

/** A node's text: its strings and its nested Texts', in order. */
const flat = (n: any): string =>
  typeof n === 'string' ? n : n?.type === 'Text' && typeof n.text === 'string' ? n.text : (n?.children ?? []).map(flat).join('')

/** The Texts under the Box with this key, in drawing order, each as shown (a line break the card added stays in). */
async function boxTexts(ui: any, key: string): Promise<string[]> {
  const out: string[] = []
  const walk = (n: any) => {
    if (!n || typeof n !== 'object') return
    if (n.type === 'Text') {
      out.push(n.text ?? flat(n))
      return
    }
    for (const c of n.children ?? []) walk(c)
  }
  walk(await ui.find({ key }))
  return out
}

const cardTexts = (ui: any) => boxTexts(ui, 'card')
const legend = async (ui: any) => (await boxTexts(ui, 'keys')).join('')
/** A row's whole line, as its Button's label. */
const rowLabel = async (ui: any, letter: string): Promise<string | undefined> => (await ui.find({ key: letter }))?.props.label

/** The card as label -> its clause rows, the title and updated rows under ''. */
function cardFields(lines: string[]): Record<string, string[]> {
  const out: Record<string, string[]> = { '': [] }
  let at = ''
  for (const l of lines) {
    if (['stop', 'next', 'newest file', 'awaiting'].includes(l)) out[(at = l)] = []
    else if (l !== '·') out[at]!.push(l)
  }
  return out
}

test('K4 parse: each STATE.md snapshot gives the expected rung, status, needs you and card', async () => {
  for (const want of EXPECTED) {
    const session = JSON.parse(FILES[`${HOME}/.claude/sessions/${want.session_file.split('/')[1]}`]!.text)
    const row = icRow(want.letter, {
      name: want.name,
      status: session.status,
      tmux: session.tmux,
      state: FILES[`${HOME}/.fleet-agent-mgmt/checks/${want.name}/STATE.md`]!.text,
      newestFile: want.card.newest_file,
    })
    expect(row).toMatchObject({
      letter: want.letter,
      name: want.name,
      pane: want.pane,
      status: want.status,
      rung: want.rung,
      needsYou: want.needs_you,
      updated: want.updated,
      updatedAt: want.updated_at === null ? null : Date.parse(want.updated_at),
      card: {
        stop: want.card.stop,
        awaiting: want.card.awaiting,
        next: want.card.next,
        updated: want.card.updated,
        newestFile: want.card.newest_file,
      },
    })
  }
  expect(parseState('also awaiting: x\nawaiting: y\nawaiting owner in pane: z\n').awaiting).toBe('y')
  expect(parseState('rung: x').stop).toBeUndefined()
  expect(parseState('next: now\n\n## log\nnext: older\nstop: old stop\n')).toEqual({ next: 'now' })
})

test('parse: a ```state fence above a bulleted ## log gives the block keys only', () => {
  const text = [
    '```state',
    'session: atlas-ic',
    'stop: STOP 2 sent 15:11',
    'next: wait for the owner',
    '```',
    '',
    '## log',
    '- stop: STOP 1 approved; plan at `<record>`/plan.md',
    '- next: older next',
    '- superseded 15:44: awaiting: lead-1',
    '',
  ].join('\n')
  expect(parseState(text)).toEqual({ session: 'atlas-ic', stop: 'STOP 2 sent 15:11', next: 'wait for the owner' })
})

test('K4 pane: the fixture fleet draws rows a–e and the workflow row', async ($, on) => {
  const { ui, trace } = await openFleet($, on, FILES)

  for (const want of EXPECTED) {
    const row = await ui.find({ key: want.letter })
    expect(row?.props.label).toBe(`${want.name} · ${want.rung} · ${want.status}`)
    expect(row?.props.hotkey).toBe(want.letter)
  }
  const lines = await texts(ui)
  // Each awaiting line is in the old free-text form, shown as written and waiting on no one (C2); the pane cuts it
  // at its width (see O3).
  for (const want of EXPECTED) {
    expect((await boxTexts(ui, `more-${want.letter}`))[0]!.startsWith(`awaiting: ${want.needs_you.slice(0, 40)}`)).toBe(true)
  }
  expect(lines).toContain('5 IC (1 busy) · 0 wait on you · 1 workflow running')
  expect(await rowLabel(ui, 'f')).toMatch(/^workflow board-check-v0 · 0 of 2 agents returned · started \d\d:\d\d · running$/)
  // Every letter drawn on the board is a key: the IC rows a–e and the workflow row f. This fleet has no row g.
  expect((await ui.find({ key: 'f' }))?.props.hotkey).toBe('f')
  expect(await ui.find({ key: 'g' })).toBeUndefined()
  // A row's letter is drawn by its Button only: no Text starts with a letter and a colon.
  expect(lines.some(l => /^[a-z]:/.test(l))).toBe(false)
  expect(await legend(ui)).toBe('a–f open a card · Esc back to your prompt · other keys go to your prompt · ctrl+x x closes the board')

  // Reads only session files, STATE.md and workflow journals: no transcript, no other .jsonl.
  for (const path of trace.reads) {
    expect(path).toMatch(/(\/\.claude\/sessions\/\d+\.json|\/STATE\.md|\/subagents\/workflows\/wf_[^/]+\/journal\.jsonl)$/)
  }
  expect(trace.runs).toEqual([])
  await ui.unmount()
})

test('K5: a letter shows atlas-ic-1’s card, then the next letters switch it; no process runs', async ($, on) => {
  const { ui, trace, clock } = await openFleet($, on, FILES)
  const card = want('atlas-ic-1').card
  // The card's title is its first Text (the harness keys Boxes, not Texts).
  const cards = async () => ((await ui.find({ key: 'card' })) ? [(await cardTexts(ui))[0]] : [])

  expect(await cards()).toEqual([])
  await ui.press({ key: L('atlas-ic-1') })
  const fields = cardFields(await cardTexts(ui))
  // Its awaiting line is in the old form, so the title names no one it waits on (C2).
  expect(fields['']).toEqual([`${L('atlas-ic-1')} · atlas-ic-1`, DONE_42, 'updated 2026-10-21 15:46 BST · 1h09 ago'])
  // Each field's clauses, trimmed and joined back with single spaces, are the STATE.md value as written.
  expect(fields.stop!.join(' ')).toBe(card.stop)
  expect(fields.next!.join(' ')).toBe(card.next)
  expect(fields.awaiting!.join(' ')).toBe(card.awaiting)
  // The newest file beside STATE.md, never STATE.md itself (N8).
  expect(fields['newest file']!.join('')).toBe(`${HOME}/.fleet-agent-mgmt/checks/atlas-ic-1/stop-2.md`)
  expect((await texts(ui)).some(l => l.includes('takes you to that pane'))).toBe(false)

  // The owner's report: stuck on the first. Each later letter must move the card.
  const title = (name: string) => `${L(name)} · ${name}`
  await ui.press({ key: L('atlas-ic-2') })
  expect(await cards()).toEqual([title('atlas-ic-2')])
  await ui.press({ key: L('orbit-ic-1') })
  expect(await cards()).toEqual([title('orbit-ic-1')])

  // The same letter again keeps its card open (no toggle: a second press never blanks the board).
  await ui.press({ key: L('orbit-ic-1') })
  expect(await cards()).toEqual([title('orbit-ic-1')])

  // Keys still work after the 5 s refresh has re-rendered the pane.
  await clock.advance(5000)
  expect(await cards()).toEqual([title('orbit-ic-1')])
  await ui.press({ key: L('atlas-ic-1') })
  expect(await cards()).toEqual([title('atlas-ic-1')])
  await clock.advance(5000)
  await ui.press({ key: L('orbit-ic-2') })
  expect(await cards()).toEqual([title('orbit-ic-2')])

  // Every row keeps its own letter as hotkey and its own key after each redraw, the workflow row f included.
  for (const w of EXPECTED) expect((await ui.find({ key: w.letter }))?.props.hotkey).toBe(w.letter)
  expect((await ui.find({ key: 'f' }))?.props.hotkey).toBe('f')
  expect(trace.runs).toEqual([])

  // Esc: the engine hands the keys back to the prompt and the pane stays. The pane asks the keyboard on /fleet
  // and does not ask Esc to close it, so Esc cannot close the board or clear the card. The harness cannot send Esc.
  expect(trace.opens).toHaveLength(1)
  expect(trace.opens[0]).toMatchObject({ id: 'fleet', focus: true })
  expect(trace.opens[0]).not.toHaveProperty('closeOnEscape')
  await ui.unmount()
})

test('card helpers: clauses and path breaks keep every character', () => {
  // Every card value of every snapshot splits into pieces that join back to the value.
  for (const want of EXPECTED) {
    for (const v of [want.card.stop, want.card.awaiting, want.card.next]) expect(clauses(v).join('')).toBe(v)
  }
  expect(clauses("review first; fix its findings; ready only on the owner's word; never merge")).toEqual([
    'review first; ',
    'fix its findings; ',
    "ready only on the owner's word; ",
    'never merge',
  ])
  // Not inside () or "": the "; " and " / " there stay put.
  expect(clauses('a (x; y / z) b; c')).toEqual(['a (x; y / z) b; ', 'c'])
  expect(clauses('PO said "a; b. C" here. Then')).toEqual(['PO said "a; b. C" here. ', 'Then'])
  // ". " cuts only before a capital, a digit or "("; " / " starts the next piece.
  expect(clauses('done. lead-1 next. E14 ok. (x) y / b z')).toEqual(['done. lead-1 next. ', 'E14 ok. ', '(x) y', ' / b z'])
  expect(clauses('-')).toEqual(['-'])

  const path = '/Users/owner/.orbit/drafts/week-43/export-columns.schema.json,'
  expect(breakPath(path, 52)).toEqual(['/Users/owner/.orbit/drafts/week-43/', 'export-columns.schema.json,'])
  expect(breakPath(path, 200)).toEqual([path])
  expect(breakPath('nopathatalltoolong', 5)).toEqual(['nopathatalltoolong'])
  const text = `the draft schema (2026-10-21): ${path} valid`
  expect(breakLong(text, 52)).toBe('the draft schema (2026-10-21): /Users/owner/.orbit/drafts/week-43/\nexport-columns.schema.json, valid')
  expect(breakLong(text, 52).replace(/\n/g, '')).toBe(text)
  expect(splitPath('/Users/owner/.fleet-agent-mgmt/checks/atlas-ic-1/STATE.md')).toEqual(['/Users/owner/.fleet-agent-mgmt/checks/atlas-ic-1/', 'STATE.md'])
  expect(splitPath('-')).toEqual(['', '-'])
})

test('card shape: atlas-ic-1 (fenced block) and atlas-ic-2 (bare lines), fields in order stop, next, newest file, awaiting', async ($, on) => {
  const { ui } = await openFleet($, on, FILES)
  const labels = (lines: string[]) => lines.filter(l => ['stop', 'next', 'newest file', 'awaiting', 'updated'].includes(l))

  await ui.press({ key: L('atlas-ic-1') })
  let lines = await cardTexts(ui)
  expect(labels(lines)).toEqual(['stop', 'next', 'newest file', 'awaiting'])
  expect(cardFields(lines)).toEqual({
    '': [`${L('atlas-ic-1')} · atlas-ic-1`, DONE_42, 'updated 2026-10-21 15:46 BST · 1h09 ago'],
    stop: ['STOP 2 ready for push sent 15:11 (/Users/owner/.fleet-agent-mgmt/checks/atlas-ic-1/stop-2.md)'],
    next: ["wait for the owner's word to mark PR #86 ready;", 'never merge'],
    'newest file': ['/Users/owner/.fleet-agent-mgmt/checks/atlas-ic-1/', 'stop-2.md'],
    awaiting: [
      'ATL-42 D4 (sent to lead-1 at 14:57): which retry limit to ship',
      '/ a three tries, then fail the run',
      '/ b five tries, then fail the run',
    ],
  })
  // Each clause row is a "·" mark beside a column holding the text, so its wrapped rows hang under the text.
  const row = await ui.find({ key: 'card-awaiting-1' })
  expect(row?.props.flexDirection).toBe('row')
  expect((await ui.find({ key: 'card-awaiting-1-mark' }))?.props).toMatchObject({ width: 2, flexShrink: 0 })
  expect((await ui.find({ key: 'card-awaiting-1-body' }))?.props).toMatchObject({ flexShrink: 1 })
  for (const id of ['stop', 'next', 'newest', 'awaiting']) expect((await ui.find({ key: `card-${id}` }))?.props.marginTop).toBe(1)
  expect((await ui.find({ key: 'card-stop' }))?.children?.[0]).toMatchObject({ type: 'Text', props: { bold: true, dimColor: true } })

  await ui.press({ key: L('atlas-ic-2') })
  lines = await cardTexts(ui)
  expect(labels(lines)).toEqual(['stop', 'next', 'newest file', 'awaiting'])
  expect(cardFields(lines)).toEqual({
    '': [`${L('atlas-ic-2')} · atlas-ic-2`, DONE_43, 'updated 2026-10-21 14:46 BST · 2h09 ago'],
    stop: ['STOP 2 sent 14:41;', 'branch pushed, draft PR #85 open (DR3)'],
    next: ['review first;', 'fix its findings;', "ready only on the owner's word;", 'never merge'],
    'newest file': ['/Users/owner/.fleet-agent-mgmt/checks/atlas-ic-2/', 'stop-2.md'],
    awaiting: [want('atlas-ic-2').card.awaiting],
  })

  // No time in updated: no age. The title never carries "card" or a bare "since HH:MM".
  await ui.press({ key: L('orbit-ic-2') })
  expect(cardFields(await cardTexts(ui))['']).toEqual([
    `${L('orbit-ic-2')} · orbit-ic-2`,
    '● NOT DONE · orb-8-r1 open · no close report yet',
    'updated 2026-10-21 BST',
  ])
  expect((await texts(ui)).some(l => / · card · |waiting on you since/.test(l))).toBe(false)
  await ui.unmount()
})

test('card at 60 columns: a long path breaks after a "/", never mid-word; a missing key shows "-"', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const path = `${HOME}/.fleet-agent-mgmt/checks/atlas-ic-2/STATE.md`
  files[path] = { ...files[path]!, text: files[path]!.text.replace(/^awaiting: .*\n/m, '') }
  const { ui } = await openFleet($, on, files, 'terminal', 60)

  await ui.press({ key: L('orbit-ic-1') })
  const lines = await cardTexts(ui)
  expect(lines.some(l => l.includes('/Users/owner/.orbit/drafts/week-43/\nexport-columns.schema.json,'))).toBe(true)
  // Only the card's own line breaks were added: taken out, each field is its value again.
  const fields = cardFields(lines.map(l => l.replace(/\n/g, '')))
  expect(fields.awaiting!.join(' ')).toBe(want('orbit-ic-1').card.awaiting)
  expect(fields.stop!.join(' ')).toBe(want('orbit-ic-1').card.stop)

  await ui.press({ key: L('atlas-ic-2') })
  const b = cardFields(await cardTexts(ui))
  expect(b['']![0]).toBe(`${L('atlas-ic-2')} · atlas-ic-2`)
  expect(b.awaiting).toEqual(['-'])
  await ui.unmount()
})

test('read scope: a session name or lead-1 id with a path in it is skipped, never listed or read', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const sessions = `${HOME}/.claude/sessions`
  for (const [i, name] of ['../projects/x', '../../.ssh', '.', 'a/b'].entries()) {
    files[`${sessions}/9900${i}.json`] = {
      text: JSON.stringify({ name, status: 'idle', sessionId: '00000000-0000-0000-0000-00000000000' + i, updatedAt: 1 }),
      mtimeMs: 1,
    }
  }
  // A newer lead-1 session file whose id climbs out of its project folder wins the name, and must not be followed.
  const leadPath = Object.keys(files).find(p => p.startsWith(sessions) && JSON.parse(files[p]!.text).name === 'lead-1')!
  const lead = JSON.parse(files[leadPath]!.text)
  files[`${sessions}/99010.json`] = {
    text: JSON.stringify({ ...lead, sessionId: '../../../.ssh', updatedAt: (lead.updatedAt ?? 0) + 1 }),
    mtimeMs: 2,
  }
  const { ui, trace } = await openFleet($, on, files)

  const checks = `${HOME}/.fleet-agent-mgmt/checks/`
  const projects = `${HOME}/.claude/projects/`
  // A record folder is only listed, never read, and only as records/<project>/<folder> of plain names.
  const records = `${HOME}/.fleet-agent-mgmt/records/`
  for (const path of [...trace.lists, ...trace.reads]) {
    expect(path.includes('..')).toBe(false)
    expect(path.startsWith(sessions) || path.startsWith(checks) || path.startsWith(projects) || path.startsWith(records)).toBe(true)
    if (path.startsWith(checks)) expect(path.slice(checks.length).split('/')[0]).toMatch(/^[A-Za-z0-9_-][A-Za-z0-9._-]*$/)
    if (path.startsWith(records)) {
      expect(trace.reads).not.toContain(path)
      for (const part of path.slice(records.length).split('/')) expect(part).toMatch(/^[A-Za-z0-9_-][A-Za-z0-9._-]*$/)
    }
  }
  expect(trace.lists).not.toContain(`${HOME}/.fleet-agent-mgmt/checks/.`)
  // lead-1's newest file names an unsafe id, so no workflow folder is listed at all.
  expect(trace.lists.some(p => p.startsWith(projects))).toBe(false)
  await ui.unmount()
})

test('a journal.jsonl that is a link is never read', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const journal = Object.keys(files).find(p => p.endsWith('/wf_5a6b7c8d-342/journal.jsonl'))!
  files[journal] = { ...files[journal]!, kind: 'other' }
  const { ui, trace } = await openFleet($, on, files)

  expect(trace.reads).not.toContain(journal)
  expect(await rowLabel(ui, 'f')).toMatch(/^workflow board-check-v0 · \? of \? agents returned · /)
  await ui.unmount()
})

test('a failed read is not tried again until the mtime moves', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const journal = Object.keys(files).find(p => p.endsWith('/wf_5a6b7c8d-342/journal.jsonl'))!
  files[journal] = { ...files[journal]!, fail: true }
  const { ui, trace, clock } = await openFleet($, on, files, 'desktop')
  const tries = () => trace.reads.filter(p => p === journal).length
  expect(tries()).toBe(1)

  await clock.advance(5000)
  await clock.advance(5000)
  expect(tries()).toBe(1)

  files[journal] = { ...files[journal]!, fail: false, mtimeMs: files[journal]!.mtimeMs + 1000 }
  await clock.advance(5000)
  expect(tries()).toBe(2)
  expect(await rowLabel(ui, 'f')).toMatch(/^workflow board-check-v0 · 0 of 2 agents returned · /)
  await ui.unmount()
})

test('refresh: every 5 s, a file is read again only when its mtime moved', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const { ui, trace, clock } = await openFleet($, on, files, 'desktop')
  const firstReads = trace.reads.length

  await clock.advance(5000)
  expect(trace.reads.length).toBe(firstReads)

  const path = `${HOME}/.fleet-agent-mgmt/checks/atlas-ic-2/STATE.md`
  const old = files[path]!
  files[path] = { text: old.text.replace(/^awaiting: .*$/m, 'awaiting: owner: the D4 ruling'), mtimeMs: old.mtimeMs + 1000 }
  await clock.advance(5000)
  expect(trace.reads.slice(firstReads)).toEqual([path])
  expect((await texts(ui)).some(l => l.startsWith('waiting on you: the D4 ruling · '))).toBe(true)
  await ui.unmount()
})

test('head line and the last: line for an IC not waiting on you', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const path = `${HOME}/.fleet-agent-mgmt/checks/atlas-ic-2/STATE.md`
  files[path] = { ...files[path]!, text: files[path]!.text.replace(/^awaiting: .*\n/m, '') }
  const { ui } = await openFleet($, on, files)
  const lines = await texts(ui)

  expect(lines.some(l => /^\d\d:\d\d · refreshed 0s ago$/.test(l))).toBe(true)
  expect(lines).toContain("last: 2026-10-21 14:46 BST · next: review first; fix its findings; ready only on the owner's word; never merge")
  // Rows still waiting on you keep only their needs-you line.
  expect(lines.filter(l => l.startsWith('last: '))).toHaveLength(1)
  await ui.unmount()
})

test('header counts only rows waiting and running workflows', async () => {
  expect(header([], NOW)).toBe('0 IC (0 busy) · 0 wait on you · 0 workflows running')
})

test('O1: 0 closes the card, drawn only while a card is open; /fleet opens the board with no card', async ($, on) => {
  const { ui } = await openFleet($, on, FILES)
  const card = async () => (await ui.find({ key: 'card' })) !== undefined

  // No card: no close key, and the legend says how to close the board.
  expect(await ui.find({ key: 'close-card' })).toBeUndefined()
  expect(await legend(ui)).not.toContain('0 closes the card')
  expect(await legend(ui)).toContain('ctrl+x x closes the board')

  await ui.press({ key: 'a' })
  expect((await ui.find({ key: 'close-card' }))?.props).toMatchObject({ hotkey: '0', label: 'close card', plain: true })
  expect(await legend(ui)).toContain('0 closes the card')
  expect(await legend(ui)).toContain('ctrl+x x closes the board')
  // The same letter twice keeps the card.
  await ui.press({ key: 'a' })
  expect(await card()).toBe(true)

  await ui.press({ key: 'close-card' })
  expect(await card()).toBe(false)
  expect(await ui.find({ key: 'close-card' })).toBeUndefined()
  expect(await legend(ui)).not.toContain('0 closes the card')
  expect(await legend(ui)).toContain('ctrl+x x closes the board')

  // /fleet always opens the bare board.
  await ui.press({ key: 'c' })
  expect(await card()).toBe(true)
  await $.command.run({ command: 'fleet', args: '' })
  expect(await card()).toBe(false)

  // Closing the board (the close mark or ctrl+x x) clears the card too, through the ui.close hook. The test's `$`
  // has no ui.close to raise that chain (the kit's ui noun is render, scroll, focus, press, input, select, mount),
  // so that part is SPEC "How to try it" row 12.
  await ui.unmount()
})

test('O2: every letter drawn on the board is a key; f opens the workflow’s read-only card', async ($, on) => {
  const { ui, trace } = await openFleet($, on, FILES)
  expect(LETTERS.join('')).toBe('abcdefghijklmnopqrstuvwxyz')
  expect(LETTERS[6]).toBe('g')

  // Each row's letter is drawn by a Button whose hotkey is that letter.
  const buttons = (await ui.findAll({ type: 'Button' })).filter((n: any) => n.props.hotkey !== '0')
  expect(buttons.map((n: any) => n.props.hotkey)).toEqual(['a', 'b', 'c', 'd', 'e', 'f'])
  for (const n of buttons) expect(n.key ?? n.props.key ?? n.props.hotkey).toBe(n.props.hotkey)

  await ui.press({ key: 'f' })
  const lines = await cardTexts(ui)
  expect(lines[0]).toBe('f · workflow board-check-v0')
  const fields: Record<string, string> = {}
  for (let i = 1; i + 1 < lines.length; i += 2) fields[lines[i]!] = lines[i + 1]!
  expect(fields).toMatchObject({ agents: '0 of 2 returned', status: 'running', 'run id': 'wf_5a6b7c8d-342' })
  expect(fields.started).toMatch(/^\d\d:\d\d$/)
  expect(fields.journal!.replace(/\n/g, '')).toMatch(/\/subagents\/workflows\/wf_5a6b7c8d-342\/journal\.jsonl$/)
  expect((await ui.find({ key: 'close-card' }))?.props.hotkey).toBe('0')

  // From the workflow card to an IC card and back.
  await ui.press({ key: L('atlas-ic-1') })
  expect((await cardTexts(ui))[0]).toBe(`${L('atlas-ic-1')} · atlas-ic-1`)
  await ui.press({ key: 'f' })
  expect((await cardTexts(ui))[0]).toBe('f · workflow board-check-v0')
  expect(trace.runs).toEqual([])
  await ui.unmount()
})

test('N3a: the legend says when the keys are at the prompt and how to get them back', async ($, on) => {
  const { ui } = await openFleet($, on, FILES, 'terminal', 120, false)
  const away = await legend(ui)
  expect(away).toContain('ctrl+x tab')
  expect(away).not.toContain('open a card')
  // ctrl+x x is the engine's close only while the pane holds the keys, so away from the board the legend says so.
  expect(away).toContain('ctrl+x tab, then ctrl+x x closes the board')
  expect(away.split(' · ')).not.toContain('ctrl+x x closes the board')
  // Drawn in amber, as everything that needs the owner is.
  expect((await ui.find({ key: 'keys' }))?.children?.[0]).toMatchObject({ type: 'Text', props: { color: 'warning' } })
  await ui.unmount()

  const focused = await $.ui.mount({ ...MOUNT, surface: 'terminal' })
  expect(await legend(focused)).toContain('a–f open a card')
  expect(await legend(focused)).not.toContain('ctrl+x tab')
  expect((await legend(focused)).split(' · ')).toContain('ctrl+x x closes the board')
  await focused.unmount()
})

test('O1: closing the board still closes it when the hook that clears the card fails', async () => {
  // The kit cannot raise ui.close, so this reads the registration itself: the ui.close hook carries a fallback
  // that hands the close on to the engine, so a failed card reset never keeps the board open.
  const regs: { event: string; matcher?: unknown; fallback?: (...a: any[]) => unknown }[] = []
  const fakeOn = (event: string, ...rest: unknown[]) => {
    const r: (typeof regs)[number] = { event, matcher: rest.length > 1 ? rest[0] : undefined }
    regs.push(r)
    const handle = {
      catch(fn: (...a: any[]) => unknown) {
        r.fallback = fn
        return handle
      },
    }
    return handle
  }
  register(fakeOn as any, {} as any)
  const close = regs.find(r => r.event === 'ui.close')
  expect(close?.matcher).toEqual({ id: 'fleet' })
  expect(typeof close?.fallback).toBe('function')
  const passed: unknown[] = []
  const result = await close!.fallback!({}, { id: 'fleet' }, (e: unknown) => {
    passed.push(e)
    return 'closed'
  })
  expect(passed).toEqual([{ id: 'fleet' }])
  expect(result).toBe('closed')
})

test('N4: the open card follows the IC by name; letters follow the names, not the session file names', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const { ui, clock } = await openFleet($, on, files)
  const names = ['apex-ic-1', 'atlas-ic-1', 'atlas-ic-2', 'orbit-ic-1', 'orbit-ic-2']
  const letters = async () => {
    const out: Record<string, string> = {}
    for (const l of 'abcde') out[l] = ((await rowLabel(ui, l)) ?? '').split(' · ')[0]!
    return out
  }
  const byName = Object.fromEntries(names.map((n, i) => ['abcde'[i]!, n]))
  expect(await letters()).toEqual(byName)
  for (const n of names) expect(L(n)).toBe('abcde'[names.indexOf(n)])

  await ui.press({ key: L('orbit-ic-1') })
  expect((await cardTexts(ui))[0]).toBe(`${L('orbit-ic-1')} · orbit-ic-1`)

  // atlas-ic-1 restarts: its session file goes and one with a higher pid comes. Nothing moves.
  const sessions = `${HOME}/.claude/sessions`
  const old = files[`${sessions}/42001.json`]!
  delete files[`${sessions}/42001.json`]
  files[`${sessions}/99999.json`] = { ...old, mtimeMs: old.mtimeMs + 1000 }
  await clock.advance(5000)
  expect(await letters()).toEqual(byName)
  expect((await cardTexts(ui))[0]).toBe(`${L('orbit-ic-1')} · orbit-ic-1`)

  // orbit-ic-1 ends: its card goes with it, never handed to the IC now on its letter.
  delete files[`${sessions}/43001.json`]
  await clock.advance(5000)
  expect(await ui.find({ key: 'card' })).toBeUndefined()
  await ui.unmount()
})

/** A Button's row as drawn: its hotkey, a colon and a space, then its children's text. */
async function buttonLine(ui: any, letter: string): Promise<string> {
  const button = await ui.find({ key: letter })
  return `${button.props.hotkey}: ${(button.children ?? []).map(flat).join('')}`
}

test('O3: the dock is asked as wide as the engine allows; rows are cut at the pane width with "…", whole when they fit', async ($, on) => {
  // The engine holds a dock to min(floor(0.45 w), w - 60) columns of a w-column terminal.
  const fit = (parse as any).dockColumns
  expect(typeof fit).toBe('function')
  expect([fit(200), fit(220), fit(300), fit(120), fit(40)]).toEqual([90, 99, 135, 54, 1])

  const { ui, trace } = await openFleet($, on, FILES, 'terminal', 86)
  // The kit's /fleet carries no terminal width, so the board asks for no width and the engine's share stands.
  expect(trace.opens[0]).not.toHaveProperty('columns')
  // A /fleet typed in a 200-column terminal asks for the 90 the engine allows there.
  await $.command.run({ command: 'fleet', args: '', presentation: { isFullscreen: true, columns: 200 } } as any)
  expect(trace.opens[1]).toMatchObject({ id: 'fleet', focus: true, columns: 90 })

  // icRow keeps the STATE.md rung and awaiting in full; the pane does the cutting.
  const c = icRow('c', { name: 'atlas-ic-2', status: 'idle', state: FILES[`${HOME}/.fleet-agent-mgmt/checks/atlas-ic-2/STATE.md`]!.text })
  expect(c.rung).toBe('ATL-43 r1, a weekly email that lists the imports that failed, sent to the data team on Monday mornings')
  expect(c.needsYou).toBe(c.card.awaiting)

  // At 86 body columns: the "▌" mark takes 1, so every row line fits in 85, a cut one ending in "…".
  for (const w of EXPECTED) {
    const first = await buttonLine(ui, w.letter)
    expect(Array.from(first).length).toBeLessThanOrEqual(85)
    expect(first.endsWith(` · ${w.status}`)).toBe(true)
    const more = await ui.find({ key: `more-${w.letter}` })
    expect(more?.props.paddingLeft).toBe(3)
    for (const line of await boxTexts(ui, `more-${w.letter}`)) expect(Array.from(line).length).toBeLessThanOrEqual(82)
    for (const t of more.children) expect(t.props.wrap).toBe('truncate-end')
  }
  expect(await buttonLine(ui, L('atlas-ic-2'))).toMatch(/^c: atlas-ic-2 · ATL-43 r1, a weekly email that lists[^·]*… · idle$/)
  expect((await boxTexts(ui, `more-${L('atlas-ic-1')}`))[0]).toMatch(/^awaiting: ATL-42 D4 .*… · 1h09$/)
  // No row line is pushed in with spaces: the second line sits in its own column, 3 cells in, under the label.
  expect((await texts(ui)).some(l => l.startsWith('   '))).toBe(false)
  await ui.unmount()

  // At 400 columns nothing is cut.
  const wide = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 400 } })
  expect(await buttonLine(wide, L('atlas-ic-2'))).toBe('c: atlas-ic-2 · ATL-43 r1, a weekly email that lists the imports that failed, sent to the data team on Monday mornings · idle')
  expect((await boxTexts(wide, `more-${L('atlas-ic-1')}`))[0]).toBe(`awaiting: ${want('atlas-ic-1').card.awaiting} · 1h09`)
  await wide.unmount()
})

/** The fixture fleet with every awaiting line taken out, so no IC waits and each draws its "last:" line. */
function noneWaiting(): Files {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  for (const p of Object.keys(files)) if (p.endsWith('/STATE.md')) files[p]!.text = files[p]!.text.replace(/^awaiting: .*\n/gm, '')
  return files
}

test('O3: an IC waiting on nobody draws its "last:" line cut at the pane width with "…", whole when it fits', async ($, on) => {
  const { ui } = await openFleet($, on, noneWaiting(), 'terminal', 86)
  // At 86 body columns the second lines sit 3 in past the "▌" mark, so each fits in 82.
  let cut = 0
  for (const w of EXPECTED) {
    const last = (await boxTexts(ui, `more-${w.letter}`)).find(l => l.startsWith('last: '))
    expect(last).toBeDefined()
    expect(Array.from(last!).length).toBeLessThanOrEqual(82)
    if (last!.endsWith('…')) cut++
  }
  // Every fixture "next:" is longer than the room, so every one is cut.
  expect(cut).toBe(EXPECTED.length)
  await ui.unmount()

  const wide = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 400 } })
  for (const w of EXPECTED) {
    expect((await boxTexts(wide, `more-${w.letter}`)).find(l => l.startsWith('last: '))).toBe(`last: ${w.updated} · next: ${w.card.next}`)
  }
  await wide.unmount()
})

/** The fixture fleet with today's workflow renamed `name`. */
function workflowNamed(name: string): Files {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const old = Object.keys(files).find(p => p.endsWith('/workflows/scripts/board-check-v0-wf_5a6b7c8d-342.js'))!
  files[old.replace('/board-check-v0-', `/${name}-`)] = files[old]!
  delete files[old]
  return files
}

test('O3: a workflow row is cut at the pane width with "…"; its state stays whole', async ($, on) => {
  const long = 'board-check-layout-fixes-round-one-with-a-long-name'
  const { ui } = await openFleet($, on, workflowNamed(long), 'terminal', 86)
  // At 86 body columns the name gives way first: the counts and the time stay whole.
  const at86 = await buttonLine(ui, 'f')
  expect(Array.from(at86).length).toBeLessThanOrEqual(85)
  expect(at86).toMatch(/^f: workflow board-check-layout[^·]*… · 0 of 2 agents returned · started \d\d:\d\d · running$/)
  await ui.unmount()

  // At 60 the name keeps its first letters and the counts give way too; the line still fits in 59.
  const narrow = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 60 } })
  const at60 = await buttonLine(narrow, 'f')
  expect(Array.from(at60).length).toBeLessThanOrEqual(59)
  expect(at60).toMatch(/^f: workflow board-che[^·]*… · 0 of 2 [^·]*… · running$/)
  await narrow.unmount()

  // With room, nothing is cut.
  const wide = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 400 } })
  expect(await buttonLine(wide, 'f')).toMatch(new RegExp(`^f: workflow ${long} · 0 of 2 agents returned · started \\d\\d:\\d\\d · running$`))
  await wide.unmount()
})

test('O3: on a 60-column pane every row line fits, the fixture workflow row included', async ($, on) => {
  const { ui } = await openFleet($, on, FILES, 'terminal', 60)
  for (const letter of [...EXPECTED.map(w => w.letter), 'f']) {
    const line = await buttonLine(ui, letter)
    expect(Array.from(line).length).toBeLessThanOrEqual(59)
    expect(line).toContain('…')
  }
  expect(await buttonLine(ui, 'f')).toMatch(/^f: workflow board-che[^·]*… · /)
  await ui.unmount()
})

test('O4: the head row reads "FLEET · read-only · /fleet opens it" with the time on its right, above the counts', async ($, on) => {
  const { ui, trace } = await openFleet($, on, FILES)
  // The pane's title is drawn only as a tab while two panes are open, so it stays short.
  expect(trace.opens[0]).toMatchObject({ title: 'fleet' })
  expect((await ui.find({ key: 'head' }))?.props).toMatchObject({ flexDirection: 'row', justifyContent: 'space-between' })
  const [left, clock] = await boxTexts(ui, 'head')
  expect(left).toBe('FLEET · read-only · /fleet opens it')
  expect(clock).toMatch(/^\d\d:\d\d · refreshed 0s ago$/)
  const lines = await texts(ui)
  expect(lines[0]).toBe('FLEET · read-only · /fleet opens it')
  expect(lines.indexOf(clock!)).toBeLessThan(lines.findIndex(l => l.startsWith('5 IC (')))
  // The time is no longer a line of its own under the counts.
  expect(lines.filter(l => /^\d\d:\d\d · refreshed /.test(l))).toEqual([clock])
  await ui.unmount()
})

test('N6: the legend is under the head row; with a card open every row is one line, so the card starts high', async ($, on) => {
  const { ui } = await openFleet($, on, FILES)
  const lines = await texts(ui)
  const at = (s: string) => lines.findIndex(l => l.startsWith(s))
  expect(at('FLEET')).toBeLessThan(at('a–f open a card'))
  expect(at('a–f open a card')).toBeLessThan(at('5 IC ('))
  for (const w of EXPECTED) expect((await ui.find({ key: `row-${w.letter}` }))?.props.marginTop).toBe(1)

  await ui.press({ key: L('orbit-ic-1') })
  for (const w of [...EXPECTED.map(x => x.letter), 'f']) {
    expect((await ui.find({ key: `row-${w}` }))?.props.marginTop).toBe(0)
    expect(await ui.find({ key: `more-${w}` })).toBeUndefined()
  }
  expect(await ui.find({ key: 'card' })).toBeDefined()
  // The press also asks the engine to bring the card into view. The kit has no window to scroll: it answers a
  // plugin's $.ui.scroll with "no implementation" before any ui.scroll hook of the test's sees it, so no test can
  // tell the call is made. That is SPEC "How to try it" row 17; here the press still opens the card although the
  // scroll is refused.

  await ui.press({ key: 'close-card' })
  for (const w of EXPECTED) expect(await ui.find({ key: `more-${w.letter}` })).toBeDefined()
  await ui.unmount()
})

/** The counts line's "<n> wait on you" part. */
const waitText = async (ui: any) => (await ui.findAll({ type: 'Text' })).find((t: any) => /^\d+ wait on you/.test(t.text))

test('N9: "1 workflow running", and the wait count is amber while something waits', async ($, on) => {
  const wf: Row = { kind: 'workflow', letter: 'a', name: 'x', id: 'wf_1', started: 1, returned: 0, startedAt: NOW, journal: '' }
  expect(header([wf], NOW)).toBe('0 IC (0 busy) · 0 wait on you · 1 workflow running')
  expect(header([wf, { ...wf, id: 'wf_2' }], NOW)).toBe('0 IC (0 busy) · 0 wait on you · 2 workflows running')

  // Only an "owner:" line waits on you (C2): one IC is given one.
  const { ui } = await openFleet($, on, withAwaiting({ 'atlas-ic-1': 'owner: the D4 ruling' }))
  expect((await texts(ui)).find(l => l.startsWith('5 IC ('))).toMatch(/ · 1 workflow running$/)
  expect((await waitText(ui))?.text).toBe('1 wait on you, oldest 1h09 (atlas-ic-1)')
  expect((await waitText(ui))?.props.color).toBe('warning')
  await ui.unmount()
})

test('N9: with nothing waiting the wait count is plain, not amber', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  for (const p of Object.keys(files)) if (p.endsWith('/STATE.md')) files[p]!.text = files[p]!.text.replace(/^awaiting: .*\n/gm, '')
  const { ui } = await openFleet($, on, files)
  expect((await waitText(ui))?.text).toBe('0 wait on you')
  expect((await waitText(ui))?.props.color).toBeUndefined()
  await ui.unmount()
})

test('N9: an empty fleet says nothing was found, and the legend names no card to open', async ($, on) => {
  const { ui } = await openFleet($, on, {})
  const lines = await texts(ui)
  expect(lines).toContain('0 IC (0 busy) · 0 wait on you · 0 workflows running')
  expect(lines).toContain('no IC sessions with a STATE.md, and no lead-1 workflow today')
  expect(lines.some(l => l.includes('open a card') || l.includes('a letter'))).toBe(false)
  expect(await legend(ui)).toBe('Esc back to your prompt · other keys go to your prompt · ctrl+x x closes the board')
  await ui.unmount()
})

/** The fixture fleet with each named IC's "awaiting:" line set to the given text (null takes the line out). */
function withAwaiting(lines: Record<string, string | null>): Files {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  for (const [name, line] of Object.entries(lines)) {
    const f = files[`${HOME}/.fleet-agent-mgmt/checks/${name}/STATE.md`]!
    f.text = f.text.replace(/^awaiting: .*\n/m, line === null ? '' : `awaiting: ${line}\n`)
  }
  return files
}

/** The Texts of a row's second lines, each with its colour. */
async function moreLines(ui: any, letter: string): Promise<{ text: string; color?: string }[]> {
  const more = await ui.find({ key: `more-${letter}` })
  return (more?.children ?? []).map((t: any) => ({ text: t.text ?? flat(t), color: t.props.color }))
}

test('C2 parse: the awaiting line opens with none, owner:, lead-1: or a name on the board; any other line is the old form', () => {
  const awaitingOf = (parse as any).awaitingOf
  expect(typeof awaitingOf).toBe('function')
  const names = ['lead-1', 'atlas-ic-1', 'atlas-ic-2']
  expect(awaitingOf('none', names)).toEqual({ kind: 'none' })
  expect(awaitingOf('none; owner said wait for the push', names)).toEqual({ kind: 'none' })
  expect(awaitingOf('owner: the D4 ruling', names)).toEqual({ kind: 'owner', rest: 'the D4 ruling' })
  expect(awaitingOf('owner:', names)).toEqual({ kind: 'owner', rest: '' })
  expect(awaitingOf('lead-1: review of stop-2', names)).toEqual({ kind: 'who', who: 'lead-1', rest: 'review of stop-2' })
  expect(awaitingOf('atlas-ic-2: the schema', names)).toEqual({ kind: 'who', who: 'atlas-ic-2', rest: 'the schema' })
  // The old form: "none", "nothing", "-" or empty is idle; anything else is kept as its text.
  expect(awaitingOf('nothing. idle since 14:00', names)).toEqual({ kind: 'none' })
  expect(awaitingOf('-', names)).toEqual({ kind: 'none' })
  expect(awaitingOf('', names)).toEqual({ kind: 'none' })
  expect(awaitingOf('PO: a word on N4 here', names)).toEqual({ kind: 'old', text: 'PO: a word on N4 here' })
  expect(awaitingOf('lead-1 and the PO: answers', names)).toEqual({ kind: 'old', text: 'lead-1 and the PO: answers' })
  expect(awaitingOf('orbit-ic-2 walkthrough', names)).toEqual({ kind: 'old', text: 'orbit-ic-2 walkthrough' })
  // A name not on the board is not a "who".
  expect(awaitingOf('atlas-ic: x', names)).toEqual({ kind: 'old', text: 'atlas-ic: x' })
})

test('C2 pane: only owner: waits on you; lead-1: and a name wait on them; none is idle; the header counts owner: lines', async ($, on) => {
  const files = withAwaiting({
    'apex-ic-1': 'owner: rulings on N2',
    'atlas-ic-1': 'lead-1: the D4 card',
    'atlas-ic-2': 'none',
    'orbit-ic-1': 'atlas-ic-2: the schema',
  })
  const { ui } = await openFleet($, on, files, 'terminal', 400)
  expect(await texts(ui)).toContain('5 IC (1 busy) · 1 wait on you, oldest 36d (apex-ic-1) · 1 workflow running')
  expect(await moreLines(ui, L('apex-ic-1'))).toEqual([{ text: 'waiting on you: rulings on N2 · 36d', color: 'warning' }])
  expect(await moreLines(ui, L('atlas-ic-1'))).toEqual([{ text: 'waiting on lead-1: the D4 card · 1h09', color: undefined }])
  const idle = await moreLines(ui, L('atlas-ic-2'))
  expect(idle.map(l => l.text)).toEqual([`last: 2026-10-21 14:46 BST · next: ${want('atlas-ic-2').card.next}`])
  expect(await moreLines(ui, L('orbit-ic-1'))).toEqual([{ text: 'waiting on atlas-ic-2: the schema · 22m', color: undefined }])
  expect(await moreLines(ui, L('orbit-ic-2'))).toEqual([
    { text: `awaiting: ${want('orbit-ic-2').needs_you} · -`, color: undefined },
  ])

  const title = async (name: string) => {
    await ui.press({ key: L(name) })
    return (await cardTexts(ui))[0]
  }
  expect(await title('apex-ic-1')).toBe(`${L('apex-ic-1')} · apex-ic-1 · waiting on you`)
  expect(await title('atlas-ic-1')).toBe(`${L('atlas-ic-1')} · atlas-ic-1 · waiting on lead-1`)
  expect(await title('atlas-ic-2')).toBe(`${L('atlas-ic-2')} · atlas-ic-2`)
  expect(await title('orbit-ic-1')).toBe(`${L('orbit-ic-1')} · orbit-ic-1 · waiting on atlas-ic-2`)
  expect(await title('orbit-ic-2')).toBe(`${L('orbit-ic-2')} · orbit-ic-2`)
  await ui.unmount()
})

test('C2 old form: the fixture lines never read as waiting on you', async ($, on) => {
  const { ui } = await openFleet($, on, FILES, 'terminal', 400)
  expect(await texts(ui)).toContain('5 IC (1 busy) · 0 wait on you · 1 workflow running')
  expect((await texts(ui)).some(l => l.includes('waiting on you') || l.startsWith('needs you'))).toBe(false)
  const since: Record<string, string> = {
    'apex-ic-1': '36d',
    'atlas-ic-1': '1h09',
    'atlas-ic-2': '2h09',
    'orbit-ic-1': '22m',
    'orbit-ic-2': '-',
  }
  // Each shown as written (a long one cut with "…"), plain, never amber.
  for (const w of EXPECTED) {
    const lines = await moreLines(ui, w.letter)
    expect(lines).toHaveLength(1)
    expect(lines[0]!.color).toBeUndefined()
    expect(lines[0]!.text.startsWith(`awaiting: ${w.needs_you.slice(0, 60)}`)).toBe(true)
    expect(lines[0]!.text.endsWith(` · ${since[w.name]}`)).toBe(true)
  }
  for (const w of EXPECTED) {
    await ui.press({ key: w.letter })
    expect((await cardTexts(ui))[0]).toBe(`${w.letter} · ${w.name}`)
  }
  await ui.unmount()
})

test('C2 old form: an awaiting line of none, nothing or - is idle and draws the "last:" line', async ($, on) => {
  const { ui: idle } = await openFleet($, on, withAwaiting({ 'atlas-ic-1': 'none', 'atlas-ic-2': 'nothing. idle since 14:00', 'orbit-ic-1': '-' }))
  expect(await texts(idle)).toContain('5 IC (1 busy) · 0 wait on you · 1 workflow running')
  for (const name of ['atlas-ic-1', 'atlas-ic-2', 'orbit-ic-1']) {
    const lines = await moreLines(idle, L(name))
    expect(lines).toHaveLength(1)
    expect(lines[0]!.text.startsWith('last: ')).toBe(true)
  }
  await idle.unmount()
})

test('N1: one unreadable STATE.md shows that row as unreadable and leaves the rest of the board', async ($, on) => {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  const path = `${HOME}/.fleet-agent-mgmt/checks/atlas-ic-1/STATE.md`
  files[path] = { ...files[path]!, fail: true }
  const { ui, clock } = await openFleet($, on, files)
  const lines = await texts(ui)
  expect(lines.some(l => l.includes('reading the fleet'))).toBe(false)
  expect(lines.find(l => l.startsWith('5 IC ('))).toBeDefined()
  for (const w of EXPECTED.filter(x => x.name !== 'atlas-ic-1')) expect(await rowLabel(ui, w.letter)).toBe(`${w.name} · ${w.rung} · ${w.status}`)
  expect(await rowLabel(ui, L('atlas-ic-1'))).toBe('atlas-ic-1 · - · busy')
  const more = await moreLines(ui, L('atlas-ic-1'))
  expect(more).toHaveLength(1)
  expect(more[0]!.text).toMatch(/^STATE\.md unreadable: .*EFBIG/)
  expect(await rowLabel(ui, 'f')).toMatch(/^workflow board-check-v0 · /)

  // The file is written again, readable: the row comes back.
  files[path] = { ...files[path]!, fail: false, mtimeMs: files[path]!.mtimeMs + 1000 }
  await clock.advance(5000)
  expect(await rowLabel(ui, L('atlas-ic-1'))).toBe(`atlas-ic-1 · ${want('atlas-ic-1').rung} · busy`)
  await ui.unmount()
})

/** The head row's right side: "<HH:MM> · refreshed …". */
const refreshed = async (ui: any) => (await boxTexts(ui, 'head'))[1]

test('N3: "refreshed" shows the age of the last refresh that worked, and grows while refreshes fail', async ($, on) => {
  const { ui, clock, world } = await openFleet($, on, FILES)
  expect(await refreshed(ui)).toMatch(/^\d\d:\d\d · refreshed 0s ago$/)
  await clock.advance(3000)
  expect(await refreshed(ui)).toMatch(/ · refreshed 3s ago$/)

  // Every refresh from here fails: the age keeps growing and the problem shows.
  world.isEnvDown = true
  await clock.advance(9000)
  expect(await refreshed(ui)).toMatch(/ · refreshed 12s ago$/)
  expect((await ui.findAll({ type: 'Text' })).some((t: any) => t.props.color === 'error')).toBe(true)
  await clock.advance(48000)
  expect(await refreshed(ui)).toMatch(/ · refreshed 1m ago$/)

  // A refresh that works again: back to 0s, the problem gone.
  world.isEnvDown = false
  await clock.advance(5000)
  expect(await refreshed(ui)).toMatch(/ · refreshed [0-4]s ago$/)
  expect((await ui.findAll({ type: 'Text' })).some((t: any) => t.props.color === 'error')).toBe(false)
  await ui.unmount()
})

/** The module's hooks by event, and a stand-in `$` whose timers the test can see; HOME is unset, so a refresh reads nothing. */
function standIn(panes: { id: string }[]) {
  const hooks: Record<string, (...a: any[]) => any> = {}
  const fakeOn = (event: string, ...rest: unknown[]) => {
    hooks[event] = rest[rest.length - 1] as (...a: any[]) => any
    const handle = { catch: () => handle }
    return handle
  }
  register(fakeOn as any, {} as any)
  const timers: { ms: number; isCancelled: boolean }[] = []
  const store = new Map<string, { value: unknown; version: number }>()
  const keyOf = (ref: { plugin: string; key: string }) => `${ref.plugin}/${ref.key}`
  const $ = {
    command: { register: async () => ({ command: 'fleet' }) },
    clock: {
      now: async () => NOW,
      every: (ms: number) => {
        const t = { ms, isCancelled: false }
        timers.push(t)
        return { cancel: () => (t.isCancelled = true) }
      },
    },
    env: { get: async () => undefined },
    fs: { list: async () => [], read: async () => '' },
    state: {
      get: async (ref: any) => store.get(keyOf(ref)) ?? { value: undefined, version: 0 },
      set: async (ref: any, value: unknown) => {
        const version = (store.get(keyOf(ref))?.version ?? 0) + 1
        store.set(keyOf(ref), { value, version })
        return { isSet: true, version }
      },
    },
    ui: { open: async () => ({ isPlaced: true }), panes: async () => panes, scroll: async () => ({}) },
  }
  const live = () => timers.filter(t => !t.isCancelled).map(t => t.ms).sort((x, y) => x - y)
  return { hooks, $, timers, live }
}

test('N7: closing the board stops every timer; /fleet starts them again', async () => {
  const { hooks, $, timers, live } = standIn([])
  await hooks['command.run']!($, { command: 'fleet', args: '' }, async () => ({}))
  expect(live().length).toBeGreaterThan(0)
  expect(live()).toContain(5000)

  await hooks['ui.close']!($, { id: 'fleet', origin: 'person' }, async () => undefined)
  expect(live()).toEqual([])
  expect(timers.every(t => t.isCancelled)).toBe(true)

  await hooks['command.run']!($, { command: 'fleet', args: '' }, async () => ({}))
  expect(live()).toContain(5000)
  await hooks['ui.close']!($, { id: 'fleet', origin: 'person' }, async () => undefined)
})

test('N3: after a reload with the board still up, session.start starts the refresh again; with no board it starts none', async () => {
  const up = standIn([{ id: 'fleet' }])
  await up.hooks['session.start']!(up.$, { cwd: '/w', surface: 'terminal', isInteractive: true }, async () => ({}))
  expect(up.live()).toEqual([1000, 5000])
  await up.hooks['ui.close']!(up.$, { id: 'fleet', origin: 'person' }, async () => undefined)

  const down = standIn([])
  await down.hooks['session.start']!(down.$, { cwd: '/w', surface: 'terminal', isInteractive: true }, async () => ({}))
  expect(down.live()).toEqual([])
})

test('N8: the card\'s newest file skips STATE.md, and is only listed, never read', async ($, on) => {
  const { ui, trace } = await openFleet($, on, FILES)
  await ui.press({ key: L('atlas-ic-1') })
  expect(cardFields(await cardTexts(ui))['newest file']).toEqual([`${HOME}/.fleet-agent-mgmt/checks/atlas-ic-1/`, 'stop-2.md'])
  // An IC whose folder holds only STATE.md has no newest file.
  await ui.press({ key: L('apex-ic-1') })
  expect(cardFields(await cardTexts(ui))['newest file']).toEqual(['-'])
  expect(trace.reads.some(p => p.endsWith('/stop-2.md'))).toBe(false)
  await ui.unmount()
})

test('N3: a session that starts with the board up (a reload) refreshes it at once and every 5 s', async ($, on) => {
  const lists: string[] = []
  mock.env(on, { HOME })
  const clock = mock.clock(on, { now: NOW })
  on('fs.list', (_: unknown, e: { path: string }) => {
    lists.push(e.path)
    return { deny: 'ENOENT' }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'fleet' } }))
  on('ui.panes', () => ({ value: [{ id: 'fleet', title: 'fleet', isShown: true, isFocused: false, isPlaced: true }] }))
  await $.session.start({ cwd: '/w', surface: 'terminal', isInteractive: true })
  const first = lists.length
  expect(first).toBeGreaterThan(0)
  await clock.advance(5000)
  expect(lists.length).toBeGreaterThan(first)
})

const RECORDS = `${HOME}/.fleet-agent-mgmt/records`

test('C3 parse: the handoff line names a record folder only as <home>/.fleet-agent-mgmt/records/<project>/<folder>/', () => {
  const folder = { project: 'orbit', folder: 'orb-8-r1', path: `${RECORDS}/orbit/orb-8-r1` }
  // A path starting "~" and one starting with the home folder, with or without words after it.
  expect(recordFolderOf('~/.fleet-agent-mgmt/records/orbit/orb-8-r1/handoff.md', HOME)).toEqual(folder)
  expect(recordFolderOf(`${RECORDS}/orbit/orb-8-r1/handoff.md`, HOME)).toEqual(folder)
  expect(recordFolderOf(`  ${RECORDS}/orbit/orb-8-r1/handoff.md (lead-1 message 2026-10-21 12:12)`, HOME)).toEqual(folder)
  // The folder itself, written with its "/".
  expect(recordFolderOf(`${RECORDS}/orbit/orb-8-r1/`, HOME)).toEqual(folder)
  // Anything else is no record folder: a lead-1 handoff, a URL, ".", "-", words, no line, a folder too high or too
  // deep, a name with "..", another home.
  for (const line of [
    `${HOME}/fleet/lead-1/handoffs/apx-3-r1.md`,
    'https://github.com/example/repo/issues/11',
    '.',
    '-',
    'a note from lead-1 in its pane, 2026-10-02; nothing on disk',
    '',
    undefined,
    `${RECORDS}/orbit/handoff.md`,
    `${RECORDS}/orbit/orb-8-r1/sub/handoff.md`,
    `${RECORDS}/orbit/../../.ssh/id`,
    `${RECORDS}/../checks/x/handoff.md`,
    `${RECORDS}/.hidden/x/handoff.md`,
    '/Users/other/.fleet-agent-mgmt/records/orbit/orb-8-r1/handoff.md',
    '~other/.fleet-agent-mgmt/records/orbit/orb-8-r1/handoff.md',
  ]) {
    expect(recordFolderOf(line, HOME)).toBeUndefined()
  }
  expect(recordFolderOf('~/.fleet-agent-mgmt/records/orbit/x/handoff.md', '')).toBeUndefined()
})

test('C3 parse: close.md listed is done, a folder without it is not done, no folder or no listing is unknown', () => {
  const record = { project: 'orbit', folder: 'orb-8-r1', path: `${RECORDS}/orbit/orb-8-r1` }
  const at = new Date(2026, 9, 22, 10, 36, 3).getTime()
  expect(doneOf(record, [{ name: 'handoff.md', mtimeMs: 1 }, { name: 'close.md', mtimeMs: at }])).toEqual({
    kind: 'done',
    folder: 'orb-8-r1',
    closedAt: at,
  })
  // A listing that gives no time (a link lists as 0): done, with no time made up.
  expect(doneOf(record, [{ name: 'close.md', mtimeMs: 0 }])).toEqual({ kind: 'done', folder: 'orb-8-r1' })
  expect(doneOf(record, [{ name: 'handoff.md', mtimeMs: 1 }, { name: 'close-draft.md', mtimeMs: 1 }])).toEqual({
    kind: 'open',
    folder: 'orb-8-r1',
  })
  expect(doneOf(record, [])).toEqual({ kind: 'open', folder: 'orb-8-r1' })
  expect(doneOf(record, undefined)).toEqual({ kind: 'unknown' })
  expect(doneOf(undefined, [{ name: 'close.md', mtimeMs: at }])).toEqual({ kind: 'unknown' })

  expect(ymdhm(at)).toBe('2026-10-22 10:36')
  expect(doneLine({ kind: 'done', folder: 'atl-43-r1', closedAt: at })).toBe(
    '✔ DONE · atl-43-r1 closed 2026-10-22 10:36 · close report in the record',
  )
  expect(doneLine({ kind: 'done', folder: 'atl-43-r1' })).toBe('✔ DONE · atl-43-r1 closed · close report in the record')
  expect(doneLine({ kind: 'open', folder: 'atl-43-r1' })).toBe('● NOT DONE · atl-43-r1 open · no close report yet')
  expect(doneLine({ kind: 'unknown' })).toBe("? UNKNOWN · this rung predates record folders, so there's no close report")
  expect([doneGlyph({ kind: 'done', folder: 'x' }), doneGlyph({ kind: 'open', folder: 'x' }), doneGlyph({ kind: 'unknown' })]).toEqual([
    '✔',
    '●',
    '?',
  ])
  // icRow with no done given is unknown.
  expect(icRow('a', { name: 'x', status: 'idle', state: '' }).done).toEqual({ kind: 'unknown' })
})

/** An IC row's done glyph as drawn, with its colour; undefined for a row with none. */
async function glyph(ui: any, letter: string): Promise<{ text: string; color?: string } | undefined> {
  const box = await ui.find({ key: `done-${letter}` })
  const t = box?.children?.[0]
  return t ? { text: t.text ?? flat(t), color: t.props.color } : undefined
}

/** The open card's done line: the Text right under the title row. */
async function cardDone(ui: any): Promise<{ text: string; color?: string; wrap?: string }> {
  const card = await ui.find({ key: 'card' })
  const t = card.children[1]
  return { text: t.text ?? flat(t), color: t.props.color, wrap: t.props.wrap }
}

test('C3 pane: each IC row opens with ✔, ● or ? before its letter; workflow rows have none', async ($, on) => {
  const { ui, trace } = await openFleet($, on, FILES)
  expect(await glyph(ui, L('apex-ic-1'))).toEqual({ text: '?', color: 'warning' })
  expect(await glyph(ui, L('atlas-ic-1'))).toEqual({ text: '✔', color: 'success' })
  expect(await glyph(ui, L('atlas-ic-2'))).toEqual({ text: '✔', color: 'success' })
  expect(await glyph(ui, L('orbit-ic-1'))).toEqual({ text: '●', color: 'suggestion' })
  expect(await glyph(ui, L('orbit-ic-2'))).toEqual({ text: '●', color: 'suggestion' })
  expect(await glyph(ui, 'f')).toBeUndefined()

  // In each IC row the glyph sits after the "▌" mark and before the letter's Button; it takes 2 columns.
  for (const w of EXPECTED) {
    const row = await ui.find({ key: `row-${w.letter}` })
    expect(row.children[0]).toMatchObject({ type: 'Text' })
    expect(row.children[1]).toMatchObject({ type: 'Box', props: { width: 2, flexShrink: 0 } })
    expect(row.children[1].key ?? row.children[1].props.key).toBe(`done-${w.letter}`)
  }
  // The row's own line is as before: its Button's label is name · rung · status.
  for (const w of EXPECTED) expect(await rowLabel(ui, w.letter)).toBe(`${w.name} · ${w.rung} · ${w.status}`)

  // The selected-row mark still works, with the glyph after it.
  await ui.press({ key: L('atlas-ic-2') })
  const row = await ui.find({ key: `row-${L('atlas-ic-2')}` })
  expect(row.props.backgroundColor).toBe('#262E3A')
  expect(row.children[0]).toMatchObject({ type: 'Text', props: { color: 'warning' } })
  expect(flat(row.children[0])).toBe('▌')
  expect(await glyph(ui, L('atlas-ic-2'))).toEqual({ text: '✔', color: 'success' })

  // Record folders are listed, never read.
  expect(trace.lists).toContain(`${RECORDS}/atlas/atl-42-r1`)
  expect(trace.reads.some(p => p.startsWith(`${RECORDS}/`))).toBe(false)
  // apex-ic-1's handoff is under lead-1's handoffs, so no folder is listed for it.
  expect(trace.lists.some(p => p.includes('/fleet/lead-1/handoffs'))).toBe(false)
  await ui.unmount()
})

test('C3 card: the line under the title says done, not done or unknown, in green, blue or amber', async ($, on) => {
  const { ui } = await openFleet($, on, FILES)
  await ui.press({ key: L('atlas-ic-2') })
  expect(await cardDone(ui)).toEqual({ text: DONE_43, color: 'success', wrap: 'truncate-end' })
  // Under the title row and before "updated …".
  const lines = await cardTexts(ui)
  expect(lines.slice(0, 3)).toEqual([`${L('atlas-ic-2')} · atlas-ic-2`, DONE_43, 'updated 2026-10-21 14:46 BST · 2h09 ago'])

  await ui.press({ key: L('orbit-ic-1') })
  expect(await cardDone(ui)).toEqual({
    text: '● NOT DONE · orb-7-r2 open · no close report yet',
    color: 'suggestion',
    wrap: 'truncate-end',
  })
  await ui.press({ key: L('apex-ic-1') })
  expect(await cardDone(ui)).toEqual({
    text: "? UNKNOWN · this rung predates record folders, so there's no close report",
    color: 'warning',
    wrap: 'truncate-end',
  })
  // A workflow card has no done line.
  await ui.press({ key: 'f' })
  expect((await cardTexts(ui)).some(l => /DONE|UNKNOWN/.test(l))).toBe(false)
  await ui.unmount()
})

/** The fixture fleet with each named IC's "handoff:" line set to the given text. */
function withHandoff(lines: Record<string, string>): Files {
  const files: Files = JSON.parse(JSON.stringify(FILES))
  for (const [name, line] of Object.entries(lines)) {
    const f = files[`${HOME}/.fleet-agent-mgmt/checks/${name}/STATE.md`]!
    expect(/^handoff: .*$/m.test(f.text)).toBe(true)
    f.text = f.text.replace(/^handoff: .*$/m, `handoff: ${line}`)
  }
  return files
}

test('C3 pane: a handoff with ~, a URL, a folder that cannot be listed, a close.md with no time', async ($, on) => {
  const files = withHandoff({
    // "~" form, into a folder with close.md: done.
    'orbit-ic-1': '~/.fleet-agent-mgmt/records/atlas/atl-43-r1/handoff.md',
    // A URL: unknown.
    'atlas-ic-1': 'https://github.com/example/repo/issues/11',
    // A record folder that is not there: it cannot be listed, so unknown.
    'atlas-ic-2': `${RECORDS}/atlas/atl-99-r1/handoff.md`,
    // A path that climbs out of the records: unknown, and nothing outside is listed.
    'apex-ic-1': `${RECORDS}/orbit/../../checks/handoff.md`,
  })
  // A close.md that is a link lists with no time: done, with no time shown.
  files[`${RECORDS}/orbit/orb-8-r1/close.md`] = { text: '', mtimeMs: 0, kind: 'other' }
  const { ui, trace, clock } = await openFleet($, on, files)

  expect(await glyph(ui, L('orbit-ic-1'))).toEqual({ text: '✔', color: 'success' })
  expect(await glyph(ui, L('atlas-ic-1'))).toEqual({ text: '?', color: 'warning' })
  expect(await glyph(ui, L('atlas-ic-2'))).toEqual({ text: '?', color: 'warning' })
  expect(await glyph(ui, L('apex-ic-1'))).toEqual({ text: '?', color: 'warning' })
  expect(await glyph(ui, L('orbit-ic-2'))).toEqual({ text: '✔', color: 'success' })
  await ui.press({ key: L('orbit-ic-2') })
  expect((await cardDone(ui)).text).toBe('✔ DONE · orb-8-r1 closed · close report in the record')
  await ui.press({ key: L('orbit-ic-1') })
  expect((await cardDone(ui)).text).toBe(DONE_43)
  expect(trace.lists).toContain(`${RECORDS}/atlas/atl-99-r1`)
  expect(trace.lists.some(p => p.includes('..'))).toBe(false)

  // The rung closes: close.md appears in orb-7-r2... and on the next refresh the row turns done.
  const f = files[`${HOME}/.fleet-agent-mgmt/checks/orbit-ic-1/STATE.md`]!
  f.text = f.text.replace(/^handoff: .*$/m, `handoff: ${RECORDS}/orbit/orb-7-r2/handoff.md`)
  f.mtimeMs += 1000
  await clock.advance(5000)
  expect(await glyph(ui, L('orbit-ic-1'))).toEqual({ text: '●', color: 'suggestion' })
  files[`${RECORDS}/orbit/orb-7-r2/close.md`] = { text: '', mtimeMs: Date.parse('2026-10-21T16:50:00+01:00') }
  await clock.advance(5000)
  expect(await glyph(ui, L('orbit-ic-1'))).toEqual({ text: '✔', color: 'success' })
  expect((await cardDone(ui)).text).toBe(closedLine('orb-7-r2', '2026-10-21T16:50:00+01:00'))
  expect(trace.reads.some(p => p.startsWith(`${RECORDS}/`))).toBe(false)
  await ui.unmount()
})

test('C3 pane: a record folder that is there but empty is not done; one that is not there is unknown', async ($, on) => {
  const files = withHandoff({
    'orbit-ic-1': `${RECORDS}/orbit/empty-r1/handoff.md`,
    'atlas-ic-2': `${RECORDS}/orbit/missing-r1/handoff.md`,
  })
  files[`${RECORDS}/orbit/empty-r1/`] = { text: '', mtimeMs: 0 }
  const { ui, trace } = await openFleet($, on, files)
  expect(await glyph(ui, L('orbit-ic-1'))).toEqual({ text: '●', color: 'suggestion' })
  expect(await glyph(ui, L('atlas-ic-2'))).toEqual({ text: '?', color: 'warning' })
  await ui.press({ key: L('orbit-ic-1') })
  expect(await cardDone(ui)).toEqual({
    text: '● NOT DONE · empty-r1 open · no close report yet',
    color: 'suggestion',
    wrap: 'truncate-end',
  })
  expect(trace.lists).toContain(`${RECORDS}/orbit/empty-r1`)
  expect(trace.lists).toContain(`${RECORDS}/orbit/missing-r1`)
  expect(trace.reads.some(p => p.startsWith(`${RECORDS}/`))).toBe(false)
  await ui.unmount()
})

test('C3 layout: the card line is cut with "…" at narrow widths, never wrapped; rows still fit with the glyph', async ($, on) => {
  const first = await openFleet($, on, FILES, 'terminal', 54)
  for (const columns of [54, 60, 81]) {
    const ui = columns === 54 ? first.ui : await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: columns } })
    for (const name of ['atlas-ic-1', 'orbit-ic-2', 'apex-ic-1']) {
      await ui.press({ key: L(name) })
      const line = await cardDone(ui)
      // The card's border and padding take 4 columns.
      expect(Array.from(line.text).length).toBeLessThanOrEqual(columns - 4)
      expect(line.text.includes('\n')).toBe(false)
      expect(line.wrap).toBe('truncate-end')
    }
    // The longest one, the unknown line (73 characters), is cut at 54 and 60.
    await ui.press({ key: L('apex-ic-1') })
    if (columns < 77) expect((await cardDone(ui)).text.endsWith('…')).toBe(true)
    else expect((await cardDone(ui)).text).toBe("? UNKNOWN · this rung predates record folders, so there's no close report")
    await ui.press({ key: 'close-card' })
    await ui.unmount()
  }

  // At 86 body columns the "▌" mark and the 2-column glyph leave 83 for the row line, the second lines 80.
  const ui = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 86 } })
  for (const w of EXPECTED) {
    expect(Array.from(await buttonLine(ui, w.letter)).length).toBeLessThanOrEqual(83)
    expect(await boxTexts(ui, `more-${w.letter}`)).toHaveLength(1)
    for (const line of await boxTexts(ui, `more-${w.letter}`)) expect(Array.from(line).length).toBeLessThanOrEqual(80)
  }
  await ui.unmount()
})

// The render regression. fixtures/invented/baseline/ holds the board as it was drawn before decision cards existed:
// at 180, 120, 81 and 54 columns, with no card open and with each letter's card open. With no card file present the
// board must draw every one of them again, byte for byte. A snapshot missing from the baseline is printed between
// @@BEGIN and @@END and fails the test, so a new one is written from what the test drew, never by hand.
test('render regression: with no card files, every baseline snapshot is drawn again byte for byte', async ($, on) => {
  const missing: string[] = []
  const differ: string[] = []
  const check = async (ui: any, cols: number, state: string) => {
    const name = `render-${cols}-${state}`
    const got = snapshot(await ui.drawn(), cols, state)
    if (!(name in BASELINE)) {
      missing.push(name)
      console.log(`@@BEGIN ${name}\n${got}@@END`)
    } else if (got !== BASELINE[name]) {
      differ.push(name)
      console.log(`@@DIFF ${name}\n${got}@@END`)
    }
  }
  const first = await openFleet($, on, FILES, 'terminal', WIDTHS[0])
  await first.clock.advance(3000)
  for (const cols of WIDTHS) {
    const ui = cols === WIDTHS[0] ? first.ui : await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: cols } })
    await check(ui, cols, 'nocard')
    const letters = (await ui.findAll({ type: 'Button' })).map((n: any) => String(n.props.hotkey)).filter((k: string) => k !== '0')
    for (const letter of letters) {
      await ui.press({ key: letter })
      await check(ui, cols, `card-${letter}`)
    }
    await ui.press({ key: 'close-card' })
    await ui.unmount()
  }
  expect(Object.keys(BASELINE).filter(k => k.startsWith('render-')).length).toBe(28)
  expect(missing).toEqual([])
  expect(differ).toEqual([])
})

// C4: decision cards. lead-1 writes each card it sends the owner to checks/lead-1/cards/<slug>.md (shared/ledger/card-add.sh);
// the board reads them. Every card file here is invented (test/fixtures/invented/cards/).

const CARDS_DIR = `${HOME}/.fleet-agent-mgmt/checks/lead-1/cards`
const cardFile = (name: string) => CARD_FILES[`${CARDS_DIR}/${name}`]!
/** The fixture fleet with these card files beside it. */
const withCards = (...names: string[]): Files => {
  const files: Files = { ...FILES }
  for (const name of names) files[`${CARDS_DIR}/${name}`] = cardFile(name)
  return files
}
/** The same card file with its status (and answer) changed. */
const restatus = (name: string, status: string, answer = '-') => ({
  ...cardFile(name),
  text: cardFile(name).text.replace(/^status: .*$/m, `status: ${status}`).replace(/^answer: .*$/m, `answer: ${answer}`),
})
/** The Text nodes under the Box with this key, in drawing order. */
async function textNodes(ui: any, key: string): Promise<any[]> {
  const out: any[] = []
  const walk = (n: any) => {
    if (!n || typeof n !== 'object') return
    if (n.type === 'Text') return void out.push(n)
    for (const c of n.children ?? []) walk(c)
  }
  walk(await ui.find({ key }))
  return out
}
const RULE = '─'.repeat(120 - 4)

test('C4 parse: a card file gives its header and body; a file that is not a card gives nothing', () => {
  const card = parseCard(cardFile('ATL-42-D6.md').text, 'ATL-42-D6.md', 1)
  expect(card).toMatchObject({
    file: 'ATL-42-D6.md',
    mtimeMs: 1,
    id: 'ATL-42 D6',
    row: 'atlas-ic-1',
    status: 'open',
    since: '2026-10-21 15:46 BST',
    sinceAt: Date.parse('2026-10-21T15:46:00+01:00'),
    where: 'atlas-ic-1',
    reply: 'ATL-42 D6 a | ATL-42 D6 back: <line>',
    answer: '-',
  })
  expect(card!.body.startsWith('atlas · ATL-42 D6, ship the retry with a limit of three or wait for the vendor · lead-1 ·')).toBe(true)
  expect(card!.body.endsWith('Reply ATL-42 D6 a, or ATL-42 D6 back: <line>.')).toBe(true)
  expect(parseCard(cardFile('ATL-43-D2.md').text, 'x', 0)).toMatchObject({ status: 'answered', answer: 'a, go ahead · 14:52' })
  expect(parseCard(cardFile('board-check-D1.md').text, 'x', 0)?.id).toBe('board check D1')
  // Not a card: no "---", a key missing, another status, a row that is a path, an empty body.
  const good = cardFile('fleet-G2.md').text
  expect(parseCard(cardFile('broken.md').text, 'broken.md', 0)).toBeUndefined()
  expect(parseCard(good.replace(/^reply: .*\n/m, ''), 'x', 0)).toBeUndefined()
  expect(parseCard(good.replace(/^where: .*\n/m, ''), 'x', 0)).toBeUndefined()
  expect(parseCard(good.replace('status: open', 'status: closed'), 'x', 0)).toBeUndefined()
  expect(parseCard(good.replace('row: lead-1', 'row: ../lead-1'), 'x', 0)).toBeUndefined()
  expect(parseCard(good.slice(0, good.indexOf('---') + 4), 'x', 0)).toBeUndefined()
  expect(parseCard('', 'x', 0)).toBeUndefined()
  // Windows line ends read the same.
  expect(parseCard(good.replace(/\n/g, '\r\n'), 'x', 0)).toMatchObject({ id: 'fleet G2', row: 'lead-1' })
  // A row's open cards, newest first; its last answered one by file time; another row's are not its own.
  const all = Object.entries(CARD_FILES)
    .map(([path, f]) => parseCard(f.text, path.split('/').pop()!, f.mtimeMs))
    .filter(c => c !== undefined)
  expect(cardsOf(all, 'orbit-ic-1').open.map(c => c.id)).toEqual(['ORB-7 N4', 'ORB-7 N3'])
  expect(cardsOf(all, 'atlas-ic-2')).toMatchObject({ open: [], lastAnswered: { id: 'ATL-43 D2' } })
  expect(cardsOf(all, 'apex-ic-1')).toEqual({ open: [] })
  expect(sinceShort('2026-10-21 15:46 BST', NOW)).toBe('15:46')
  expect(sinceShort('2026-10-20 09:15 BST', NOW)).toBe('2026-10-20 09:15')
})

test('C4 parse: a card body is cut into labelled parts; the reply part is left out', () => {
  const prose = cardParts(parseCard(cardFile('ATL-42-D6.md').text, 'x', 0)!.body)
  // One word per label: the frame line is "about", "Recommendation:" is "rec", the option list is "options".
  expect(prose.map(p => p.label)).toEqual(['about', 'problem', 'state', 'options', 'rec'])
  expect(prose[1]!.lines[0]!.text.startsWith('the vendor has not said how many calls')).toBe(true)
  expect(prose[3]!.lines.map(l => [l.indent, l.text])).toEqual([
    [0, 'a) ship with a limit of three tries, and ask the vendor for its limit at the same time'],
    [3, 'the import may still be blocked on a bad night'],
    [0, 'b) hold the push until the vendor answers'],
    [3, 'no date for that answer'],
  ])
  // The decision-card skill's shape: "**label**" fields, continuation lines kept with their indent, "**" dropped,
  // and the frame line's "?" glyph left out (every open card would carry it).
  const skill = cardParts(parseCard(cardFile('ORB-7-N3.md').text, 'x', 0)!.body)
  expect(skill.map(p => p.label)).toEqual(['about', 'problem', 'options', 'rec'])
  expect(skill[0]!.lines[0]!.text).toBe('ORB-7 N3 · orbit · orbit-ic-1 · how the export writes dates · 2026-10-22')
  expect(skill[1]!.lines).toEqual([
    { indent: 0, text: 'the two sample files write the same date two ways' },
    { indent: 0, text: 'e.g. "2026-10-21" in one, "21/10/2026" in the other' },
  ])
  expect(skill[2]!.lines.map(l => l.indent)).toEqual([0, 3, 0, 3])
  // A failed gate's glyph is kept: it says something the card's place does not.
  expect(cardParts('✖ **ATL-61 D2** · atlas · the build is red')[0]).toEqual({
    label: 'about',
    lines: [{ indent: 0, text: '✖ ATL-61 D2 · atlas · the build is red' }],
  })
  // Every character of a line is kept: the parts give back the body's words, less the reply and the "**".
  const words = (t: string) => t.replace(/\*\*/g, '').split(/\s+/).filter(Boolean)
  const body = parseCard(cardFile('ATL-42-D6.md').text, 'x', 0)!.body
  const kept = prose.flatMap(p => p.lines.map(l => l.text)).join(' ')
  expect(words(kept)).toEqual(words(body.slice(0, body.indexOf('Reply ')).replace('The problem:', '').replace('Status:', '').replace('Recommendation:', '')))
})

test('C4 parse: "Reply" or "<Label>:" inside a paragraph stays in it; a fence keeps its lines and blank lines as written', () => {
  const body = [
    'The problem: the nightly run writes its log to a folder nobody reads.',
    'Reply rates from the team are low, so a failure goes unseen for days.',
    'Note: this line is part of the problem too.',
    '',
    '```',
    'Status: not a label inside a fence',
    '',
    '**rec** not a label either',
    'Reply not a reply',
    '```',
    '',
    'Reply ATL-9 a.',
  ].join('\n')
  const parts = cardParts(body)
  expect(parts.map(p => p.label)).toEqual(['problem', ''])
  expect(parts[0]!.lines.map(l => l.text)).toEqual([
    'the nightly run writes its log to a folder nobody reads.',
    'Reply rates from the team are low, so a failure goes unseen for days.',
    'Note: this line is part of the problem too.',
  ])
  expect(parts[1]!.lines.map(l => l.text)).toEqual([
    '```',
    'Status: not a label inside a fence',
    '',
    'rec not a label either',
    'Reply not a reply',
    '```',
  ])
  // A label that opens a paragraph still opens a part; a second options paragraph sits under no label.
  const two = cardParts('about the card\n\na) one\nb) two\n\nc) three\n\nStatus: open')
  expect(two.map(p => p.label)).toEqual(['about', 'options', '', 'state'])
  expect(optionParts('a) keep it')).toEqual(['a) ', 'keep it'])
  expect(optionParts('apart) no')).toBeUndefined()
})

test('C4 pane: an open card makes its row wait on you, with its age and how many cards', async ($, on) => {
  const { ui } = await openFleet($, on, withCards('ATL-42-D6.md'))
  const b = L('atlas-ic-1')
  expect(await boxTexts(ui, `more-${b}`)).toEqual(['waiting on you: ATL-42 D6 · 1h09 · 1 card'])
  expect((await textNodes(ui, `more-${b}`))[0]!.props.color).toBe('warning')
  expect(await texts(ui)).toContain('5 IC (1 busy) · 1 wait on you, oldest 1h09 (atlas-ic-1) · 1 workflow running')
  // No row moves: the letters are the fixture's, and lead-1 has no row (it has no open card of its own).
  for (const w of EXPECTED) expect(await rowLabel(ui, w.letter)).toBe(`${w.name} · ${w.rung} · ${w.status}`)
  expect(await ui.find({ key: 'g' })).toBeUndefined()
  // Every other row's second line is as it was.
  for (const w of EXPECTED.filter(w => w.name !== 'atlas-ic-1'))
    expect((await boxTexts(ui, `more-${w.letter}`))[0]!.startsWith(`awaiting: ${w.needs_you.slice(0, 40)}`)).toBe(true)
  await ui.unmount()
})

test('C4 card: the decision card comes first, then a rule, then the STATE.md card exactly as before', async ($, on) => {
  // The same board before and after the card file is written: the next refresh picks it up.
  const files = withCards()
  const { ui, trace, clock } = await openFleet($, on, files)
  const b = L('atlas-ic-1')
  await ui.press({ key: b })
  const plain = await cardTexts(ui)
  files[`${CARDS_DIR}/ATL-42-D6.md`] = cardFile('ATL-42-D6.md')
  await clock.advance(5000)
  const lines = await cardTexts(ui)
  expect(lines[0]).toBe(`${b} · last card · ATL-42 D6 · waiting on you since 15:46`)
  const at = (t: string) => lines.indexOf(t)
  expect(at('about')).toBeGreaterThan(0)
  expect(lines[at('about') + 1]).toBe(
    'atlas · ATL-42 D6, ship the retry with a limit of three or wait for the vendor · lead-1 · decision 1 of 1, answering "Is ATL-42 ready to ship?"',
  )
  expect(at('about') < at('problem') && at('problem') < at('state') && at('state') < at('options') && at('options') < at('rec')).toBe(true)
  // An option's letter is drawn apart from its text, so its wrapped lines hang under the text.
  expect(lines.slice(at('options') + 1, at('rec'))).toEqual([
    'a)',
    'ship with a limit of three tries, and ask the vendor for its limit at the same time',
    'the import may still be blocked on a bad night',
    'b)',
    'hold the push until the vendor answers',
    'no date for that answer',
  ])
  expect(at("you type, in atlas-ic-1's pane")).toBeGreaterThan(at('rec'))
  expect(lines.slice(at("you type, in atlas-ic-1's pane") + 1, at(RULE))).toEqual(['ATL-42 D6 a', 'ATL-42 D6 back: <line>'])
  // The reply paragraph is carried by the reply line, never drawn twice.
  expect(lines.some(l => l.startsWith('Reply '))).toBe(false)
  // After the rule, the STATE.md card as it is drawn with no card file, line for line.
  expect(lines.slice(at(RULE) + 1)).toEqual(plain)
  // One close key, on the first title row.
  expect((await ui.findAll({ type: 'Button' })).filter((n: any) => n.props.hotkey === '0')).toHaveLength(1)
  await ui.press({ key: 'close-card' })
  expect(await ui.find({ key: 'card' })).toBeUndefined()
  expect(trace.runs).toEqual([])
  await ui.unmount()
})

test('C4 card: two open cards on one row show in full, newest first', async ($, on) => {
  const { ui } = await openFleet($, on, withCards('ORB-7-N3.md', 'ORB-7-N4.md'))
  const d = L('orbit-ic-1')
  expect(await boxTexts(ui, `more-${d}`)).toEqual(['waiting on you: ORB-7 N4, ORB-7 N3 · 45m · 2 cards'])
  await ui.press({ key: d })
  const lines = await cardTexts(ui)
  const first = lines.indexOf(`${d} · card 1 of 2 · ORB-7 N4 · waiting on you since 16:31`)
  const second = lines.indexOf(`${d} · card 2 of 2 · ORB-7 N3 · waiting on you since 16:10`)
  expect(first).toBe(0)
  expect(second).toBeGreaterThan(first)
  // A rule between the two cards and one before the STATE.md card.
  expect(lines.filter(l => l === RULE)).toHaveLength(2)
  expect(lines.indexOf(RULE)).toBeLessThan(second)
  // Each in full: the second card's options keep their consequence lines.
  expect(lines.slice(second)).toContain('the survey owners read it as they write it')
  expect(lines.slice(second)).toContain('ORB-7 N3 b')
  await ui.unmount()
})

/** The board as the layout test kit draws it at `cols` body columns: one string per row, the card's side borders
 * drawn as spaces (so a column number is the same inside the card and out), right edge trimmed. */
const drawnLines = async (ui: any, cols: number) =>
  snapshot(await ui.drawn(), cols, 'x')
    .split('\n')
    .filter(l => l.startsWith('|'))
    .map(l => l.slice(1, -1).replace(/^│/, ' ').replace(/│(\s*)$/, '').replace(/\s+$/, ''))

test('C4 layout: an option wraps under its text, not under its letter; the title never breaks inside a phrase', async ($, on) => {
  const { ui } = await openFleet($, on, withCards('ATL-42-D6.md', 'ORB-7-N3.md', 'ORB-7-N4.md'), 'terminal', 54)
  await ui.press({ key: L('atlas-ic-1') })
  const lines = await drawnLines(ui, 54)
  const a = lines.findIndex(l => l.includes('a) ship with a limit'))
  expect(a).toBeGreaterThan(0)
  // The wrapped line of option a starts where its text starts, 3 in from the "a)".
  const textAt = lines[a]!.indexOf('ship')
  expect(lines[a + 1]!.search(/\S/)).toBe(textAt)
  expect(lines[a]!.indexOf('a)')).toBe(textAt - 3)
  // Too narrow for the title and the close key: "waiting on you since" moves to its own line, whole.
  const b = L('atlas-ic-1')
  const title = lines.findIndex(l => l.includes(`${b} · last card · ATL-42 D6`))
  expect(lines[title]).toMatch(/0: close card$/)
  expect(lines[title + 1]!.trim()).toBe('waiting on you since 15:46')
  // Wide enough, it stays one line.
  await ui.unmount()
  const wide = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 120 } })
  await wide.press({ key: b })
  const one = (await drawnLines(wide, 120)).filter(l => l.includes(`${b} · last card · ATL-42 D6 · waiting on you since 15:46`))
  expect(one).toHaveLength(1)
  expect(one[0]).toMatch(/0: close card$/)
  await wide.unmount()
})

test('C4 layout: the cards of one row share one label column and one place for the reply', async ($, on) => {
  // ORB-7 N4 without its problem paragraph: alone, its longest label would be "about" or "state".
  const files = withCards('ORB-7-N3.md')
  files[`${CARDS_DIR}/ORB-7-N4.md`] = {
    ...cardFile('ORB-7-N4.md'),
    text: cardFile('ORB-7-N4.md').text.replace(/^The problem: .*\n\n/m, ''),
  }
  const { ui } = await openFleet($, on, files, 'terminal', 54)
  const d = L('orbit-ic-1')
  await ui.press({ key: d })
  const lines = await drawnLines(ui, 54)
  const textColumn = (label: string, from: number) => {
    const i = lines.findIndex((l, n) => n >= from && l.trimStart().startsWith(`${label} `))
    return lines[i]!.length - lines[i]!.slice(lines[i]!.indexOf(label) + label.length).trimStart().length
  }
  const second = lines.findIndex(l => l.includes('card 2 of 2'))
  expect(textColumn('about', 0)).toBe(textColumn('about', second))
  expect(textColumn('state', 0)).toBe(textColumn('options', second))
  // ORB-7 N4's reply does not fit beside "you type, …" at 54 columns, so neither card's does.
  const you = lines.map((l, i) => [l.trim(), i] as const).filter(([l]) => l.startsWith("you type, in orbit-ic-1's pane"))
  expect(you).toHaveLength(2)
  for (const [l, i] of you) {
    expect(l).toBe("you type, in orbit-ic-1's pane")
    expect(lines[i + 1]!.trim().startsWith('ORB-7 N')).toBe(true)
  }
  await ui.unmount()
})

test('C4 header: lead-1 is named, never counted as an IC; the counts line fits the pane', async ($, on) => {
  const { ui } = await openFleet($, on, withCards('ATL-42-D6.md', 'ORB-7-N3.md', 'fleet-G2.md'), 'terminal', 81)
  const head = '5 IC (1 busy) · 2 IC and lead-1 wait on you'
  expect(headerParts([], NOW).wait).toBe('0 wait on you')
  // Too wide for 81 columns with its "oldest" part: drawn without it, on one line.
  const lines = await drawnLines(ui, 81)
  expect(lines).toContain(`${head} · 1 workflow running`)
  await ui.unmount()
  const wide = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: 120 } })
  expect(await texts(wide)).toContain(`${head}, oldest 1h09 (atlas-ic-1) · 1 workflow running`)
  await wide.unmount()
})

test('C4 lead-1 row: drawn last, only while lead-1 has an open card of its own', async ($, on) => {
  const files = withCards('fleet-G2.md')
  const { ui, clock } = await openFleet($, on, files)
  for (const w of EXPECTED) expect(await rowLabel(ui, w.letter)).toBe(`${w.name} · ${w.rung} · ${w.status}`)
  expect(await rowLabel(ui, 'g')).toBe('lead-1 · lead session · busy')
  expect(await boxTexts(ui, 'more-g')).toEqual(['waiting on you: fleet G2 · 5m · 1 card'])
  expect(await legend(ui)).toBe('a–g open a card · Esc back to your prompt · other keys go to your prompt · ctrl+x x closes the board')
  // lead-1 is named beside the IC count, never counted as an IC.
  expect(await texts(ui)).toContain('5 IC (1 busy) · lead-1 waits on you, oldest 5m (lead-1) · 1 workflow running')
  await ui.press({ key: 'g' })
  const lines = await cardTexts(ui)
  expect(lines[0]).toBe('g · last card · fleet G2 · waiting on you since 16:50')
  expect(lines).toContain("you type, in lead-1's pane")
  // lead-1 has no STATE.md card: no rule, no stop or next.
  expect(lines).not.toContain(RULE)
  expect(lines).not.toContain('stop')

  // Answered, the row goes, and its card with it.
  files[`${CARDS_DIR}/fleet-G2.md`] = { ...restatus('fleet-G2.md', 'answered', 'a · 16:52'), mtimeMs: NOW + 1000 }
  await clock.advance(5000)
  expect(await ui.find({ key: 'g' })).toBeUndefined()
  expect(await ui.find({ key: 'card' })).toBeUndefined()
  expect(await texts(ui)).toContain('5 IC (1 busy) · 0 wait on you · 1 workflow running')
  await ui.unmount()
})

test('C4 answered: never on a row; the card ends with the last answered card as one line, only with none open', async ($, on) => {
  const files = withCards()
  const { ui, clock } = await openFleet($, on, files)
  const c = L('atlas-ic-2')
  const row = await boxTexts(ui, `more-${c}`)
  await ui.press({ key: c })
  const plain = await cardTexts(ui)

  files[`${CARDS_DIR}/ATL-43-D2.md`] = cardFile('ATL-43-D2.md')
  await clock.advance(5000)
  expect(await texts(ui)).toContain('5 IC (1 busy) · 0 wait on you · 1 workflow running')
  expect(await cardTexts(ui)).toEqual([...plain, 'last answered: ATL-43 D2 · a, go ahead · 14:52'])
  await ui.press({ key: 'close-card' })
  expect(await boxTexts(ui, `more-${c}`)).toEqual(row)

  // With a card open on the same row, the answered one is not shown.
  files[`${CARDS_DIR}/ATL-43-D3.md`] = {
    text: cardFile('ATL-43-D2.md').text.replace(/ATL-43 D2/g, 'ATL-43 D3').replace('status: answered', 'status: open').replace(/^answer: .*$/m, 'answer: -'),
    mtimeMs: NOW - 60_000,
  }
  await clock.advance(5000)
  await ui.press({ key: c })
  const lines = await cardTexts(ui)
  expect(lines[0]).toBe(`${c} · last card · ATL-43 D3 · waiting on you since 14:30`)
  expect(lines.some(l => l.startsWith('last answered:'))).toBe(false)
  await ui.unmount()
})

test('C4: a file that is not a card is left out; an id with spaces; a name starting "." is never listed as a card', async ($, on) => {
  const files = withCards('broken.md', 'board-check-D1.md')
  files[`${CARDS_DIR}/.ATL-42-D6.md`] = cardFile('ATL-42-D6.md')
  files[`${CARDS_DIR}/notes.txt`] = cardFile('ATL-42-D6.md')
  const { ui, trace } = await openFleet($, on, files)
  const b = L('atlas-ic-1')
  const e = L('orbit-ic-2')
  // broken.md and the dot file are about atlas-ic-1: its row is as it was.
  expect((await boxTexts(ui, `more-${b}`))[0]!.startsWith('awaiting: ATL-42 D4 ')).toBe(true)
  expect(await boxTexts(ui, `more-${e}`)).toEqual(['waiting on you: board check D1 · 1d · 1 card'])
  await ui.press({ key: e })
  expect((await cardTexts(ui))[0]).toBe(`${e} · last card · board check D1 · waiting on you since 2026-10-20 09:15`)
  expect(trace.reads.some(p => p.endsWith('/.ATL-42-D6.md') || p.endsWith('/notes.txt'))).toBe(false)
  // Reads stay in scope: session files, STATE.md, workflow journals, and lead-1's card files.
  for (const path of trace.reads)
    expect(path).toMatch(/(\/\.claude\/sessions\/\d+\.json|\/STATE\.md|\/subagents\/workflows\/wf_[^/]+\/journal\.jsonl|\/\.fleet-agent-mgmt\/checks\/lead-1\/cards\/[^./][^/]*\.md)$/)
  expect(trace.reads.filter(p => p.startsWith(CARDS_DIR)).sort()).toEqual([`${CARDS_DIR}/board-check-D1.md`, `${CARDS_DIR}/broken.md`])
  expect(trace.runs).toEqual([])
  await ui.unmount()
})

test('C4 newest file: a name starting "." beside STATE.md is never the newest file', async ($, on) => {
  const checks = `${HOME}/.fleet-agent-mgmt/checks`
  const files: Files = {
    ...FILES,
    [`${checks}/atlas-ic-1/.last-prompt`]: { text: '', mtimeMs: NOW },
    [`${checks}/apex-ic-1/.last-prompt`]: { text: '', mtimeMs: NOW },
  }
  const { ui, trace } = await openFleet($, on, files)
  await ui.press({ key: L('atlas-ic-1') })
  expect(cardFields(await cardTexts(ui))['newest file']).toEqual([`${checks}/atlas-ic-1/`, 'stop-2.md'])
  await ui.press({ key: L('apex-ic-1') })
  expect(cardFields(await cardTexts(ui))['newest file']).toEqual(['-'])
  expect(trace.reads.some(p => p.endsWith('/.last-prompt'))).toBe(false)
  await ui.unmount()
})

// Card width: shared/ledger/card-add.sh refuses a body line wider than the cap in shared/launch/card-width.txt. The cap is the
// room a body line has beside the label column at a 160-column terminal: dockColumns(160) = 72, less the engine's
// dock grip (1: the engine adds it to the width /fleet asks for, clamps the whole dock at dockColumns and gives the
// pane the dock less the grip), the card's frame (4) and a label column of "unverified" (10, the longest label
// card-add.sh takes) and its gap (3). These lead-1 cards are invented; every line is inside the cap, as card-add.sh
// would take them.

const CAP = 54
const GRIP = 1
const TERMINALS = [160, 186, 200] as const
/** A line's width as card-add.sh counts it: "**" is not drawn; every character here is one column. */
const lineCols = (s: string) => Array.from(s.replace(/\*\*/g, '')).length
const leadCard = (id: string, since: string, body: string) => ({
  text: `id: ${id}\nrow: lead-1\nstatus: open\nsince: 2026-10-21 ${since} BST\nwhere: lead-1\nreply: ${id} a | ${id} b\nanswer: -\n---\n${body}\n`,
  mtimeMs: NOW - 10 * 60_000,
})
const DIAGRAM = [
  '┌────────────┐     ┌────────────┐     ┌──────────────┐',
  '│ import job │────▶│ retry queue│────▶│ vendor api   │',
  '└────────────┘     └────────────┘     └──────────────┘',
]
const TABLE = [
  'IMPORT      ROWS     LAST RUN   TOOK   OWNER',
  'orders      41000    01:58      12m    data team',
  'refunds      3200    02:11       4m    finance and ops',
]
const WIDTH_CARDS: Record<string, string> = {
  'atlas-D7.md': [
    'fleet · atlas D7, where the retry waits · lead-1',
    '',
    '**problem**     the retry and the import share one queue',
    '',
    '```',
    ...DIAGRAM,
    '```',
    '',
    "**unverified**  the queue limit is from the vendor's page",
  ].join('\n'),
  'atlas-D8.md': [
    'fleet · atlas D8, which import runs first · lead-1',
    '',
    '**problem**     two imports want the 02:00 slot',
    '',
    '```',
    ...TABLE,
    '```',
    '',
    '**rec**         orders first, it feeds the refunds join',
  ].join('\n'),
  'atlas-D9.md': [
    'fleet · atlas D9, how long the retry waits · lead-1',
    '',
    '**problem**     the retry waits a fixed ten seconds, so',
    '            on a slow night every job retries at once',
    '            and the vendor sees a burst of calls, not',
    '            a spread; last night that was 312 calls in',
    '            one second, and 40 of them were refused by',
    '            the vendor with a "too many calls" answer',
    '',
    '**options**     a) wait a random time, 5 to 20 seconds',
    '               calls spread out, a job may end later',
    '            b) keep ten seconds, lower the retry limit',
    '               fewer calls, more jobs end in a failure',
    '',
    '**rec**         a, it spreads calls, fails no more jobs',
  ].join('\n'),
}
const SINCE: Record<string, string> = { 'atlas-D7.md': '16:40', 'atlas-D8.md': '16:41', 'atlas-D9.md': '16:42' }
const widthFiles = (cards: Record<string, string>): Files => {
  const files: Files = { ...FILES }
  for (const [name, body] of Object.entries(cards))
    files[`${CARDS_DIR}/${name}`] = leadCard(name.slice(0, -3).replace('-', ' '), SINCE[name] ?? '16:43', body)
  return files
}

test('card width: the cap is what the mod leaves a body line at a 160-column terminal', () => {
  expect(parse.dockColumns(160) - GRIP - 4 - ('unverified'.length + 3)).toBe(CAP)
  // The examples are ones card-add.sh takes; the diagram is exactly at the cap.
  for (const body of Object.values(WIDTH_CARDS)) for (const line of body.split('\n')) expect(lineCols(line)).toBeLessThanOrEqual(CAP)
  for (const line of DIAGRAM) expect(lineCols(line)).toBe(CAP)
  expect(Math.max(...Object.values(WIDTH_CARDS).flatMap(b => b.split('\n').map(lineCols)))).toBe(CAP)
})

test('card width: at 160, 186 and 200 columns every line of three lead-1 cards is drawn whole', async ($, on) => {
  const { ui, trace } = await openFleet($, on, widthFiles(WIDTH_CARDS))
  await ui.unmount()
  for (const terminal of TERMINALS) {
    // /fleet typed in this terminal asks for the dock the engine gives; the pane is mounted as wide as the engine
    // draws it, the dock less its grip.
    await $.command.run({ command: 'fleet', args: '', presentation: { isFullscreen: true, columns: terminal } } as any)
    const asked = trace.opens[trace.opens.length - 1]!.columns as number
    expect(asked).toBe(parse.dockColumns(terminal))
    const cols = asked - GRIP
    const pane = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: cols } })
    await pane.press({ key: 'g' })
    const lines = await drawnLines(pane, cols)
    expect(lines.filter(l => /g · card \d of 3 · atlas D[789]\b/.test(l))).toHaveLength(3)
    for (const line of [...DIAGRAM, ...TABLE]) expect([terminal, lines.some(l => l.includes(line))]).toEqual([terminal, true])
    // Every line the pane draws of each body (labels apart, "**" gone) is on one drawn line, never cut or wrapped.
    for (const body of Object.values(WIDTH_CARDS))
      for (const part of cardParts(body))
        for (const { text } of part.lines) if (text !== '') expect([terminal, text, lines.some(l => l.includes(text))]).toEqual([terminal, text, true])
    // Nothing in the card is cut with "…" (the rows above it may be: they are one line each while a card is open).
    expect(lines.slice(lines.findIndex(l => l.includes('g · card 1 of 3'))).some(l => l.includes('…'))).toBe(false)
    await pane.unmount()
  }
})

test('card width: a fenced line over the cap is wrapped at 160 columns, so the check can fail', async ($, on) => {
  const over1 = `┌${'─'.repeat(CAP - 1)}┐`
  const over12 = `${'│ import job ────▶ retry queue ────▶ vendor api'.padEnd(CAP + 11)}│`
  expect([lineCols(over1), lineCols(over12)]).toEqual([CAP + 1, CAP + 12])
  const body = ['fleet · atlas D10, a diagram too wide · lead-1', '', '**unverified**  nothing; drawn to fail', '', '```', over1, over12, '```'].join('\n')
  const { ui } = await openFleet($, on, widthFiles({ 'atlas-D10.md': body }))
  await ui.unmount()
  // Room beside the label column: 54 at 160, 65 at 186, 72 at 200.
  const whole: Record<number, [boolean, boolean]> = { 160: [false, false], 186: [true, false], 200: [true, true] }
  for (const terminal of TERMINALS) {
    const cols = parse.dockColumns(terminal) - GRIP
    const pane = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: cols } })
    await pane.press({ key: 'g' })
    const lines = await drawnLines(pane, cols)
    expect([terminal, lines.some(l => l.includes(over1)), lines.some(l => l.includes(over12))]).toEqual([terminal, ...whole[terminal]!])
    await pane.unmount()
  }
})

// A grill question sent as a card: the grilling format's "Recommended: b" paragraph is the label "recommended" (11),
// which card-add.sh refuses. Written "Recommendation: b" (drawn "rec"), the question and the diagram card beside it
// on lead-1's row are drawn whole at 160 columns; with "Recommended:" the label column widens by one for the whole
// row, so atlas D7's diagram, at the cap, wraps.
const grillCard = (rec: string) =>
  [
    'ROW-12 Q4 of 6: the path for a term the enum lacks',
    '',
    'The problem: a term the enum lacks has no way in.',
    '',
    `${rec}: b, an amendment path in the handoff`,
    '',
    'a) a new enum value per term',
    'b) an amendment path in the handoff',
    'c) drop the term',
  ].join('\n')

/** Draws atlas D7 and the grill card written with `rec` on lead-1's row at 160 columns; true per DIAGRAM line drawn whole. */
async function grillRow($: any, on: any, rec: string, label: string) {
  const grill = grillCard(rec)
  for (const line of [...WIDTH_CARDS['atlas-D7.md']!.split('\n'), ...grill.split('\n')]) expect(lineCols(line)).toBeLessThanOrEqual(CAP)
  expect(cardParts(grill).map(p => p.label)).toContain(label)
  const files = widthFiles({ 'atlas-D7.md': WIDTH_CARDS['atlas-D7.md']! })
  files[`${CARDS_DIR}/ROW-12-Q4.md`] = leadCard('ROW-12 Q4', '16:43', grill)
  const { ui } = await openFleet($, on, files)
  await ui.unmount()
  const cols = parse.dockColumns(160) - GRIP
  const pane = await $.ui.mount({ ...MOUNT, surface: 'terminal', props: { ...MOUNT.props, bodyColumns: cols } })
  await pane.press({ key: 'g' })
  const lines = await drawnLines(pane, cols)
  expect(lines.filter(l => /g · card \d of 2 · (atlas D7|ROW-12 Q4)\b/.test(l))).toHaveLength(2)
  await pane.unmount()
  return DIAGRAM.map(d => lines.some(l => l.includes(d)))
}

test('card width: a grill card written "Recommendation:" (drawn rec) keeps its row whole at 160 columns', async ($, on) => {
  expect(await grillRow($, on, 'Recommendation', 'rec')).toEqual([true, true, true])
})

test('card width: a grill card written "Recommended:" (11) wraps the diagram on its row at 160 columns', async ($, on) => {
  expect(await grillRow($, on, 'Recommended', 'recommended')).toEqual([false, false, false])
})
