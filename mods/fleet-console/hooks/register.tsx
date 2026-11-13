import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Board, DecisionCard, HeaderParts, IcRow, LeadRow, Row, WorkflowRow } from '../types'
import {
  LETTERS,
  age,
  breakLong,
  cardParts,
  optionParts,
  cardsOf,
  clauses,
  dockColumns,
  doneGlyph,
  doneLine,
  doneOf,
  fit,
  header,
  headerParts,
  hhmm,
  icRow,
  isPlainName,
  journalCounts,
  parseCard,
  parseState,
  projectSlug,
  recordFolderOf,
  sameLocalDay,
  sinceShort,
  splitPath,
  waitsOnYou,
} from './parse'

const PANE = 'fleet'
const EMPTY: Board = { rows: [], header: 'reading the fleet…', refreshedAt: 0 }
const board = atom({ plugin: 'fleet-console', key: 'board' } as const, EMPTY)
const selected = atom({ plugin: 'fleet-console', key: 'selected' } as const, '')
// The time, written each second while the board is open, so "refreshed <n>s ago" counts up between refreshes.
const tick = atom({ plugin: 'fleet-console', key: 'tick' } as const, 0)

type Entry = { name: string; kind: string; mtimeMs: number }
type Session = { name?: string; status?: string; tmux?: string; sessionId?: string; cwd?: string; updatedAt?: number }

// Text of each file read, by path, with the mtime it was read at: a file is read again only when its mtime moves.
// A failed read is kept too, with its reason, so a file too large to read is not tried again until its mtime moves.
const cache = new Map<string, { mtimeMs: number; text: string; failed?: string }>()
// The 5 s refresh and the 1 s tick, both running only while the board is open.
let timer: { cancel(): void } | undefined
let ticker: { cancel(): void } | undefined
let isRefreshing = false

async function list($: EngineInterface, dir: string): Promise<Entry[]> {
  try {
    return await $.fs.list(dir)
  } catch {
    return []
  }
}

async function readChanged($: EngineInterface, path: string, mtimeMs: number): Promise<string> {
  const hit = cache.get(path)
  if (hit && hit.mtimeMs === mtimeMs) {
    if (hit.failed !== undefined) throw new Error(hit.failed)
    return hit.text
  }
  let text: string
  try {
    text = await $.fs.read(path)
  } catch (error) {
    cache.set(path, { mtimeMs, text: '', failed: error instanceof Error ? error.message : String(error) })
    throw error
  }
  cache.set(path, { mtimeMs, text })
  return text
}

/** A folder's entries, or undefined when it cannot be listed (gone, refused): not the same as an empty folder. */
async function listing($: EngineInterface, dir: string): Promise<Entry[] | undefined> {
  try {
    return await $.fs.list(dir)
  } catch {
    return undefined
  }
}

const byName = (x: Entry, y: Entry) => (x.name < y.name ? -1 : x.name > y.name ? 1 : 0)

/** lead-1's workflows started today, from its session folder. */
async function workflows($: EngineInterface, base: string, now: number): Promise<WorkflowRow[]> {
  const scripts = await list($, `${base}/workflows/scripts`)
  const records = await list($, `${base}/workflows`)
  const runs = (await list($, `${base}/subagents/workflows`)).filter(r => r.kind === 'dir' && r.name.startsWith('wf_'))
  const rows: WorkflowRow[] = []
  for (const run of runs) {
    const script = scripts.find(f => f.kind === 'file' && f.name.endsWith(`-${run.name}.js`))
    if (!script || !sameLocalDay(script.mtimeMs, now)) continue
    const dir = `${base}/subagents/workflows/${run.name}`
    const journal = (await list($, dir)).find(f => f.kind === 'file' && f.name === 'journal.jsonl')
    let counts = { started: -1, returned: -1 }
    try {
      if (journal) counts = journalCounts(await readChanged($, `${dir}/journal.jsonl`, journal.mtimeMs))
    } catch {
      // too large or gone: shown as "?"
    }
    rows.push({
      kind: 'workflow',
      letter: '',
      name: script.name.slice(0, -(run.name.length + 4)),
      id: run.name,
      ...counts,
      startedAt: script.mtimeMs,
      doneAt: records.find(f => f.name === `${run.name}.json`)?.mtimeMs,
      journal: `${dir}/journal.jsonl`,
    })
  }
  return rows.sort((x, y) => x.startedAt - y.startedAt)
}

