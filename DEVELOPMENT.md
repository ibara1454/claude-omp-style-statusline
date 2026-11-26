# Development

Build tools: MoonBit `0.10.21+06da1ed44` · GNU Make · Node.js with npm · Claude Code `2.1.332`.

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | SHELL=/bin/false bash -s -- '0.10.21+06da1ed44'
export PATH="$HOME/.moon/bin:$PATH"
npm install
make build    # regenerate hooks/statusline.js
make check    # verify the shipped module and run checks
```

The first build fetches MoonBit packages; the type check fetches [Claude’s declarations](https://github.com/anthropics/claude-code/blob/v2.1.332/mods/types/claude-code.d.ts). The plugin runs offline.

`make check` covers MoonBit (90% minimum coverage), Git integration, types, lint, plugin validation and footer mount tests.

**Live check:** from this checkout, run `claude --plugin-dir .` in a color-capable terminal. Check the purple model chip, dark chip background and contrasting gauge below the prompt. Narrow the terminal and check the row again on its next refresh.

[Terminal footer](hooks/register.tsx) · [MoonBit layout](core/layout.mbt) · [Original OMP layout](https://github.com/can1357/oh-my-pi/blob/v19.0.0/packages/tui/src/status-line/component.ts)
