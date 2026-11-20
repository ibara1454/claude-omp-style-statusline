# MoonBit statusline for Claude Code

Run `claude-codex --plugin-dir .` from the checkout. The committed MoonBit ES module needs no compiler, Node.js, Bun, or package installation to load. The mod draws one terminal-only `AbovePrompt` row; it does not replace or configure the native footer.

The dark group shows reasoning effort first (`◕ xhigh > gpt-6-luna`), then the working path, Git branch and changed-path counts (`*` unstaged, `+` staged, `?` untracked), and estimated session cost. The circle belongs to effort: `○ low`, `◔ medium`, `◑ high`, `◕ xhigh`, `● max`. The rule shows percent used and the model window in tokens. Before the host reports usage, the window can appear without a percentage. A missing estimate is omitted; `~$` is not an invoice. There is no title, quota bar or subagent surcharge: Claude can retire agent records or restore a total without restoring its per-agent breakdown.

At narrow widths the path shortens first. If that is not enough, cost, Git, model and effort disappear in that order, leaving the path last. Even the path can disappear at extreme widths. A resize only fits the cached values to the available terminal cells.

**Effort before the first turn:** Claude reports the level directly on main-thread model requests. To also see it at startup and immediately after `/effort` or `/model`, allow one read-only command for this session:

```sh
claude-codex --plugin-dir . --allowedTools 'Bash(printenv CLAUDE_EFFORT)'
```

The mod never requests permission or guesses a level from settings. If that read isn't allowed, the effort chip waits for the next main-thread request. When no level is reported, the row starts directly with the model name.

### Where the values come from

- `hooks/register.tsx` reads the session model and usage, handles model and usage updates, and runs Git at startup, on an actual directory change and at main-turn completion. External edits during idle time remain stale until the next refresh. Failed or truncated Git output hides just Git.
- `core/vcs.mbt` shortens the path and parses NUL-delimited Git porcelain v2; filenames are not labels. `core/metrics.mbt` formats the estimate and the embedded gauge. `core/layout.mbt` fits the colored spans to `bodyColumns`, following the [OMP 19 layout](https://github.com/can1357/oh-my-pi/blob/v19.0.0/packages/tui/src/status-line/component.ts).
- `hooks/statusline.d.ts` describes the JS boundary. Claude imports only `hooks/statusline.js` at runtime; Unicode width and grapheme handling are compiled into it. See `THIRD-PARTY-NOTICES`.

## Development

Use MoonBit `0.10.21+06da1ed44`, GNU Make, Node.js, Bun 1.4.4, and Claude Code 2.1.328. Install the [pinned MoonBit release](https://www.moonbitlang.com/download/) if needed:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | SHELL=/bin/false bash -s -- '0.10.21+06da1ed44'
export PATH="$HOME/.moon/bin:$PATH"
bun install --frozen-lockfile
make build    # regenerate hooks/statusline.js after changing the MoonBit source
make check    # compare the shipped JS with a clean build and run unattended checks
```

The first developer build needs the pinned MoonBit packages. The TypeScript check downloads and verifies the [Claude Mods declarations](https://github.com/anthropics/claude-code/blob/v2.1.328/mods/types/claude-code.d.ts). The mod itself does not use the network.

`make check` runs JS-target MoonBit tests and a 90% production coverage-point gate, a real disposable Git repository, strict TS/lint and the official Claude plugin validator and terminal mount tests. Live acceptance uses the shipped module in `claude-codex`, wide and narrow. A host without the original shell footer cannot prove coexistence; leave that footer untouched until cutover on its intended host.

**Plan checkpoint 6.1 — reasoning effort:** verify the effort chip precedes the model at startup, updates on a session-only change without restarting, ignores subagent changes, and returns after narrowing. Plugin-panel and native-footer behavior are out of scope.
