import type { EngineInterface, On, SessionUsage } from 'claude-code'
import { formatPath, parseStatus, renderRow } from './statusline.js'

type GitSnapshot = { generation: number; segments: string[] }
type UsageSnapshot = { generation: number; percent: number; window: number; costUsd: number }
type EffortSnapshot = { generation: number; level: string }

async function refreshGit($: EngineInterface, directory: string, git: GitSnapshot) {
  const generation = ++git.generation
  const status = await $.process.run([
    'git', '--no-optional-locks', 'status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all',
  ], { cwd: directory }).catch(() => undefined)
  if (generation !== git.generation) return

  git.segments = status?.exitCode === 0 && !status.isStdoutTruncated && !status.isStderrTruncated
    ? parseStatus(status.stdout)
    : []
  $.ui.invalidate('ui.render')
}

function cacheUsage(usage: UsageSnapshot, { context, cost }: Pick<SessionUsage, 'context' | 'cost'>) {
  usage.percent = context.percent ?? -1
  usage.window = context.window
  usage.costUsd = cost?.usd ?? -1
}

async function refreshUsage($: EngineInterface, usage: UsageSnapshot) {
  const generation = ++usage.generation
  const reading = await $.session.usage()
  if (generation !== usage.generation) return
  cacheUsage(usage, reading)
  $.ui.invalidate('ui.render')
}

async function refreshEffort($: EngineInterface, effort: EffortSnapshot) {
  const generation = ++effort.generation
  const command = 'printenv CLAUDE_EFFORT'
  let level = ''
  try {
    // Claude sets this in Bash's environment, not the mod process's. Never turn an ask into an allow.
    const { decision } = await $.tool.check({ tool: 'Bash', input: { command } })
    if (decision === 'allow' && generation === effort.generation) {
      const result = await $.tool.call({ tool: 'Bash', command })
      const text = result.text?.trim()
      if (!result.isError && text && /^(low|medium|high|xhigh|max)$/.test(text)) level = text
    }
  } catch {
    // Bash may be unavailable. The next main turn supplies effort without a tool.
  }
  if (generation === effort.generation && effort.level !== level) {
    effort.level = level
    $.ui.invalidate('ui.render')
  }
}

export function register(on: On) {
  let model: string | undefined
  const effort: EffortSnapshot = { generation: 0, level: '' }
  let cwd: string | undefined
  let home = ''
  let path = ''
  const git: GitSnapshot = { generation: 0, segments: [] }
  const usage: UsageSnapshot = { generation: 0, percent: -1, window: 0, costUsd: -1 }

  on('session.start', { surface: 'terminal' }, async ($, e, next) => {
    cwd = e.cwd
    const vcsAndEffort = Promise.all([refreshGit($, cwd, git), refreshEffort($, effort)])
    const [activeModel, userHome] = await Promise.all([
      $.session.model(), $.env.get('HOME'), refreshUsage($, usage),
    ])
    model ??= activeModel
    home = userHome ?? ''
    path = formatPath(cwd, home)
    $.ui.invalidate('ui.render')
    await vcsAndEffort
    return next(e)
  })

  on('classic.CwdChanged', async ($, e, next) => {
    if (cwd !== undefined && e.agent_id === undefined && cwd !== e.new_cwd) {
      cwd = e.new_cwd
      path = formatPath(cwd, home)
      git.segments = []
      $.ui.invalidate('ui.render')
      await refreshGit($, cwd, git)
    }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (cwd !== undefined && e.agentId === undefined) await refreshGit($, cwd, git)
    return next(e)
  })

  on('session.measure', ($, e, next) => {
    if (cwd !== undefined) {
      // A pushed measurement supersedes any plain usage read still in flight.
      usage.generation += 1
      cacheUsage(usage, e)
      $.ui.invalidate('ui.render')
    }
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (cwd !== undefined && e.agentId === undefined) {
      effort.generation++
      const level = e.effort?.toString() ?? ''
      if (effort.level !== level) {
        effort.level = level
        $.ui.invalidate('ui.render')
      }
    }
    return yield* next(e)
  })

  on('command.run', { command: /^(effort|model)$/ }, async ($, e, next) => {
    const result = await next(e)
    if (cwd !== undefined && !(e.command === 'effort' && e.args.trim() === 'status')) {
      await refreshEffort($, effort)
    }
    return result
  })

  on('classic.PostModelSwitch', async ($, e, next) => {
    if (cwd !== undefined && e.agent_id === undefined) {
      model = e.to_model
      effort.level = ''
      usage.percent = -1
      usage.window = 0
      await Promise.all([refreshUsage($, usage), refreshEffort($, effort)])
    }
    return next(e)
  })

  on('classic.PostCompact', async ($, e, next) => {
    if (cwd !== undefined && e.agent_id === undefined) await refreshUsage($, usage)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt', surface: 'terminal' }, ($, e, next) => {
    if (!model || e.props.hasSurvey) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    const columns = e.props.bodyColumns
    const spans = renderRow(columns, model, effort.level, path, git.segments, usage.percent, usage.window, usage.costUsd)
    const children = []
    for (let i = 0; i < spans.length; i += 3) {
      children.push(
        <Text key={String(i)} color={spans[i + 1]} backgroundColor={spans[i + 2] || undefined} wrap="truncate-end">
          {spans[i]}
        </Text>,
      )
    }
    return <Box width={columns} height={1} flexDirection="row" flexWrap="nowrap">{children}</Box>
  })
}