async function collect($: EngineInterface): Promise<Board> {
  const now = await $.clock.now()
  const home = await $.env.get('HOME')
  if (!home) return { ...EMPTY, header: 'HOME is not set', refreshedAt: now }

  const sessionsDir = `${home}/.claude/sessions`
  const files = (await list($, sessionsDir)).filter(f => f.kind === 'file' && f.name.endsWith('.json')).sort(byName)
  const sessions = new Map<string, Session>()
  for (const f of files) {
    let s: Session
    try {
      s = JSON.parse(await readChanged($, `${sessionsDir}/${f.name}`, f.mtimeMs)) as Session
    } catch {
      continue
    }
    if (!isPlainName(s.name)) continue
    const had = sessions.get(s.name)
    if (!had || (s.updatedAt ?? 0) > (had.updatedAt ?? 0)) sessions.set(s.name, s)
  }

  // lead-1's decision cards, one file each; a name starting "." is never one (a tool's own file). Read, never written.
  const cardsDir = `${home}/.fleet-agent-mgmt/checks/lead-1/cards`
  const cards: DecisionCard[] = []
  for (const f of (await list($, cardsDir)).filter(f => f.kind === 'file' && f.name.endsWith('.md') && !f.name.startsWith('.')).sort(byName)) {
    try {
      const card = parseCard(await readChanged($, `${cardsDir}/${f.name}`, f.mtimeMs), f.name, f.mtimeMs)
      if (card) cards.push(card)
    } catch {
      // too large or gone: left out until its mtime moves
    }
  }

  // IC rows in name order, so an IC keeps its letter when it restarts under a new pid.
  const rows: Row[] = []
  const names = [...sessions.keys()]
  for (const s of [...sessions.values()].sort((x, y) => (x.name! < y.name! ? -1 : x.name! > y.name! ? 1 : 0))) {
    const checks = `${home}/.fleet-agent-mgmt/checks/${s.name}`
    const entries = (await list($, checks)).filter(f => f.kind === 'file')
    const state = entries.find(f => f.name === 'STATE.md')
    if (!state) continue
    // The newest file beside STATE.md, never STATE.md itself (rewritten on every update) and never a name starting
    // "." (a hook's own marker file): listed, never read.
    const others = entries.filter(f => f !== state && !f.name.startsWith('.'))
    const newest = others.length ? others.reduce((x, y) => (y.mtimeMs > x.mtimeMs ? y : x)) : undefined
    // One STATE.md that cannot be read blanks its own row only.
    let text = ''
    let unreadable: string | undefined
    try {
      text = await readChanged($, `${checks}/STATE.md`, state.mtimeMs)
    } catch (error) {
      unreadable = error instanceof Error ? error.message : String(error)
    }
    // Done or not: close.md in the record folder the "handoff:" line points into. Listed, never read.
    const record = recordFolderOf(parseState(text).handoff, home)
    const done = doneOf(record, record ? await listing($, record.path) : undefined)
    const { open, lastAnswered } = cardsOf(cards, s.name!)
    rows.push({
      ...icRow(LETTERS[rows.length] ?? '?', {
        name: s.name!,
        status: s.status ?? '-',
        tmux: s.tmux,
        state: text,
        names,
        done,
        ...(newest ? { newestFile: `${checks}/${newest.name}` } : {}),
        ...(unreadable === undefined ? {} : { unreadable }),
      }),
      ...(open.length ? { cards: open } : {}),
      ...(lastAnswered ? { lastAnswered } : {}),
    })
  }

  const lead = sessions.get('lead-1')
  if (lead && isPlainName(lead.sessionId) && lead.cwd) {
    const base = `${home}/.claude/projects/${projectSlug(lead.cwd)}/${lead.sessionId}`
    for (const w of await workflows($, base, now)) rows.push({ ...w, letter: LETTERS[rows.length] ?? '?' })
  }
  // lead-1's own row, last so no other row's letter moves: only while it has an open card for row lead-1.
  const mine = cardsOf(cards, 'lead-1')
  if (mine.open.length && !rows.some(r => r.kind === 'ic' && r.name === 'lead-1')) {
    rows.push({
      kind: 'lead',
      letter: LETTERS[rows.length] ?? '?',
      name: 'lead-1',
      status: lead?.status ?? '-',
      cards: mine.open,
      ...(mine.lastAnswered ? { lastAnswered: mine.lastAnswered } : {}),
    })
  }
  return { rows, header: header(rows, now), parts: headerParts(rows, now), refreshedAt: now }
}

