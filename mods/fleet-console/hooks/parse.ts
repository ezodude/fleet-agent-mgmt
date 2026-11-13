// Pure helpers for fleet-console: no `$`, no I/O. The tests import these too.

import type { Awaiting, DecisionCard, Done, HeaderParts, IcRow, LeadRow, Row } from '../types'

/** `key: value` lines at the start of a line, in or out of a fence, down to a `## log` heading; the last one of a key wins. */
export function parseState(text: string): Record<string, string> {
  const keys: Record<string, string> = {}
  for (const line of text.split('\n')) {
    if (line.startsWith('## log')) break
    const at = line.indexOf(': ')
    if (at <= 0 || line[0] === ' ' || line[0] === '\t') continue
    keys[line.slice(0, at)] = line.slice(at + 2).replace(/\r$/, '')
  }
  return keys
}

/** The value of a key, or `-` when it is missing. */
export function field(keys: Record<string, string>, key: string): string {
  return keys[key] ?? '-'
}

/**
 * A card value cut into its clauses, every character kept: the pieces joined back are the value.
 * Cuts only outside () and "": after "; ", after ". " when a capital, a digit or "(" follows, and before " / ".
 */
export function clauses(value: string): string[] {
  const pieces: string[] = []
  let start = 0
  let depth = 0
  let quoted = false
  for (let i = 0; i < value.length; i++) {
    const ch = value[i]
    if (ch === '"') quoted = !quoted
    else if (ch === '(' && !quoted) depth++
    else if (ch === ')' && !quoted) depth = Math.max(0, depth - 1)
    if (depth > 0 || quoted) continue
    const after = value[i + 2] ?? ''
    if (value.startsWith('; ', i) || (value.startsWith('. ', i) && /[\p{Lu}\d(]/u.test(after))) {
      pieces.push(value.slice(start, i + 2))
      start = i + 2
      i++
    } else if (value.startsWith(' / ', i) && i > start) {
      pieces.push(value.slice(start, i))
      start = i
    }
  }
  pieces.push(value.slice(start))
  return pieces.filter(p => p !== '')
}

/**
 * A token longer than `width` cut after the last "/" that fits, again on the rest; a part with no "/"
 * that fits is left whole. The parts joined back are the token.
 */
export function breakPath(token: string, width: number): string[] {
  const parts: string[] = []
  let rest = token
  while (rest.length > width) {
    const at = rest.lastIndexOf('/', width - 1)
    if (at <= 0) break
    parts.push(rest.slice(0, at + 1))
    rest = rest.slice(at + 1)
  }
  parts.push(rest)
  return parts
}

/** The text with a line break inside each word longer than `width` (see breakPath); nothing else changes. */
export function breakLong(text: string, width: number): string {
  return text
    .split(' ')
    .map(word => (word.length > width ? breakPath(word, width).join('\n') : word))
    .join(' ')
}

/** "/a/b/STATE.md" -> ["/a/b/", "STATE.md"]; a value with no "/" is all name. */
export function splitPath(path: string): [string, string] {
  const at = path.lastIndexOf('/')
  return [path.slice(0, at + 1), path.slice(at + 1)]
}

/** The text in `n` characters at most: whole when it fits, else its first `n - 1` and "…". */
export function fit(text: string, n: number): string {
  const chars = Array.from(text)
  if (chars.length <= n) return text
  return n < 1 ? '' : `${chars.slice(0, n - 1).join('')}…`
}

/**
 * The widest dock to ask for beside a `terminal`-column transcript: the engine holds a dock to 45% of the
 * terminal and leaves the transcript 60 columns, so this is the most it gives; at least 1, as `columns` must be.
 */
export function dockColumns(terminal: number): number {
  return Math.max(1, Math.min(Math.floor(terminal * 0.45), terminal - 60))
}

/** "atlas-ic-2:@40.%40" -> "%40"; undefined when there is no pane id. */
export function paneOf(tmux: string | undefined): string | undefined {
  const id = tmux?.slice(tmux.lastIndexOf('.') + 1)
  return id && id.startsWith('%') ? id : undefined
}

const ZONES: Record<string, number> = { BST: 60, GMT: 0, UTC: 0, Z: 0, CET: 60, CEST: 120 }

/** "2026-10-21 15:46 BST" -> epoch ms; null when no time is given. */
export function parseUpdated(text: string): number | null {
  const m = /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)(?: ([A-Z]{1,4})\b)?/.exec(text)
  if (!m) return null
  const [y = 0, mo = 1, d = 1, h = 0, mi = 0] = m.slice(1, 6).map(Number)
  const zone = m[6] !== undefined ? ZONES[m[6]] : undefined
  if (zone === undefined) return new Date(y, mo - 1, d, h, mi).getTime()
  return Date.UTC(y, mo - 1, d, h, mi) - zone * 60_000
}

