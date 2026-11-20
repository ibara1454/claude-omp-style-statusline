# MoonBit statusline for Claude Code

One row above your Claude Code prompt. The native footer stays untouched.

**Wide terminal**

```text
 ◕ xhigh > gpt-6-luna > 📁 ~/src/atlas > ⑂ main *2 +1 ?3 > ~$0.42 ▶────32%─────200K─
```

**Same session, narrow terminal**

```text
 📁 …tlas ▶────32%─────200K─
```

| Readout | What it means |
| --- | --- |
| `◕ xhigh` | Reasoning effort: `○ low` · `◔ medium` · `◑ high` · `◕ xhigh` · `● max` |
| `⑂ main *2 +1 ?3` | On `main`: 2 unstaged paths, 1 staged, 3 untracked |
| `~$0.42` | Estimated session cost, not a bill. Hidden if unknown. |
| `32%` · `200K` | 32% of the 200K-token context window used. Until usage arrives, only the window size is shown. |

The path shortens first. If space is still tight, the row drops cost → Git → model → effort → path.

## Run

If the plugin is already configured, run `claude` from your project. No build or package install needed.

Otherwise, run from this plugin’s checkout:

```sh
claude --plugin-dir . --allowedTools 'Bash(printenv CLAUDE_EFFORT)'
```

The session-only permission lets the plugin read the current effort at startup. It doesn’t change your settings. If effort is unavailable, the row starts with the model.

## When does it update?

| Action | Result |
| --- | --- |
| Confirm `/effort` or `/model` | Effort updates immediately, even for a session-only change. Cancel to keep the old level. |
| Change only effort with `Alt+P` (Claude Code 2.1.329) | Run `/effort status` to refresh, or wait for the next turn. |
| Start a session, change directory, or finish a main turn | Git refreshes. External edits made while idle appear on the next refresh. |

## Development

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

[Session hooks](hooks/register.tsx) · [MoonBit layout](core/layout.mbt) · [Original OMP layout](https://github.com/can1357/oh-my-pi/blob/v19.0.0/packages/tui/src/status-line/component.ts) · [Third-party notices](THIRD-PARTY-NOTICES)