/** Starts the 5 s refresh and the 1 s tick, stopping any left from before. */
function startTimers($: EngineInterface): void {
  stopTimers()
  timer = $.clock.every(5000, () => {
    void refresh($)
  })
  ticker = $.clock.every(1000, () => {
    void $.clock
      .now()
      .then(now => update($, tick, () => now))
      .catch(() => undefined)
  })
}

function stopTimers(): void {
  timer?.cancel()
  ticker?.cancel()
  timer = undefined
  ticker = undefined
}

async function refresh($: EngineInterface): Promise<void> {
  if (isRefreshing) return
  isRefreshing = true
  try {
    const next = await collect($)
    await update($, board, () => next)
  } catch (error) {
    const problem = error instanceof Error ? error.message : String(error)
    await update($, board, b => ({ ...b, problem }))
  } finally {
    isRefreshing = false
  }
}

const count = (n: number) => (n < 0 ? '?' : String(n))

/** Who a row is, kept as the open card: an IC by its name, a workflow by its run id. */
const rowId = (row: Row) => (row.kind === 'workflow' ? `workflow:${row.id}` : `${row.kind}:${row.name}`)

// The board's colours, as theme keys: amber waits on you, blue busy or running, green done.
const AMBER = 'warning'
const BLUE = 'suggestion'
const GREEN = 'success'
// An IC's done glyph and card line: green done, blue not done, amber unknown.
const DONE_COLOUR = { done: GREEN, open: BLUE, unknown: AMBER } as const

function icLine(row: IcRow): string {
  return `${row.name} · ${row.rung} · ${row.status}`
}

function workflowEnd(row: WorkflowRow): string {
  return row.doneAt === undefined ? 'running' : `done ${hhmm(row.doneAt)}`
}

/** A workflow row between its name and its state: "<r> of <n> agents returned · started <time>". */
function workflowCounts(row: WorkflowRow): string {
  return `${count(row.returned)} of ${count(row.started)} agents returned · started ${hhmm(row.startedAt)}`
}

/** A workflow row after its name: " · <r> of <n> agents returned · started <time> · <running or done>". */
function workflowTail(row: WorkflowRow): string {
  return ` · ${workflowCounts(row)} · ${workflowEnd(row)}`
}

function workflowLine(row: WorkflowRow): string {
  return `workflow ${row.name}${workflowTail(row)}`
}

/** "3s ago", "1m ago", "1h05 ago", from the last refresh that worked; "-" before the first. */
function refreshedAgo(now: number, refreshedAt: number): string {
  if (!refreshedAt) return '-'
  const ms = Math.max(0, now - refreshedAt)
  return ms < 60_000 ? `${Math.floor(ms / 1000)}s ago` : `${age(ms)} ago`
}

// The card's border and paddingX take 4 columns; a clause's indent and its "·" mark take 4 more,
// the newest file's indent 2.
const CARD_FRAME = 4
const CLAUSE_INDENT = 4
const PATH_INDENT = 2

// A row: the "▌" mark takes 1 column and its Button's "a: " 3 more; the row's second lines sit 3 in, under the label.
// An IC row's done glyph and the space after it take 2 more, before its letter.
const ROW_MARK = 1
const ROW_INDENT = 3
const DONE_MARK = 2
// A workflow name cut shorter than this would say nothing, so below it the counts give way too.
const NAME_MIN = 12
// A decision card: its labels in a column as wide as the longest and 3 more, the text beside them; the reply's
// alternatives sit 2 in under "you type, …" when they do not fit beside it.
const LABEL_GAP = 3
const REPLY_INDENT = 2
// The first card's title shares its row with the "0: close card" key, which takes 13 columns and 1 between.
const CLOSE_KEY = 14

