# MoonBit statusline for Claude Code

From this checkout, run `claude-codex --plugin-dir .`. No rebuild or installation is needed to load the mod. The milestone 1 row shows only the active model, immediately above the terminal input. It does not replace or configure the native footer.

`hooks/register.tsx` reads `$.session.model()` at session start and updates the label on `classic.PostModelSwitch`. `core/model.mbt` formats the label; `hooks/statusline.js` is its committed ES module. Rendering uses the cached label and the band’s `bodyColumns`, with no model lookup on resize.

## Development

Use MoonBit `0.10.21+06da1ed44`, GNU Make, Node.js, Bun 1.4.4, and Claude Code 2.1.328. Install the [pinned MoonBit release](https://www.moonbitlang.com/download/) if needed:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | SHELL=/bin/false bash -s -- '0.10.21+06da1ed44'
export PATH="$HOME/.moon/bin:$PATH"
bun install --frozen-lockfile
make build    # regenerate hooks/statusline.js after changing the MoonBit source
make check    # compare the shipped JS with a clean build and run unattended checks
```

The first developer check downloads the matching [Claude Mods declarations](https://github.com/anthropics/claude-code/blob/v2.1.328/mods/types/claude-code.d.ts) and verifies their checksum. The mod itself does not use the network.

The host test supplies two model names to Claude Code’s terminal test environment. Only a live `claude-codex` session verifies the real model and its placement. Check coexistence on a host that already has the native footer; do not install or disable a footer for the test.
