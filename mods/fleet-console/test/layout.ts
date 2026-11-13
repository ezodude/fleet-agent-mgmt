// The board's tree from the test kit, laid out as text: a small approximation of a terminal box layout
// (column/row, padding, border, marginTop, space-between, wrap/truncate). Not the engine's paint.
// Used by the render regression test: every snapshot in fixtures/invented/baseline/ is this text.

const W = (s: string) => Array.from(s).length
const cut = (s: string, n: number) => (W(s) <= n ? s : n < 1 ? '' : `${Array.from(s).slice(0, n - 1).join('')}…`)
const pad = (s: string, n: number) => s + ' '.repeat(Math.max(0, n - W(s)))

function inline(n: any): string {
  if (n === null || n === undefined || n === false || n === true) return ''
  if (typeof n === 'string' || typeof n === 'number') return String(n)
  if (n.type === 'Text' && typeof n.text === 'string' && !(n.children ?? []).some((c: any) => typeof c === 'object' && c)) return n.text
  return (n.children ?? []).map(inline).join('')
}

function wrap(s: string, width: number, truncate: boolean): string[] {
  const out: string[] = []
  for (const para of s.split('\n')) {
    if (truncate) {
      out.push(cut(para, width))
      continue
    }
    let line = ''
    for (const word of para.split(' ')) {
      let w = word
      const next = line === '' ? w : `${line} ${w}`
      if (W(next) <= width) {
        line = next
        continue
      }
      if (line !== '') out.push(line)
      while (W(w) > width) {
        out.push(Array.from(w).slice(0, width).join(''))
        w = Array.from(w).slice(width).join('')
      }
      line = w
    }
    out.push(line)
  }
  return out
}

const kids = (n: any) => (n.children ?? []).filter((c: any) => c !== null && c !== undefined && c !== false && c !== true && c !== '')

function lay(n: any, width: number): string[] {
  if (typeof n === 'string' || typeof n === 'number') return wrap(String(n), width, false)
  if (!n || typeof n !== 'object') return []
  const p = n.props ?? {}
  if (n.type === 'Text' && inline(n) !== '' && inline(n).trim() === '') return [inline(n)]
  if (n.type === 'Text') return wrap(inline(n), width, typeof p.wrap === 'string' && p.wrap.startsWith('truncate'))
  if (n.type === 'Button') {
    const body = kids(n).length ? inline(n) : String(p.label ?? '')
    return wrap(`${p.hotkey ? `${p.hotkey}: ` : ''}${body}`, width, false)
  }
  // Box
  const outer = typeof p.width === 'number' ? Math.min(p.width, width) : width
  const border = p.borderStyle ? 1 : 0
  const padL = p.paddingLeft ?? p.paddingX ?? 0
  const padR = p.paddingRight ?? p.paddingX ?? 0
  const inner = Math.max(1, outer - 2 * border - padL - padR)
  const cs = kids(n)
  let lines: string[] = []
  if ((p.flexDirection ?? 'row') === 'column') {
    for (const c of cs) {
      const mt = (typeof c === 'object' && c.props?.marginTop) || 0
      for (let i = 0; i < mt; i++) lines.push('')
      lines.push(...lay(c, inner))
    }
  } else if (cs.length <= 1) {
    lines = cs.length ? lay(cs[0], inner) : ['']
  } else if (p.justifyContent === 'space-between' && cs.length === 2) {
    const right = lay(cs[1], inner)
    const rw = Math.max(...right.map(W))
    const left = lay(cs[0], W(lay(cs[0], 10_000)[0] ?? '') + rw + 1 <= inner ? inner : Math.max(1, inner - rw - 1))
    const lw = Math.max(...left.map(W))
    const gap = Math.max(1, inner - lw - rw)
    for (let i = 0; i < Math.max(left.length, right.length); i++) lines.push(pad(left[i] ?? '', lw) + ' '.repeat(gap) + (right[i] ?? ''))
  } else {
    // Row: a child with a width takes it; the others take what they need of what is left, the last the rest.
    const fixed = cs.map((c: any) => (typeof c === 'object' && typeof c.props?.width === 'number' ? c.props.width : 0))
    const cols: string[][] = []
    const widths: number[] = []
    let used = 0
    cs.forEach((c: any, i: number) => {
      const room = Math.max(1, inner - used - fixed.slice(i + 1).reduce((a: number, b: number) => a + b, 0))
      const l = lay(c, fixed[i] || room)
      const w = fixed[i] || Math.min(room, Math.max(0, ...l.map(W)))
      cols.push(l)
      widths.push(w)
      used += w
    })
    const h = Math.max(...cols.map(c => c.length))
    for (let r = 0; r < h; r++) lines.push(cols.map((c, i) => pad(c[r] ?? '', widths[i]!)).join('').replace(/\s+$/, ''))
  }
  lines = lines.map(l => ' '.repeat(padL) + l)
  if (border) {
    const w = outer - 2
    lines = [`┌${'─'.repeat(w)}┐`, ...lines.map(l => `│${pad(l, w)}│`), `└${'─'.repeat(w)}┘`]
  }
  return lines
}

/** The Texts that carry a colour or a weight, so the text render keeps what colour it loses. */
function styles(n: any, out: string[] = []): string[] {
  if (!n || typeof n !== 'object') return out
  const p = n.props ?? {}
  const marks = [p.color && `color=${p.color}`, p.dimColor && 'dim', p.bold && 'bold', p.backgroundColor && `bg=${p.backgroundColor}`, p.borderColor && `border=${p.borderColor}`].filter(Boolean)
  if (marks.length && (n.type === 'Text' || p.backgroundColor || p.borderColor)) {
    const t = n.type === 'Text' ? inline(n) : `<${n.type} key=${n.key ?? p.key ?? ''}>`
    if (t.trim() !== '') out.push(`${marks.join(',')}: ${cut(t.replace(/\n/g, '⏎'), 110)}`)
  }
  for (const c of n.children ?? []) styles(c, out)
  return out
}

/** One snapshot: the tree laid out at `cols` body columns, framed, then the styled Texts. Ends with a newline. */
export function snapshot(tree: any, cols: number, state: string): string {
  const body = lay(tree, cols)
  const over = body.filter(l => W(l) > cols).length
  return [
    `# fleet-console board, test-kit tree laid out as text (an approximation, not the engine's paint)`,
    `# body columns ${cols}, state ${state}, input: invented fixtures, clock 2026-10-21 16:55 BST + 3 s`,
    `# ${body.length} lines, ${over} wider than the body; the | marks the body's right edge`,
    `+${'-'.repeat(cols)}+`,
    ...body.map(l => `|${pad(l, cols)}|`),
    `+${'-'.repeat(cols)}+`,
    '',
    '# styles (colour keys: warning = amber, suggestion = blue, success = green)',
    ...styles(tree),
    '',
  ].join('\n')
}

export const WIDTHS = [180, 120, 81, 54] as const