const W = (s: string) => Array.from(s).length
const plural = (n: number, one: string) => `${n} ${one}${n === 1 ? '' : 's'}`

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    try {
      await $.command.register({
        name: 'fleet',
        description: 'Open the fleet console: what each IC is doing and what it needs from you',
        immediate: true,
      })
    } catch {
      // the name is taken: /fleet stays with its owner
    }
    // A reload drops the module's timers but not the board: if the board is still up, start them again.
    try {
      if ((await $.ui.panes()).some(pane => pane.id === PANE)) {
        startTimers($)
        await refresh($)
      }
    } catch {
      // no pane list here: the next /fleet starts them
    }
    return next(e)
  })

  on('command.run', { command: 'fleet' }, async ($, e) => {
    // /fleet always opens the bare board: no card from an earlier look.
    await update($, selected, () => '')
    await refresh($)
    startTimers($)
    // The dock as wide as the engine gives one; a width the owner dragged it to still wins. The title is drawn
    // only as a tab while two panes are open, so it stays short: the board draws its own head row.
    const terminal = e.presentation?.columns
    await $.ui.open({ id: PANE, title: 'fleet', focus: true, ...(terminal ? { columns: dockColumns(terminal) } : {}) })
    return {}
  })

  // Closing the board (its close mark or ctrl+x x) stops the refresh and clears the card.
  // If that fails, the board still closes.
  on('ui.close', { id: PANE }, async ($, e, next) => {
    stopTimers()
    await update($, selected, () => '')
    return next(e)
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const b = await read($, board)
    const id = await read($, selected)
    // Read so each second's tick draws the board again; the time itself is the clock's.
    await read($, tick)
    // The card follows a row by who it is (the IC's name, the workflow's run id), never by its letter.
    const shown = b.rows.find(r => rowId(r) === id)
    const now = await $.clock.now()
    const isFocused = e.props?.isFocused === true

    // Every letter on the board is a key: it opens that row's card. It runs no process and types nothing.
    // The card opens under the rows, so the press brings it into view, moving the board the least that shows it
    // (its top when it is taller than the pane). If the engine refuses that (the card not drawn yet), the press
    // brings the board's top into view instead, where the card starts under the one-line rows.
    const press = (row: Row) => async () => {
      await update($, selected, () => rowId(row))
      // A scroll the surface refuses leaves the card open all the same.
      const moved = await $.ui.scroll({ in: PANE, to: { key: 'card' }, block: 'nearest' }).catch(() => undefined)
      if (moved?.deny !== undefined) await $.ui.scroll({ in: PANE, to: 'start' }).catch(() => undefined)
    }
    const closeCard = () => update($, selected, () => '')

    const letters = b.rows.map(r => r.letter)
    const range = letters.length > 1 ? `${letters[0]}–${letters[letters.length - 1]}` : letters[0]
    // The keys reach the board only while it holds them; any other key, and ↑↓ when nothing scrolls, goes to the prompt.
    const keys = isFocused
      ? [
          ...(range ? [`${range} open a card`] : []),
          ...(shown ? ['0 closes the card'] : []),
          'Esc back to your prompt',
          'other keys go to your prompt',
        ]
      : ['your keys are at the prompt: click the board or press ctrl+x tab to use the letters here']
    // The engine binds ctrl+x x to the pane only while the pane holds the keys, so away from it ctrl+x tab comes first.
    const legend = [...keys, isFocused ? 'ctrl+x x closes the board' : 'ctrl+x tab, then ctrl+x x closes the board'].join(' · ')

    // The card's widths, from the pane's body: a word longer than its row breaks after a "/", never mid-word.
    const columns = typeof e.props?.bodyColumns === 'number' ? e.props.bodyColumns : 120
    const clauseWidth = Math.max(16, columns - CARD_FRAME - CLAUSE_INDENT)
    const pathWidth = Math.max(16, columns - CARD_FRAME - PATH_INDENT)
    // A row line is cut at the pane's edge with "…" (its card has it in full); the status and the age stay whole.
    const rowWidth = columns - ROW_MARK - ROW_INDENT
    const rest = (...fixed: string[]) => rowWidth - fixed.reduce((n, t) => n + Array.from(t).length, 0)
    // The same for an IC row, whose done glyph comes before its letter.
    const icRest = (...fixed: string[]) => rest(...fixed) - DONE_MARK
    const isCardOpen = shown !== undefined

    /** What an IC waits on, as its row's second line; undefined when it waits on nobody. */
    const waitLine = (row: IcRow | LeadRow) => {
      const open = row.cards ?? []
      if (open.length) {
        const head = 'waiting on you: '
        const dated = open.map(c => c.sinceAt).filter((t): t is number => t !== null)
        const since = dated.length ? age(b.refreshedAt - Math.min(...dated)) : '-'
        const tail = ` · ${since} · ${plural(open.length, 'card')}`
        return `${head}${fit(open.map(c => c.id).join(', '), icRest(head, tail))}${tail}`
      }
      if (row.kind === 'lead') return undefined
      const w = row.waiting
      if (w.kind === 'none') return undefined
      const head = w.kind === 'owner' ? 'waiting on you: ' : w.kind === 'who' ? `waiting on ${w.who}: ` : 'awaiting: '
      const text = w.kind === 'old' ? w.text : w.rest
      const since = row.updatedAt === null ? '-' : age(b.refreshedAt - row.updatedAt)
      return `${head}${fit(text, icRest(head, ' · ', since))} · ${since}`
    }
    /** The card title's end: whom the IC waits on, when it is you, lead-1 or another IC. */
    const waitTitle = (row: IcRow) =>
      row.waiting.kind === 'owner' ? ' · waiting on you' : row.waiting.kind === 'who' ? ` · waiting on ${row.waiting.who}` : ''
    /**
     * A workflow row's name and counts, cut to the row: the name gives way first, down to NAME_MIN, then the
     * counts. The state ("running", "done <time>") stays whole, as an IC row's status does.
     */
    const workflowFit = (row: WorkflowRow) => {
      const end = workflowEnd(row)
      const counts = workflowCounts(row)
      const nameRoom = rest('workflow ', ' · ', counts, ' · ', end)
      if (nameRoom >= Math.min(NAME_MIN, Array.from(row.name).length)) return { name: fit(row.name, nameRoom), counts, end }
      const name = fit(row.name, NAME_MIN)
      return { name, counts: fit(counts, rest('workflow ', name, ' · ', ' · ', end)), end }
    }
    const workflowButton = (row: WorkflowRow) => {
      const { name, counts, end } = workflowFit(row)
      return (
        <Button key={row.letter} hotkey={row.letter} plain label={workflowLine(row)} onPress={press(row)}>
          <Text bold>{`workflow ${name}`}</Text>
          {` · ${counts} · `}
          <Text color={row.doneAt === undefined ? BLUE : GREEN}>{end}</Text>
        </Button>
      )
    }
    /** For an IC not waiting on you: when its STATE.md was last updated, and its "next:" as written. */
    const lastLine = (row: IcRow) => {
      const head = `last: ${row.updated} · next: `
      return `${head}${fit(row.card.next, icRest(head))}`
    }

    // One card field: its label on its own row, then one row per clause, each wrapped under its own text.
    const cardField = (id: string, value: string) => (
      <Box key={`card-${id}`} flexDirection="column" marginTop={1}>
        <Text key={`card-${id}-label`} bold dimColor>
          {id}
        </Text>
        <Box key={`card-${id}-value`} flexDirection="column" paddingLeft={2}>
          {clauses(value).map((clause, i) => (
            <Box key={`card-${id}-${i}`} flexDirection="row">
              <Box key={`card-${id}-${i}-mark`} width={2} flexShrink={0}>
                <Text key={`card-${id}-${i}-dot`} dimColor>
                  ·
                </Text>
              </Box>
              <Box key={`card-${id}-${i}-body`} flexDirection="column" flexShrink={1}>
                <Text key={`card-${id}-${i}-text`}>{breakLong(clause.trim(), clauseWidth)}</Text>
              </Box>
            </Box>
          ))}
        </Box>
      </Box>
    )
    const cardNewest = (path: string) => {
      const [dir, name] = splitPath(path)
      return (
        <Box key="card-newest" flexDirection="column" marginTop={1}>
          <Text key="card-newest-label" bold dimColor>
            newest file
          </Text>
          <Box key="card-newest-value" flexDirection="column" paddingLeft={PATH_INDENT}>
            {dir !== '' && <Text key="card-newest-dir">{breakLong(dir, pathWidth)}</Text>}
            <Text key="card-newest-name">{name}</Text>
          </Box>
        </Box>
      )
    }
    // One plain card field: its label on its own row, the value under it (a workflow card's fields).
    const cardPlain = (id: string, label: string, value: string) => (
      <Box key={`card-${id}`} flexDirection="column" marginTop={1}>
        <Text key={`card-${id}-label`} bold dimColor>
          {label}
        </Text>
        <Box key={`card-${id}-value`} flexDirection="column" paddingLeft={PATH_INDENT}>
          <Text key={`card-${id}-text`}>{breakLong(value, pathWidth)}</Text>
        </Box>
      </Box>
    )
    // The card's title row, with the key that closes the card.
    const cardHead = (title: string) => (
      <Box key="card-head" flexDirection="row" justifyContent="space-between">
        <Text key="card-title" bold color={AMBER}>
          {title}
        </Text>
        <Button key="close-card" hotkey="0" plain label="close card" onPress={closeCard} />
      </Box>
    )

    // A rule across the card, between one decision card and the next, and before the IC's STATE.md.
    const rule = (key: string) => (
      <Box key={key} marginTop={1}>
        <Text key={`${key}-text`} dimColor>
          {'─'.repeat(Math.max(1, columns - CARD_FRAME))}
        </Text>
      </Box>
    )
    /** What you type for a card, and in which pane: the label, and each reply it takes. */
    const replyOf = (card: DecisionCard) => ({
      you: `you type, in ${card.where}'s pane`,
      replies: card.reply.split(' | ').map(r => r.trim()).filter(r => r !== ''),
    })
    /**
     * One decision card, as lead-1 sent it: the title (the row's letter, the card's id, since when it waits on you),
     * each part of the body under its label in a column, then what you type and in which pane. The label column and
     * where the replies sit (beside "you type, …" or under it) are the row's, the same on each of its cards.
     */
    const decisionCard = (
      row: IcRow | LeadRow,
      card: DecisionCard,
      i: number,
      n: number,
      layout: { labelColumn: number; isBeside: boolean },
    ) => {
      const { labelColumn, isBeside } = layout
      const parts = cardParts(card.body)
      const textWidth = Math.max(16, columns - CARD_FRAME - labelColumn)
      const head = `${row.letter} · ${n > 1 ? `card ${i + 1} of ${n}` : 'last card'} · ${card.id}`
      const since = `waiting on you since ${sinceShort(card.since, now)}`
      // The title on one line when it fits beside the close key; otherwise "waiting on you since …" on its own line,
      // so the title never breaks inside a phrase.
      const isOneLine = W(head) + W(' · ') + W(since) + (i === 0 ? CLOSE_KEY : 0) <= columns - CARD_FRAME
      const title = isOneLine ? `${head} · ${since}` : head
      const { you, replies } = replyOf(card)
      const replyWidth = Math.max(16, columns - CARD_FRAME - (isBeside ? W(you) + LABEL_GAP : REPLY_INDENT))
      const k = `dc-${i}`
      // A line of the body: an option ("a) …") hangs its wrapped lines under its text, not under its letter.
      const bodyLine = (key: string, line: { indent: number; text: string }) => {
        const width = textWidth - line.indent
        const option = optionParts(line.text)
        if (!option)
          return (
            <Box key={key} paddingLeft={line.indent}>
              <Text key={`${key}-text`}>{breakLong(line.text, Math.max(16, width))}</Text>
            </Box>
          )
        const [marker, text] = option
        return (
          <Box key={key} flexDirection="row" paddingLeft={line.indent}>
            <Box key={`${key}-marker`} width={W(marker)} flexShrink={0}>
              <Text key={`${key}-marker-text`}>{marker.trimEnd()}</Text>
            </Box>
            <Box key={`${key}-option`} flexShrink={1}>
              <Text key={`${key}-text`}>{breakLong(text, Math.max(16, width - W(marker)))}</Text>
            </Box>
          </Box>
        )
      }
      return (
        <Box key={k} flexDirection="column">
          {i === 0 ? (
            cardHead(title)
          ) : (
            <Text key={`${k}-title`} bold color={AMBER}>
              {title}
            </Text>
          )}
          {!isOneLine && (
            <Text key={`${k}-since`} bold color={AMBER}>
              {since}
            </Text>
          )}
          {parts.map((part, j) => (
            <Box key={`${k}-part-${j}`} flexDirection="row" marginTop={1}>
              <Box key={`${k}-part-${j}-label`} width={labelColumn} flexShrink={0}>
                <Text key={`${k}-part-${j}-label-text`} bold dimColor>
                  {part.label === '' ? ' ' : part.label}
                </Text>
              </Box>
              <Box key={`${k}-part-${j}-body`} flexDirection="column" flexShrink={1}>
                {part.lines.map((line, l) => bodyLine(`${k}-part-${j}-${l}`, line))}
              </Box>
            </Box>
          ))}
          <Box key={`${k}-reply`} flexDirection={isBeside ? 'row' : 'column'} marginTop={1}>
            <Box key={`${k}-reply-label`} {...(isBeside ? { width: W(you) + LABEL_GAP, flexShrink: 0 } : {})}>
              <Text key={`${k}-reply-label-text`} bold dimColor>
                {you}
              </Text>
            </Box>
            <Box key={`${k}-reply-body`} flexDirection="column" flexShrink={1} paddingLeft={isBeside ? 0 : REPLY_INDENT}>
              {replies.map((r, l) => (
                <Text key={`${k}-reply-${l}`} bold>
                  {breakLong(r, replyWidth)}
                </Text>
              ))}
            </Box>
          </Box>
        </Box>
      )
    }
    /** The open decision cards of a row, newest first, each in full, a rule between them. */
    const decisionCards = (row: IcRow | LeadRow) => {
      const open = row.cards ?? []
      // One label column and one reply layout for the whole row, so its cards line up one under the other.
      const labelColumn = Math.max(0, ...open.flatMap(c => cardParts(c.body).map(p => W(p.label)))) + LABEL_GAP
      const isBeside = open.every(c => {
        const { you, replies } = replyOf(c)
        return W(you) + LABEL_GAP + Math.max(0, ...replies.map(W)) <= columns - CARD_FRAME
      })
      return open.flatMap((card, i) => [
        ...(i > 0 ? [rule(`dc-rule-${i}`)] : []),
        decisionCard(row, card, i, open.length, { labelColumn, isBeside }),
      ])
    }
    /** The most recently answered card, as one line, when no card is open. */
    const lastAnsweredLine = (row: IcRow) =>
      row.lastAnswered && !(row.cards ?? []).length ? (
        <Box key="card-answered" marginTop={1}>
          <Text key="card-answered-text" wrap="truncate-end" dimColor>
            {fit(`last answered: ${row.lastAnswered.id} · ${row.lastAnswered.answer}`, columns - CARD_FRAME)}
          </Text>
        </Box>
      ) : undefined

    // The wait part of the counts line, without its "oldest" part when the whole line would not fit the pane.
    const countsWait = (p: HeaderParts) =>
      p.waitShort !== undefined && W(`${p.ics} · ${p.wait} · ${p.workflows}`) > columns ? p.waitShort : p.wait

    return (
      <Box flexDirection="column">
        <Box key="head" flexDirection="row" justifyContent="space-between">
          <Text>
            <Text bold>FLEET</Text>
            <Text dimColor> · read-only · /fleet opens it</Text>
          </Text>
          <Text dimColor>{`${hhmm(now)} · refreshed ${refreshedAgo(now, b.refreshedAt)}`}</Text>
        </Box>
        <Box key="keys" flexDirection="row" flexWrap="wrap">
          {isFocused ? <Text dimColor>{legend}</Text> : <Text color={AMBER}>{legend}</Text>}
        </Box>
        {b.problem && <Text color="error">{b.problem}</Text>}
        <Box key="counts" marginTop={1}>
          {b.parts ? (
            <Text>
              {`${b.parts.ics} · `}
              <Text color={b.parts.waiting > 0 ? AMBER : undefined}>{countsWait(b.parts)}</Text>
              {` · ${b.parts.workflows}`}
            </Text>
          ) : (
            <Text>{b.header}</Text>
          )}
        </Box>
        {b.parts && b.rows.length === 0 && <Text dimColor>no IC sessions with a STATE.md, and no lead-1 workflow today</Text>}
        {b.rows.map(row => {
          const isSelected = row === shown
          // While a card is open every row is one line, so the card starts high in the pane.
          return (
            <Box
              key={`row-${row.letter}`}
              flexDirection="row"
              marginTop={isCardOpen ? 0 : 1}
              backgroundColor={isSelected ? '#262E3A' : undefined}
            >
              <Text color={AMBER}>{isSelected ? '▌' : ' '}</Text>
              {row.kind === 'ic' && (
                <Box key={`done-${row.letter}`} width={DONE_MARK} flexShrink={0}>
                  <Text color={DONE_COLOUR[row.done.kind]}>{doneGlyph(row.done)}</Text>
                </Box>
              )}
              {row.kind === 'lead' && <Box key={`done-${row.letter}`} width={DONE_MARK} flexShrink={0} />}
              {row.kind === 'lead' ? (
                <Box flexDirection="column">
                  <Button key={row.letter} hotkey={row.letter} plain label={`${row.name} · lead session · ${row.status}`} onPress={press(row)}>
                    <Text bold>{row.name}</Text>
                    {` · ${fit('lead session', icRest(row.name, ' · ', ' · ', row.status))} · `}
                    <Text color={row.status === 'busy' ? BLUE : undefined} dimColor={row.status !== 'busy'}>
                      {row.status}
                    </Text>
                  </Button>
                  {!isCardOpen && (
                    <Box key={`more-${row.letter}`} flexDirection="column" paddingLeft={ROW_INDENT}>
                      <Text wrap="truncate-end" color={AMBER}>
                        {waitLine(row)}
                      </Text>
                    </Box>
                  )}
                </Box>
              ) : row.kind === 'ic' ? (
                <Box flexDirection="column">
                  <Button key={row.letter} hotkey={row.letter} plain label={icLine(row)} onPress={press(row)}>
                    <Text bold>{row.name}</Text>
                    {` · ${fit(row.rung, icRest(row.name, ' · ', ' · ', row.status))} · `}
                    <Text color={row.status === 'busy' ? BLUE : undefined} dimColor={row.status !== 'busy'}>
                      {row.status}
                    </Text>
                  </Button>
                  {!isCardOpen && (
                    <Box key={`more-${row.letter}`} flexDirection="column" paddingLeft={ROW_INDENT}>
                      {(row.cards ?? []).length ? (
                        <Text wrap="truncate-end" color={AMBER}>
                          {waitLine(row)}
                        </Text>
                      ) : row.unreadable !== undefined ? (
                        <Text wrap="truncate-end" dimColor>
                          {fit(`STATE.md unreadable: ${row.unreadable}`, icRest())}
                        </Text>
                      ) : row.waiting.kind === 'none' ? (
                        <Text wrap="truncate-end" dimColor>
                          {lastLine(row)}
                        </Text>
                      ) : (
                        <Text wrap="truncate-end" color={row.waiting.kind === 'owner' ? AMBER : undefined}>
                          {waitLine(row)}
                        </Text>
                      )}
                    </Box>
                  )}
                </Box>
              ) : (
                workflowButton(row)
              )}
            </Box>
          )
        })}
        {shown?.kind === 'workflow' && (
          <Box key="card" flexDirection="column" marginTop={1} borderStyle="single" borderColor={AMBER} paddingX={1}>
            {cardHead(`${shown.letter} · workflow ${shown.name}`)}
            {cardPlain('agents', 'agents', `${count(shown.returned)} of ${count(shown.started)} returned`)}
            {cardPlain('started', 'started', hhmm(shown.startedAt))}
            {cardPlain('status', 'status', workflowEnd(shown))}
            {cardPlain('run', 'run id', shown.id)}
            {cardPlain('journal', 'journal', shown.journal)}
          </Box>
        )}
        {shown?.kind === 'lead' && (
          <Box key="card" flexDirection="column" marginTop={1} borderStyle="single" borderColor={AMBER} paddingX={1}>
            {decisionCards(shown)}
          </Box>
        )}
        {shown?.kind === 'ic' && (
          <Box key="card" flexDirection="column" marginTop={1} borderStyle="single" borderColor={AMBER} paddingX={1}>
            {decisionCards(shown)}
            {(shown.cards ?? []).length ? rule('card-rule') : undefined}
            {(shown.cards ?? []).length ? (
              <Text key="card-state-title" bold color={AMBER}>
                {`${shown.letter} · ${shown.name}${waitTitle(shown)}`}
              </Text>
            ) : (
              cardHead(`${shown.letter} · ${shown.name}${waitTitle(shown)}`)
            )}
            <Text key="card-done" wrap="truncate-end" color={DONE_COLOUR[shown.done.kind]}>
              {fit(doneLine(shown.done), columns - CARD_FRAME)}
            </Text>
            <Text key="card-updated" dimColor>
              {`updated ${shown.card.updated}${shown.updatedAt === null ? '' : ` · ${age(now - shown.updatedAt)} ago`}`}
            </Text>
            {cardField('stop', shown.card.stop)}
            {cardField('next', shown.card.next)}
            {cardNewest(shown.card.newestFile)}
            {cardField('awaiting', shown.card.awaiting)}
            {lastAnsweredLine(shown)}
          </Box>
        )}
      </Box>
    )
  })
}
