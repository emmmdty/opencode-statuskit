# opencode-statuskit

OpenCode TUI status plugins. Two independently installable plugins, verified against OpenCode **1.18.30**.

| Plugin | What it does | Needs env var |
|---|---|---|
| `status-title.js` | Terminal window/tab title shows session state: `🟡 \| task · branch` (working), `🟢 \| …` (idle/done), `🔴 \| …` (permission/question pending, retrying, or turn died from an error). Shows the session name and current git branch (worktree-aware). | yes (suppresses the built-in `OC \| …` title writer) |
| `status-done.tsx` | Appends `· done 12:23` to the input prompt info line, right after the built-in model/timer segment, when the current session's last turn finished. | no |

Example of `status-done` in place (verified live):

```
▣ Build · GLM-5.3-Flash · 2.3s · done 12:42
```

## Install

```sh
git clone <this repo>
cd opencode-statuskit
./install.sh                # both plugins, env var auto-injected per your shell
./install.sh --without-title  # only the done plugin, no shell rc changes (leaves an existing title install untouched)
./install.sh --shell /usr/bin/fish  # override shell detection
```

Then restart your opencode sessions (running instances load plugins at startup only).

What the installer touches:

- copies `plugins/status-title.js` and `plugins/status-done.tsx` to `~/.config/opencode/tui-plugins/` (`--without-title` copies only the latter)
- registers them in `~/.config/opencode/tui.json` (merge; existing keys untouched; requires `node`, otherwise prints manual instructions)
- appends a marked `OPENCODE_DISABLE_TERMINAL_TITLE=1` block to your shell rc (zsh → `.zshenv`, bash → `.bashrc`+`.bash_profile` with Debian interactive-guard awareness, fish → `config.fish`)

## Uninstall

```sh
./uninstall.sh
```

## Feature flags

| Env var | Effect |
|---|---|
| `OPENCODE_DISABLE_TERMINAL_TITLE=1` | disables OpenCode's built-in title writer (required for clean status titles; installer handles this) |
| `OPENCODE_DISABLE_STATUS_TITLE=1` | fully disables the `status-title` plugin |
| `OPENCODE_STATUSKIT_DONE=0` | fully disables the `status-done` plugin |

## Notes & known limits

- Verified on **OpenCode 1.18.30** (`tui.json` plugin mechanism). A v2 line is in development (npm `next`/`beta` snapshots; v2 docs describe `cli.json` + package-based plugin discovery) and is not published as 2.x yet; revalidate when it ships.
- **tmux**: env vars only reach sessions started after the change — `tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1` or restart the tmux server.
- Non-interactive shells (cron/scripts), GUI-launched terminals and exotic shells are not covered by the installer; set the env var manually there. Without it, titles still work but may flicker briefly on route changes.
- `done` times are in-memory per TUI instance; they reset on restart by design.
- The `session_prompt_right` slot is `append` mode and currently unoccupied upstream, so this composes with stock builds and other plugins. If OpenCode ships an official terminal-title formatter (open PR exists), `status-title` may be retired in favor of it.

## Development

See `docs/DESIGN.md` for the full design, verified host behavior, and the isolated testing recipe (XDG redirection + `OPENCODE_DB=:memory:`) that lets you run test instances without touching your live config.
