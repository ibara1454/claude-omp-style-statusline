# Development

Build tools: MoonBit `0.10.21+06da1ed44` · GNU Make · Node.js · Bun `1.4.4` · Claude Code `2.1.328`.

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | SHELL=/bin/false bash -s -- '0.10.21+06da1ed44'
export PATH="$HOME/.moon/bin:$PATH"
bun install --frozen-lockfile
make build    # regenerate hooks/statusline.js
make check    # verify the shipped module and run checks
```

The first build fetches MoonBit packages; the type check fetches [Claude’s declarations](https://github.com/anthropics/claude-code/blob/v2.1.328/mods/types/claude-code.d.ts). The plugin runs offline.

`make check` covers MoonBit (90% minimum coverage), Git integration, types, lint, plugin validation and terminal mount tests.

**Live check:** launch `claude` on the intended host. Change effort for this session, then narrow and widen the terminal. The effort label should return before the model; subagent turns shouldn’t change it. Check the native footer there too.

[Session hooks](hooks/register.tsx) · [MoonBit layout](core/layout.mbt) · [Original OMP layout](https://github.com/can1357/oh-my-pi/blob/v19.0.0/packages/tui/src/status-line/component.ts)
