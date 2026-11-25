import type { EngineInterface, On, SessionUsage } from 'claude-code'
import { formatPath, parseStatus, renderRow } from './statusline.js'

type Git = { generation: number; segments: string[] }
type Usage = Pick<SessionUsage, 'context' | 'cost'> & { generation: number }

async function refreshGit($: EngineInterface, cwd: string, git: Git) {
  const generation = ++git.generation
  const r = await $.process.run(['git', '--no-optional-locks', 'status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all'], { cwd }).catch(() => undefined)
  if (git.generation !== generation) return
  git.segments = r?.exitCode === 0 && !r.isStdoutTruncated && !r.isStderrTruncated ? parseStatus(r.stdout) : []
  $.ui.invalidate('ui.render')
}

async function refreshUsage($: EngineInterface, usage: Usage) {
  const generation = ++usage.generation
  const r = await $.session.usage()
  if (usage.generation !== generation) return
  usage.context = r.context
  usage.cost = r.cost
  $.ui.invalidate('ui.render')
}

function confirmedEffort(command: string, output: string) {
  const match = command === 'model'
    ? /^Set model to `[^`]+`[^`\n]*?(?: with `| · effort stays )(\w+)(?:` effort\b| \(set by )/.exec(output)
    : /^Set effort level to (\w+)\b/.exec(output)
      ?? /^Effort '[^']+' exceeds the cap[^;\n]*; set to '(\w+)' instead\b/.exec(output)
      ?? /^(?:Not applied: )?CLAUDE_CODE_EFFORT_LEVEL=(\w+) overrides\b/.exec(output)
      ?? /^Current effort level: (\w+)\b/.exec(output)
      ?? /^Effort level: auto \(currently (\w+)\)/.exec(output)
      ?? /^Effort level(?: set to|:) (auto)\b/.exec(output)
  const level = match?.[1]
  if ((!level && command === 'model' && output.startsWith('Set model to ')) || level === 'auto' || level === 'unset') return ''
  return level && /^(low|medium|high|xhigh|max)$/.test(level) ? level : undefined
}

export function register(on: On) {
  let cwd: string | undefined
  let home = ''
  let path = ''
  let model = ''
  let effort = ''
  let pendingCommand: string | undefined
  let keepPickedEffort = false
  let useHint = false
  const git: Git = { generation: 0, segments: [] }
  const usage: Usage = { generation: 0, context: { window: 0 } }

  on('session.start', { surface: 'terminal' }, async ($, e, next) => {
    cwd = e.cwd
    const [activeModel, userHome, release] = await Promise.all([
      $.session.model(), $.env.get('HOME'), $.session.version(), refreshGit($, cwd, git), refreshUsage($, usage),
    ])
    const patch = /^2\.1\.(\d+)/.exec(release.version)
    useHint = !!patch && Number(patch[1]) < 332
    model ||= activeModel
    home = userHome ?? ''
    path = formatPath(cwd, home)
    $.ui.invalidate('ui.render')
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
      usage.generation++
      usage.context = e.context
      usage.cost = e.cost
      $.ui.invalidate('ui.render')
    }
    return next(e)
  })

  on('classic.PostModelSwitch', async ($, e, next) => {
    if (cwd !== undefined && e.agent_id === undefined) {
      model = e.to_model
      effort = ''
      await refreshUsage($, usage)
    }
    return next(e)
  })

  on('classic.PostCompact', async ($, e, next) => {
    if (cwd !== undefined && e.agent_id === undefined) await refreshUsage($, usage)
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (cwd !== undefined && e.agentId === undefined && (e.index === 0 || !keepPickedEffort)) {
      keepPickedEffort = false
      const level = e.effort?.toString() ?? ''
      if (effort !== level) {
        effort = level
        $.ui.invalidate('ui.render')
      }
    }
    return yield* next(e)
  })

  on('session.append', { door: 'command' }, ($, e, next) => {
    const block = e.message.content[0]
    if (cwd !== undefined && e.agentId === undefined && block?.type === 'text' && typeof block.text === 'string') {
      if (block.text.startsWith('<command-name>')) {
        pendingCommand = /^<command-name>\/(effort|model)<\/command-name>/.exec(block.text)?.[1]
      } else if (pendingCommand) {
        const output = /^<local-command-stdout>([\s\S]*)<\/local-command-stdout>$/.exec(block.text)?.[1]
        if (output !== undefined) {
          const level = confirmedEffort(pendingCommand, output)
          pendingCommand = undefined
          if (level !== undefined) {
            effort = level
            keepPickedEffort = true
            $.ui.invalidate('ui.render')
          }
        }
      }
    }
    return next(e)
  })

  on('ui.render', { component: ['StatusLine', 'PromptHint'], surface: 'terminal' }, async ($, e, next) => {
    if (!model || (e.component === 'PromptHint') !== useHint) return next(e)
    if (e.component === 'StatusLine' && e.props.maxRows < 1) return next(e)
    const columns = e.component === 'StatusLine' ? e.props.columns : (e.viewport?.columns ?? 80) - 4
    const spans = renderRow(columns, model, effort || '◌ unknown', path, git.segments, usage.context.percent ?? -1, usage.context.window, usage.cost?.usd ?? -1)
    if (!spans.length) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    const children = []
    for (let i = 0; i < spans.length; i += 3) {
      children.push(<Text key={String(i)} color={spans[i + 1]} backgroundColor={spans[i + 2] || undefined} wrap="truncate-end">{spans[i]}</Text>)
    }
    const row = <Box flexDirection="row" height={1} width={columns} flexWrap="nowrap">{children}</Box>
    // Keep the native command or prompt hints below our row when the host has room.
    return <Box flexDirection="column">{row}{await next(e)}</Box>
  })
}