/** 46m, 1h45, 36d. */
export function age(ms: number): string {
  const min = Math.max(0, Math.floor(ms / 60_000))
  if (min < 60) return `${min}m`
  if (min < 24 * 60) return `${Math.floor(min / 60)}h${String(min % 60).padStart(2, '0')}`
  return `${Math.floor(min / (24 * 60))}d`
}

/** Local HH:MM. */
export function hhmm(ms: number): string {
  const t = new Date(ms)
  return `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}`
}

/** Local "YYYY-MM-DD HH:MM". */
export function ymdhm(ms: number): string {
  const t = new Date(ms)
  const day = `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')}`
  return `${day} ${hhmm(ms)}`
}

/** Local HH:MM:SS. */
export function hhmmss(ms: number): string {
  return `${hhmm(ms)}:${String(new Date(ms).getSeconds()).padStart(2, '0')}`
}

export function sameLocalDay(a: number, b: number): boolean {
  return new Date(a).toDateString() === new Date(b).toDateString()
}

/** The folder name Claude Code keeps a project's sessions under. */
export function projectSlug(cwd: string): string {
  return cwd.replace(/[^a-zA-Z0-9]/g, '-')
}

/** Counts of `started` and `result` lines in a workflow journal. */
export function journalCounts(text: string): { started: number; returned: number } {
  let started = 0
  let returned = 0
  for (const line of text.split('\n')) {
    if (!line.trim()) continue
    try {
      const type = (JSON.parse(line) as { type?: string }).type
      if (type === 'started') started++
      if (type === 'result') returned++
    } catch {
      // a line still being written
    }
  }
  return { started, returned }
}

/** A session name, lead-1 id or record folder name used as one folder name: no '/', no '..', no leading dot. */
export const isPlainName = (name: string | undefined): name is string =>
  !!name && /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(name) && !name.includes('..')

export type RecordFolder = { project: string; folder: string; path: string }

/**
 * The record folder a STATE.md "handoff:" line points into: the line's first word is a path (starting "~/" or
 * "<home>/") whose folder is <home>/.fleet-agent-mgmt/records/<project>/<folder>. Undefined for anything else:
 * a handoff elsewhere, a URL, ".", "-", or no line.
 */
export function recordFolderOf(handoff: string | undefined, home: string): RecordFolder | undefined {
  const word = handoff?.trim().split(/\s+/)[0] ?? ''
  const path = word.startsWith('~/') ? `${home}${word.slice(1)}` : word
  const root = `${home}/.fleet-agent-mgmt/records/`
  if (!home || !path.startsWith(root)) return undefined
  const dir = path.slice(root.length, path.lastIndexOf('/'))
  const [project, folder, ...deeper] = dir.split('/')
  if (deeper.length || !isPlainName(project) || !isPlainName(folder)) return undefined
  return { project, folder, path: `${root}${project}/${folder}` }
}

/**
 * Done or not, from the record folder's listing: close.md listed is `done` (with its time when the listing gives
 * one, never a made-up one), the folder listed with no close.md is `open`, and no folder or no listing is `unknown`.
 */
export function doneOf(record: RecordFolder | undefined, listing: readonly { name: string; mtimeMs: number }[] | undefined): Done {
  if (!record || !listing) return { kind: 'unknown' }
  const close = listing.find(f => f.name === 'close.md')
  if (!close) return { kind: 'open', folder: record.folder }
  return close.mtimeMs > 0 ? { kind: 'done', folder: record.folder, closedAt: close.mtimeMs } : { kind: 'done', folder: record.folder }
}

/** The glyph an IC row opens with: ✔ done, ● not done, ? unknown. */
export function doneGlyph(done: Done): string {
  return done.kind === 'done' ? '✔' : done.kind === 'open' ? '●' : '?'
}

