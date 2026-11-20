import type { ModelEffort, On, ProcessRunResult, SessionUsage } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const band = {
  plugin: 'omp-statusline',
  component: 'AbovePrompt',
  surface: 'terminal',
  viewport: { columns: 80, rows: 24 },
  props: {
    hasSurvey: false, isCollapsed: false, isWorking: false,
    maxRows: 8, bodyColumns: 75, scroll: { offset: 0, bodyRows: 7 }, view: {},
  },
} as const

function stubSession(
  on: On,
  readUsage: () => SessionUsage = () => ({ startedAt: 0, context: { window: 0 }, rateLimits: [] }),
) {
  on('session.model', () => ({ value: 'model-alpha' }))
  mock.env(on, { HOME: '/home/dev' })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('session.usage', () => ({ value: readUsage() }))
}

function gitStatus(branch: string): ProcessRunResult {
  return {
    exitCode: 0, stdout: `# branch.head ${branch}\0`, stderr: '',
    isStdoutTruncated: false, isStderrTruncated: false,
  }
}

const turn = { reason: 'answer', answer: '', durationMs: 42, isAborted: false } as const
const modelSwitch = {
  from_model: 'model-alpha', to_model: 'model-beta', requested_model: 'model-beta',
  source: 'picker', context_tokens: 0, prompt_cache_warm: false,
  cache_ttl: '5m', estimated_cache_write_usd: 0, pricing: 'default',
} as const

test('the band shows the real model and home-relative path outside a Git repository', async ($, on) => {
  stubSession(on)
  const calls: unknown[] = []
  on('process.run', (_$, e) => {
    calls.push({ argv: e.argv, cwd: e.init?.cwd })
    return { value: { ...gitStatus('irrelevant'), exitCode: 128, stderr: 'not a git repository' } }
  })
  on('classic.PostModelSwitch', () => ({}))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/acme' })

  const ui = await $.ui.mount(band)
  const model = await ui.find({ type: 'Text', text: /^◕ model-alpha$/ })
  expect(model?.props.color).toBe('#af5fff')
  expect(model?.props.backgroundColor).toBe('#121212')
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/acme$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ irrelevant$/ })).toBeUndefined()

  await $.classic.PostModelSwitch(modelSwitch)
  expect(await ui.find({ type: 'Text', text: /^◕ model-beta$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^◕ model-alpha$/ })).toBeUndefined()
  await ui.redraw({ ...band.props, bodyColumns: 12 })
  expect(await ui.drawn()).toMatchObject({ type: 'Box', props: { width: 12, height: 1 } })
  await ui.redraw()
  await ui.redraw(band.props)
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/acme$/ })).toBeDefined()
  expect(calls).toEqual([{
    argv: ['git', '--no-optional-locks', 'status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all'],
    cwd: '/home/dev/acme',
  }])
  await ui.unmount()
})

test('directory and main-turn refreshes reject stale Git results, even in the same directory', async ($, on) => {
  stubSession(on)
  const clock = mock.clock(on)
  const dirs: (string | undefined)[] = []
  on('process.run', async (_$, e) => {
    dirs.push(e.init?.cwd)
    switch (dirs.length) {
      case 1: return { value: gitStatus('initial-branch') }
      case 2:
        await clock.sleep(100)
        return { value: gitStatus('old-directory-branch') }
      case 3: return { value: gitStatus('new-directory-branch') }
      case 4:
        await clock.sleep(100)
        return { value: gitStatus('old-turn-branch') }
      case 5: return { value: gitStatus('new-turn-branch') }
      default: throw new Error('unexpected Git call')
    }
  })
  on('classic.CwdChanged', () => ({}))
  on('turn.complete', (_$, e) => ({ text: e.answer }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/start' })
  const ui = await $.ui.mount(band)
  expect(await ui.find({ type: 'Text', text: /^⑂ initial-branch$/ })).toBeDefined()

  const oldDirectory = $.classic.CwdChanged({ old_cwd: '/home/dev/start', new_cwd: '/home/dev/a' })
  await clock.settle()
  expect(dirs).toEqual(['/home/dev/start', '/home/dev/a'])
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/a$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ initial-branch$/ })).toBeUndefined()
  await $.classic.CwdChanged({ old_cwd: '/home/dev/a', new_cwd: '/home/dev/b' })
  await clock.advance(100)
  await oldDirectory
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/b$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ new-directory-branch$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ old-directory-branch$/ })).toBeUndefined()

  await $.classic.CwdChanged({ old_cwd: '/home/dev/b', new_cwd: '/home/dev/b' })
  await $.turn.complete({ ...turn, turnId: 'agent-turn', agentId: 'agent' })
  expect(dirs).toEqual(['/home/dev/start', '/home/dev/a', '/home/dev/b'])
  const oldTurn = $.turn.complete({ ...turn, turnId: 'main-1' })
  await clock.settle()
  expect(dirs).toHaveLength(4)
  await $.turn.complete({ ...turn, turnId: 'main-2' })
  await clock.advance(100)
  await oldTurn
  expect(await ui.find({ type: 'Text', text: /^⑂ new-turn-branch$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ old-turn-branch$/ })).toBeUndefined()
  expect(dirs).toEqual(['/home/dev/start', '/home/dev/a', '/home/dev/b', '/home/dev/b', '/home/dev/b'])
  await ui.unmount()
})

