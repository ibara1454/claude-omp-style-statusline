import { expect, mock, test } from 'claude-code/testing'

for (const [version, component, configured] of [
  ['2.1.332', 'StatusLine', false], ['2.1.332', 'StatusLine', true], ['2.1.329', 'PromptHint', true],
] as const) {
  test(`colored footer on ${version}, native status command ${configured ? 'configured' : 'absent'}`, async ($, on) => {
    const clock = mock.clock(on)
    const startupCommands: string[] = []
    on('command.run', (_$, e) => {
      startupCommands.push(e.command)
      return {}
    })
    on('session.version', () => ({ value: { version } }))
    on('session.model', () => ({ value: 'model-alpha' }))
    on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200_000, percent: 32 }, rateLimits: [] } }))
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    mock.env(on, { HOME: '/home/dev' })
    on('process.run', () => ({ value: { exitCode: 0, stdout: '# branch.head main\0', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
    on('session.append', (_$, e, next) => next(e))
    await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/home/dev/test' })
    await clock.settle()
    expect(startupCommands).toEqual([])
    const target = { plugin: 'omp-style-statusline', surface: 'terminal', viewport: { columns: 100, rows: 30 } } as const
    const status = component === 'StatusLine'
      ? await $.ui.mount({ ...target, component, props: { text: null, isManaged: false, isWorking: false, maxRows: 2, columns: 96 } })
      : undefined
    const mounted = status ?? await $.ui.mount({ ...target, component: 'PromptHint', props: { isDraft: false, isWorking: false, hint: '? for shortcuts' } })
    const model = await mounted.find({ type: 'Text', text: /^model-alpha$/ })
    expect(model?.props.color).toBe('#af5fff')
    expect(model?.props.backgroundColor).toBe('#121212')
    expect(await mounted.find({ type: 'Text', text: /^📁 ~\/test$/ })).toBeDefined()
    expect(await mounted.find({ type: 'Text', text: /^⑂ main$/ })).toBeDefined()
    expect(await mounted.find({ type: 'Text', text: '32%' })).toBeDefined()
    expect(await mounted.find({ type: 'Text', text: '◌ unknown' })).toBeDefined()
    expect(await mounted.keepsBeneath()).toBe(true)
    if (configured && status) {
      await status.redraw({ text: 'native', isManaged: false, isWorking: false, maxRows: 2, columns: 96 })
      expect(await mounted.find({ type: 'Text', text: /^model-alpha$/ })).toBeDefined()
      expect(await mounted.keepsBeneath()).toBe(true)
    }
    for (const [index, text] of ['<command-name>/effort</command-name>', '<local-command-stdout>Set effort level to high</local-command-stdout>'].entries()) {
      await $.session.append({ door: 'command', uuid: `picker-${index}`, origin: { kind: 'unclassified' }, message: { type: 'user', content: [{ type: 'text', text }] } })
    }
    expect(await mounted.find({ type: 'Text', text: /^◑ high$/ })).toBeDefined()
    expect(await mounted.find({ type: 'Text', text: '◌ unknown' })).toBeUndefined()
    await mounted.unmount()
  })
}
