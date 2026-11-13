/**
 * Whom an IC waits on, from its STATE.md "awaiting:" line: `owner:` waits on the owner, `lead-1:` or an IC's name
 * on someone else, `none` on nobody. A line in the old free-text form is `old`, kept as written.
 */
export type Awaiting =
  | { kind: 'none' }
  | { kind: 'owner'; rest: string }
  | { kind: 'who'; who: string; rest: string }
  | { kind: 'old'; text: string }

/**
 * Whether an IC's rung is finished, from the record folder its STATE.md "handoff:" line points into:
 * `done` when close.md is listed there (with close.md's time when the listing gives one), `open` when the folder
 * is listed with no close.md, `unknown` when the handoff is not in a record folder or the folder cannot be listed.
 */
export type Done =
  | { kind: 'done'; folder: string; closedAt?: number }
  | { kind: 'open'; folder: string }
  | { kind: 'unknown' }

export type IcRow = {
  kind: 'ic'
  letter: string
  name: string
  pane?: string
  status: string
  rung: string
  /** The "awaiting:" line as written. */
  needsYou: string
  waiting: Awaiting
  updated: string
  updatedAt: number | null
  /** Why STATE.md could not be read; the row then shows "-" for what it holds. */
  unreadable?: string
  done: Done
  card: { stop: string; awaiting: string; next: string; updated: string; newestFile: string }
  /** lead-1's open decision cards for this IC, newest first; absent when there are none. */
  cards?: DecisionCard[]
  /** lead-1's most recently answered decision card for this IC, by file time; absent when there is none. */
  lastAnswered?: DecisionCard
}

/**
 * One decision card lead-1 sent the owner, from `checks/lead-1/cards/<slug>.md`: a header of `key: value` lines,
 * a line `---`, then the card's body exactly as sent.
 */
export type DecisionCard = {
  file: string
  mtimeMs: number
  id: string
  /** The board row the card is about: an IC's name, or lead-1. */
  row: string
  status: 'open' | 'answered'
  /** As written, "YYYY-MM-DD HH:MM <zone>". */
  since: string
  sinceAt: number | null
  /** The session whose pane the owner types the reply in. */
  where: string
  /** The replies the owner can type, as written: alternatives separated by " | ". */
  reply: string
  /** "-" while open; the owner's words and the time once answered. */
  answer: string
  body: string
}

/** lead-1's own row: drawn only while lead-1 has an open decision card for row lead-1. */
export type LeadRow = {
  kind: 'lead'
  letter: string
  name: string
  status: string
  cards: DecisionCard[]
  lastAnswered?: DecisionCard
}

export type WorkflowRow = {
  kind: 'workflow'
  letter: string
  name: string
  id: string
  started: number
  returned: number
  startedAt: number
  doneAt?: number
  journal: string
}

export type Row = IcRow | WorkflowRow | LeadRow

export type HeaderParts = { ics: string; wait: string; waitShort?: string; waiting: number; workflows: string }

export type Board = { rows: Row[]; header: string; parts?: HeaderParts; refreshedAt: number; problem?: string }

declare module 'claude-code' {
  interface PluginState {
    'fleet-console': { board: Board; selected: string; tick: number }
  }
}