/** The card's line under its title: whether the rung is done, and where its close report is. */
export function doneLine(done: Done): string {
  if (done.kind === 'done') {
    const closed = done.closedAt === undefined ? 'closed' : `closed ${ymdhm(done.closedAt)}`
    return `✔ DONE · ${done.folder} ${closed} · close report in the record`
  }
  if (done.kind === 'open') return `● NOT DONE · ${done.folder} open · no close report yet`
  return "? UNKNOWN · this rung predates record folders, so there's no close report"
}

/** Row letters, every one a key; the card closes with `0`, so no letter is kept back. */
export const LETTERS = 'abcdefghijklmnopqrstuvwxyz'.split('')

/**
 * Whom an "awaiting:" line waits on. It opens with `none`, `owner:`, `lead-1:` or `<name>:` (a name in `names`),
 * free text after. A line in the old free-text form reads as idle when it is "none", "nothing", "-" or empty,
 * and is otherwise kept as written, waiting on no one in particular.
 */
export function awaitingOf(text: string, names: readonly string[]): Awaiting {
  const line = text.trim()
  const owner = /^owner:\s?(.*)$/s.exec(line)
  if (owner) return { kind: 'owner', rest: owner[1]! }
  // A name first, so an IC whose name starts "none-" is not read as "none".
  const at = line.indexOf(':')
  const who = line.slice(0, at)
  if (at > 0 && (who === 'lead-1' || names.includes(who))) return { kind: 'who', who, rest: line.slice(at + 1).replace(/^\s/, '') }
  if (line === '' || line === '-' || /^(none|nothing)\b/i.test(line)) return { kind: 'none' }
  return { kind: 'old', text: line }
}

export type IcInput = {
  name: string
  status: string
  tmux?: string
  state: string
  newestFile?: string
  /** The names on the board, which an "awaiting:" line may open with. */
  names?: readonly string[]
  /** Why STATE.md could not be read, when it could not. */
  unreadable?: string
  /** Whether the rung is done (see doneOf); unknown when not given. */
  done?: Done
}

export function icRow(letter: string, ic: IcInput): IcRow {
  const keys = parseState(ic.state)
  const updated = field(keys, 'updated')
  return {
    kind: 'ic',
    letter,
    name: ic.name,
    pane: paneOf(ic.tmux),
    status: ic.status,
    rung: field(keys, 'rung'),
    needsYou: field(keys, 'awaiting'),
    waiting: awaitingOf(field(keys, 'awaiting'), ic.names ?? []),
    updated,
    updatedAt: parseUpdated(updated),
    ...(ic.unreadable === undefined ? {} : { unreadable: ic.unreadable }),
    done: ic.done ?? { kind: 'unknown' },
    card: {
      stop: field(keys, 'stop'),
      awaiting: field(keys, 'awaiting'),
      next: field(keys, 'next'),
      updated,
      newestFile: ic.newestFile ?? '-',
    },
  }
}

/** "<n> IC (<b> busy) · <w> wait on you, oldest <age> (<IC name>) · <k> workflows running" */
export function header(rows: Row[], now: number): string {
  const { ics, wait, workflows } = headerParts(rows, now)
  return `${ics} · ${wait} · ${workflows}`
}

/** The time a row has waited on you since: its oldest open decision card's, else its STATE.md "updated:". */
function waitingSince(row: IcRow | LeadRow): number | null {
  const dated = (row.cards ?? []).map(c => c.sinceAt).filter((t): t is number => t !== null)
  if (dated.length) return Math.min(...dated)
  return row.kind === 'ic' ? row.updatedAt : null
}

/** Whether a row waits on you: an open decision card for it, or an "awaiting:" line opening with `owner:`. */
export function waitsOnYou(row: Row): row is IcRow | LeadRow {
  if (row.kind === 'workflow') return false
  return (row.cards?.length ?? 0) > 0 || (row.kind === 'ic' && row.waiting.kind === 'owner')
}

/**
 * The header's three parts, and how many rows wait on you (an open decision card for the row, or an "awaiting:"
 * line opening with `owner:`, nothing else); the pane draws `wait` in amber while that is above 0. The number in
 * `wait` counts ICs only, beside the IC count: lead-1, when its own card waits, is named, never counted as an IC
 * ("3 IC and lead-1 wait on you", "lead-1 waits on you"). While any card file is shown, `waitShort` is `wait`
 * without its "oldest" part, for a pane too narrow for the whole counts line.
 */