test('failed and truncated Git refreshes hide the segment without losing the path', async ($, on) => {
  stubSession(on)
  const status = gitStatus('counted-branch')
  const oid = '0123456789abcdef0123456789abcdef01234567'
  status.stdout += `1 M. N... 100644 100644 100644 ${oid} ${oid} staged\0`
  status.stdout += `1 .M N... 100644 100644 100644 ${oid} ${oid} worktree\0`
  status.stdout += '? a file\0? another\nfile\0'
  let run = 0
  on('process.run', () => {
    run += 1
    if (run === 2) return { value: { ...gitStatus('partial-branch'), isStdoutTruncated: true } }
    if (run === 4) return { deny: 'git could not start' }
    return { value: status }
  })
  on('turn.complete', (_$, e) => ({ text: e.answer }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/acme' })
  const ui = await $.ui.mount(band)
  for (const text of [/^⑂ counted-branch$/, /^ \*1$/, /^ \+1$/, /^ \?2$/]) {
    expect(await ui.find({ type: 'Text', text })).toBeDefined()
  }

  await $.turn.complete({ ...turn, turnId: 'truncated' })
  expect(await ui.find({ type: 'Text', text: /^⑂ counted-branch$/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /^⑂ partial-branch$/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/acme$/ })).toBeDefined()

  await $.turn.complete({ ...turn, turnId: 'restored' })
  expect(await ui.find({ type: 'Text', text: /^⑂ counted-branch$/ })).toBeDefined()
  await $.turn.complete({ ...turn, turnId: 'git-missing' })
  expect(await ui.find({ type: 'Text', text: /^⑂ counted-branch$/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /^📁 ~\/acme$/ })).toBeDefined()
  expect(run).toBe(4)
  await ui.unmount()
})

test('usage and estimated cost follow startup, measurements, model switches and compaction', async ($, on) => {
  let usage: SessionUsage = {
    startedAt: 0, context: { window: 272_000, percent: 14 }, rateLimits: [], cost: { usd: 1.04 },
  }
  let usageReads = 0
  stubSession(on, () => {
    usageReads += 1
    return usage
  })
  on('process.run', () => ({ value: gitStatus('main') }))
  on('session.measure', (_$, e) => ({ changed: e.changed }))
  on('classic.PostModelSwitch', () => ({}))
  on('classic.PostCompact', () => ({}))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/acme' })
  const ui = await $.ui.mount(band)
  for (const text of ['model-alpha', '14%', '272K', '~$1.04']) {
    expect(await ui.find({ type: 'Text', text })).toBeDefined()
  }
  expect(await ui.find({ type: 'Text', text: '(+' })).toBeUndefined()

  await $.session.measure({
    context: { window: 272_000, percent: 0 }, rateLimits: [], cost: { usd: 0 },
    changed: ['context', 'cost'],
  })
  expect(await ui.find({ type: 'Text', text: /\b0%/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '~$0.00' })).toBeDefined()
  await $.session.measure({ context: { window: 272_000 }, rateLimits: [], changed: ['context', 'cost'] })
  expect(await ui.find({ type: 'Text', text: '272K' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /\d+%|~\$/ })).toBeUndefined()

  usage = { ...usage, context: { window: 1_000_000, percent: 4 } }
  await $.classic.PostModelSwitch(modelSwitch)
  expect(await ui.find({ type: 'Text', text: 'model-beta' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '1M' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /\b4%/ })).toBeDefined()

  usage = { ...usage, context: { window: 1_000_000 }, cost: { usd: 1.23 } }
  await $.classic.PostCompact({ trigger: 'manual', compact_summary: 'summary' })
  await ui.redraw()
  expect(await ui.find({ type: 'Text', text: '1M' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '~$1.23' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /\d+%/ })).toBeUndefined()
  expect(usageReads).toBe(3)
  await ui.unmount()
})

test('the model chip tracks main-thread effort without borrowing a subagent level', async ($, on) => {
  stubSession(on)
  on('process.run', () => ({ value: gitStatus('main') }))
  on('tool.check', { tool: 'Bash' }, () => ({ decision: 'ask' }))
  on('turn.step', async function* (_$, e) {
    yield { kind: 'text', index: 0, text: 'answer' }
    return { turnId: e.turnId, index: e.index, answer: 'answer', toolUses: [], stopReason: null, usage: null }
  })
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/acme' })
  const ui = await $.ui.mount(band)
  const chip = (text: string) => ui.find({ type: 'Text', text: new RegExp(`^◕ model-alpha${text}$`) })
  async function step(effort?: ModelEffort, agentId?: string) {
    const chunks = []
    for await (const chunk of $.turn.step({ turnId: agentId ?? 'main', index: 0, model: 'model-alpha', messageCount: 1, effort, agentId })) {
      if (chunk.kind === 'text') chunks.push(chunk.text)
    }
    expect(chunks).toEqual(['answer'])
  }
  expect(await chip('')).toBeDefined()
  await step('medium')
  expect(await chip(' \\(medium\\)')).toBeDefined()
  await step('low', 'child')
  expect(await chip(' \\(medium\\)')).toBeDefined()
  await step('xhigh')
  await ui.redraw({ ...band.props, bodyColumns: 12 })
  expect(await chip(' \\(xhigh\\)')).toBeUndefined()
  await ui.redraw(band.props)
  expect(await chip(' \\(xhigh\\)')).toBeDefined()
  await step()
  expect(await chip('')).toBeDefined()
  await ui.unmount()
})

test('idle effort follows the allowed host reading, not the requested level or previous model', async ($, on) => {
  stubSession(on)
  on('process.run', () => ({ value: gitStatus('main') }))
  let decision: 'allow' | 'deny' = 'allow'
  let level = 'low'
  let reads = 0
  on('tool.check', { tool: 'Bash' }, (_$, e) => {
    expect(e.input).toEqual({ command: 'printenv CLAUDE_EFFORT' })
    return { decision }
  })
  on('tool.call', { tool: 'Bash' }, (_$, e) => {
    expect(e.command).toBe('printenv CLAUDE_EFFORT')
    reads++
    return { result: level, text: level }
  })
  on('command.run', { command: 'effort' }, () => {
    level = 'high' // The host capped the requested max.
    return {}
  })
  on('classic.PostModelSwitch', () => ({}))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/acme' })
  const ui = await $.ui.mount(band)
  expect(await ui.find({ type: 'Text', text: /^◕ model-alpha \(low\)$/ })).toBeDefined()
  await $.command.run({
    command: 'effort', args: 'max', origin: { kind: 'composer' },
    presentation: { columns: 80, isFullscreen: false },
  })
  expect(await ui.find({ type: 'Text', text: /^◕ model-alpha \(high\)$/ })).toBeDefined()
  await ui.redraw()
  expect(reads).toBe(2)
  decision = 'deny'
  await $.classic.PostModelSwitch(modelSwitch)
  expect(await ui.find({ type: 'Text', text: /^◕ model-beta$/ })).toBeDefined()
  expect(reads).toBe(2)
  await ui.unmount()
})
