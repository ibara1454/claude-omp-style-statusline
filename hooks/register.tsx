import type { On } from 'claude-code'
import { modelLabel } from './statusline.js'

export function register(on: On) {
  let label = ''

  on('session.start', { surface: 'terminal' }, async ($, e, next) => {
    label = modelLabel(await $.session.model())
    $.ui.invalidate('ui.render')
    return next(e)
  })

  on('classic.PostModelSwitch', ($, e, next) => {
    label = modelLabel(e.to_model)
    $.ui.invalidate('ui.render')
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt', surface: 'terminal' }, ($, e, next) => {
    if (!label || e.props.hasSurvey) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return <Box width={e.props.bodyColumns} height={1}><Text wrap="truncate-end">{label}</Text></Box>
  })
}
