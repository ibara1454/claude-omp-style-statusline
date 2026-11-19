import { expect, test } from 'claude-code/testing'

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

test('the band shows the session model and follows a model switch', async ($, on) => {
  on('session.model', () => ({ value: 'model-alpha' }))
  on('session.start', () => ({ cwd: '/work' }))
  on('classic.PostModelSwitch', () => ({}))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

  const ui = await $.ui.mount(band)
  expect(await ui.find({ type: 'Text', text: /model-alpha/ })).toBeDefined()

  await $.classic.PostModelSwitch({
    from_model: 'model-alpha', to_model: 'model-beta', requested_model: 'model-beta',
    source: 'picker', context_tokens: 0, prompt_cache_warm: false,
    cache_ttl: '5m', estimated_cache_write_usd: 0, pricing: 'default',
  })
  expect(await ui.find({ type: 'Text', text: /model-beta/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /model-alpha/ })).toBeUndefined()
  await ui.unmount()
})
