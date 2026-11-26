# Repository Guidelines

## Project Overview

`omp-style-statusline` adds one colored row below the Claude Code terminal prompt: effort, model, path, Git changes, estimated cost, and context usage. It runs offline as a footer hook, not a shell `statusLine` command.

## Architecture & Data Flow

1. `hooks/hooks.json` loads `register(on)` from `hooks/register.tsx`. Session and turn handlers keep state in that closure. They use the injected `$` engine for session data, environment, Git, and UI; rendering reads cached state rather than running commands.
2. The hook passes the working directory and NUL-delimited Git porcelain v2 output to MoonBit. `parseStatus` returns `[branch, unstaged, staged, untracked]`. Failed or truncated Git output hides only the Git chip. Independent generation counters discard stale Git and usage results before they can overwrite newer state.
3. On `ui.render`, `renderRow` returns flat `[text, foreground, background]` triples. The hook maps them to host `Text` elements and preserves native content via `next(e)`. Use `StatusLine` on 2.1.332+ and the `PromptHint` fallback on older 2.1.x hosts. If native text fills the row budget, leave it untouched.

## Key Directories

- `core/` owns display rules: `vcs.mbt` shortens paths, sanitizes text, and parses Git; `layout.mbt` fits chips; `metrics.mbt` formats the gauge and cost. Unit tests sit beside each module.
- `hooks/` contains the host adapter and shipped core. `tests/` exercises mounted footers; `scripts/` holds the real-Git integration test and Claude declaration fetcher.

## Development Commands

Run from the repository root:

```sh
npm install                        # Install development tools
make build                         # Regenerate hooks/statusline.js after core edits
moon test --target js --deny-warn  # Core tests only
npm run check:ts                   # Strict tsc check and oxlint
make check                         # Full release gate
claude --plugin-dir .              # Run the checkout in a real terminal
```

## Code Conventions & Common Patterns

- Keep MoonBit functions `snake_case` and JS exports `camelCase` (e.g. `render_row` → `renderRow`). Use `moon fmt`; match the hook’s two-space indentation, single quotes, and type-only imports.
- Keep subagent events out of main-session state. Accept effort from main turn steps or confirmed picker output; show `◌ unknown` at startup rather than invoking a command. Invalidate `ui.render` after accepting an update.
- Measure terminal cells, not string length. Clip paths at grapheme boundaries, drop optional chips whole, and reserve at least half the row for the gauge or divider.

## Important Files

- For a cross-language API change, update the ESM export map in `core/moon.pkg`, the signatures in `hooks/statusline.d.ts`, and the caller in `hooks/register.tsx` together. Ship the rebuilt `hooks/statusline.js`; never hand-edit it.
- For distribution changes, `.claude-plugin/plugin.json` defines the plugin and `.claude-plugin/marketplace.json` points at the repository root.

## Runtime/Tooling Preferences

Use GNU Make, MoonBit `0.10.21+06da1ed44` (JS target only), Node.js with npm, Git, and Claude Code `2.1.332` for development. See [DEVELOPMENT.md](DEVELOPMENT.md) for the pinned installer. The first build fetches MoonBit packages; `scripts/claude-types.mjs` fetches pinned Claude declarations only when its SHA-256-verified cache is missing or invalid.

## Testing & QA

`make check` requires **90% aggregate production MoonBit coverage** and byte-compares a fresh release build with the shipped JS. After rebuilding a parser change, run `node --test scripts/git.integration.mjs`: it tests the shipped parser against real repositories, including renames and filenames containing newlines.

For host changes, `claude plugin test .` runs `tests/plugin.test.ts` via `claude-code/testing` on both footer render sites. For visual changes, also check chip colors and gauge labels in a color-capable terminal; narrow the window and inspect the next refresh.