export function headerParts(rows: Row[], now: number): HeaderParts {
  const ics = rows.filter((r): r is IcRow => r.kind === 'ic')
  const busy = ics.filter(r => r.status === 'busy').length
  const waiting = rows.filter(waitsOnYou)
  const icsWaiting = waiting.filter(r => r.kind === 'ic').length
  const isLeadWaiting = waiting.some(r => r.kind === 'lead')
  const dated = waiting
    .map(r => ({ name: r.name, at: waitingSince(r) }))
    .filter((r): r is { name: string; at: number } => r.at !== null)
    .sort((x, y) => x.at - y.at)
  const oldest = dated[0]
  const oldestText = oldest ? `, oldest ${age(now - oldest.at)} (${oldest.name})` : ''
  const running = rows.filter(r => r.kind === 'workflow' && r.doneAt === undefined).length
  const who = !isLeadWaiting
    ? `${icsWaiting} wait on you`
    : icsWaiting > 0
      ? `${icsWaiting} IC and lead-1 wait on you`
      : 'lead-1 waits on you'
  const hasCards = rows.some(r => r.kind !== 'workflow' && (r.cards?.length || r.lastAnswered))
  return {
    ics: `${ics.length} IC (${busy} busy)`,
    wait: `${who}${oldestText}`,
    ...(hasCards ? { waitShort: who } : {}),
    waiting: waiting.length,
    workflows: `${running} workflow${running === 1 ? '' : 's'} running`,
  }
}

// Decision cards: lead-1 writes one file per card it sends the owner (shared/ledger/card-add.sh), under
// <home>/.fleet-agent-mgmt/checks/lead-1/cards/. The mod lists and reads them, never writes them.

const CARD_KEYS = ['id', 'row', 'status', 'since', 'where', 'reply', 'answer'] as const

/**
 * A card file: `key: value` lines (id, row, status, since, where, reply, answer), a line `---`, then the body as
 * sent. Undefined when the file is not one: no `---`, a key missing (answer may be), a status other than open or
 * answered, a row that is not a plain name, or an empty body. A file that is not a card is left out, never shown.
 */
export function parseCard(text: string, file: string, mtimeMs: number): DecisionCard | undefined {
  const lines = text.replace(/\r\n/g, '\n').split('\n')
  const end = lines.indexOf('---')
  if (end < 0) return undefined
  const keys: Record<string, string> = {}
  for (const line of lines.slice(0, end)) {
    const m = /^([a-z]+):\s?(.*)$/.exec(line)
    if (m && (CARD_KEYS as readonly string[]).includes(m[1]!)) keys[m[1]!] = m[2]!.trim()
  }
  const body = lines.slice(end + 1).join('\n').replace(/\s+$/, '')
  const { id, row, status, since, where, reply } = keys
  if (!id || !row || !since || !where || !reply || body.trim() === '') return undefined
  if (status !== 'open' && status !== 'answered') return undefined
  if (!isPlainName(row)) return undefined
  return { file, mtimeMs, id, row, status, since, sinceAt: parseUpdated(since), where, reply, answer: keys.answer || '-', body }
}

/** A row's open cards, newest first (by since, then by file time), and its most recently answered one. */
export function cardsOf(cards: readonly DecisionCard[], row: string): { open: DecisionCard[]; lastAnswered?: DecisionCard } {
  const mine = cards.filter(c => c.row === row)
  const open = mine
    .filter(c => c.status === 'open')
    .sort((x, y) => (y.sinceAt ?? 0) - (x.sinceAt ?? 0) || y.mtimeMs - x.mtimeMs || (x.id < y.id ? -1 : 1))
  const answered = mine.filter(c => c.status === 'answered').sort((x, y) => y.mtimeMs - x.mtimeMs)
  return { open, ...(answered[0] ? { lastAnswered: answered[0] } : {}) }
}

/** "16:40" when `since` is on the same day as `now`, else "2026-10-20 16:40": as written, never converted. */
export function sinceShort(since: string, now: number): string {
  const m = /^(\d{4}-\d\d-\d\d) (\d\d:\d\d)/.exec(since)
  if (!m) return since
  return m[1] === ymdhm(now).slice(0, 10) ? m[2]! : `${m[1]} ${m[2]}`
}

