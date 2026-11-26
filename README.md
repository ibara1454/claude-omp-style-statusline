# Statusline for Claude Code

One colored row below the Claude Code terminal prompt: purple effort and model chips, a color-coded Git branch, and a two-tone context gauge. The plugin draws directly in the terminal footer, without a yellow notice or a row above the prompt.

**Wide terminal**

```text
 ◕ xhigh > gpt-6-luna > 📁 ~/src/atlas > ⑂ main *2 +1 ?3 > ~$0.42 ▶────────────────────32%───────────────────────────────────────200K─
```

**Same session, narrow terminal**

```text
 📁 …c/atlas ▶───32%───200K─
```

| Readout | What it means |
| --- | --- |
| `◕ xhigh` | Reasoning effort: `○ low` · `◔ medium` · `◑ high` · `◕ xhigh` · `● max` |
| `⑂ main *2 +1 ?3` | On `main`: 2 unstaged paths, 1 staged, 3 untracked |
| `~$0.42` | Estimated session cost, not a bill. Hidden if unknown. |
| `32%` · `200K` | 32% of the 200K-token context window used. Until usage arrives, only the window size is shown. |

The gauge (or plain divider when usage is unavailable) gets at least half the row, rounded up. The other half keeps the path and as many whole chips as fit, in priority order: effort, model, Git, then cost. The path uses the remaining space before the gauge grows beyond half. In very narrow terminals the folder and a suffix such as `…e` stay if they fit; otherwise the gauge fills the row. Gauge labels stay visible whenever the row can fit them.

## Installation

With GitHub read access to this repository, install the plugin:

```sh
claude plugin install omp-style-statusline --marketplace ibara1454/claude-omp-style-statusline
```

Start a new `claude` session. The plugin uses the `StatusLine` render site on Claude Code 2.1.332 and later; on 2.1.329 it draws beside the built-in footer hints without replacing them.

If your `statusLine` setting calls the old `scripts/statusline.mjs`, remove that setting. Keep any unrelated `statusLine` command: its output stays visible, and the colored row appears when there is a spare row, even if the command prints nothing.

## When does it update?

The plugin reads the model, working directory, Git status and usage at startup. Claude Code does not include the resolved effort level in the session-start event. The first chip shows `◌ unknown` until Claude reports a level. The plugin does not run a slash command or use Bash to look it up.

Context and cost follow session measurements; Git refreshes after directory changes and main turns. Main-conversation steps and confirmed `/effort` or `/model` changes keep the effort chip current.

## Development

[Developer guide](DEVELOPMENT.md) · [Third-party notices](ThirdPartyNotices.txt)
