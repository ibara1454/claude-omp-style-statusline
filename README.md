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

## Install

Run this in your shell to add the GitHub marketplace and install the plugin for your user account:

```sh
claude plugin install claude-omp-style-statusline --marketplace ibara1454/claude-omp-style-statusline
```

Start a new `claude` session from your project, or run `/reload-plugins` in an open session. The status row appears above the prompt. No build is needed.

## Try without installing

For one session, run this from a checkout of the plugin:

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

[Developer guide](DEVELOPMENT.md) · [Third-party notices](THIRD-PARTY-NOTICES)