/** One part of a card's body under its label: each line with how far it sits in from the part's first line. */
export type CardPart = { label: string; lines: { indent: number; text: string }[] }

// A line that opens a labelled part: "**problem**  …" (the decision-card skill's shape) anywhere outside a fence, or
// "The problem: …" at the start of a paragraph.
const BOLD_PART = /^\*\*([A-Za-z][A-Za-z ]{0,19})\*\*\s*(.*)$/
const WORD_PART = /^([A-Z][A-Za-z ]{0,19}):\s+(.*)$/
// The labels the pane draws, one word each: the decision-card skill's own where it has one ("rec").
const LABELS: Record<string, string> = { 'the problem': 'problem', status: 'state', recommendation: 'rec' }
// An option line: "a) …", the letter and its ")" a marker the option's wrapped lines hang under.
const OPTION = /^([a-z]\) )(.*)$/
const FENCE = /^\s*```/

/** "a) keep it" -> ["a) ", "keep it"]; undefined for a line that is not an option. */
export function optionParts(text: string): [string, string] | undefined {
  const m = OPTION.exec(text)
  return m ? [m[1]!, m[2]!] : undefined
}

/**
 * A card's body cut into labelled parts, in order, for the pane: the first paragraph with no label is "about" (the
 * frame line, less a leading "?" glyph, which every open card would carry), "The problem:" is "problem", "Status:"
 * is "state", "Recommendation:" is "rec", any other "<Label>:" or "**label**" keeps its label in lower case, a
 * paragraph with no label that opens with "a) " is "options", and any other paragraph with no label of its own is
 * drawn under an empty one. "<Label>:" and "Reply" open a part only at the start of a paragraph, so a line inside
 * a paragraph that starts with such a word stays in its paragraph; inside a ``` fence nothing opens a part, and a
 * blank line is kept. The reply part (a "**reply**" label or a paragraph opening "Reply") is left out: the card's
 * reply line carries it. Text is kept as written except the "**" bold marks, which the pane does not draw.
 */
export function cardParts(body: string): CardPart[] {
  const parts: (CardPart & { more: { indent: number; text: string }[] })[] = []
  let cur: (typeof parts)[number] | undefined
  let isFenced = false
  const plain = (t: string) => t.replace(/\*\*/g, '')
  const add = (raw: string) => {
    const indent = raw.length - raw.trimStart().length
    if (cur!.lines.length === 0 && cur!.more.length === 0) cur!.lines.push({ indent: 0, text: plain(raw.trim()) })
    else cur!.more.push({ indent, text: plain(raw.trim()) })
  }
  for (const raw of body.replace(/\r\n/g, '\n').split('\n')) {
    if (isFenced) {
      // Inside a fence every line is kept as it is, a blank one too, until the fence closes.
      add(raw.trim() === '' ? '' : raw)
      if (FENCE.test(raw)) isFenced = false
      continue
    }
    if (raw.trim() === '') {
      cur = undefined
      continue
    }
    const isStart = cur === undefined
    const m = BOLD_PART.exec(raw) ?? (isStart ? WORD_PART.exec(raw) : null)
    if (m || (isStart && /^Reply\b/.test(raw))) {
      const label = m ? m[1]!.trim().toLowerCase() : 'reply'
      const text = m ? (m[2] ?? '') : raw
      cur = { label: LABELS[label] ?? label, lines: [], more: [] }
      if (text.trim() !== '') cur.lines.push({ indent: 0, text: plain(text.trim()) })
      parts.push(cur)
      continue
    }
    if (!cur) {
      const before = parts[parts.length - 1]?.label
      const label = parts.length === 0 ? 'about' : OPTION.test(raw.trim()) && before !== 'options' ? 'options' : ''
      cur = { label, lines: [], more: [] }
      parts.push(cur)
      if (label === 'about') {
        add(raw.replace(/^(\s*)\?\s+/, '$1'))
        continue
      }
    }
    add(raw)
    if (FENCE.test(raw)) isFenced = true
  }
  return parts
    .filter(p => p.label !== 'reply')
    .map(p => {
      const base = Math.min(...p.more.filter(l => l.text !== '').map(l => l.indent))
      return {
        label: p.label,
        lines: [...p.lines, ...p.more.map(l => ({ indent: l.text === '' ? 0 : l.indent - base, text: l.text }))],
      }
    })
}
