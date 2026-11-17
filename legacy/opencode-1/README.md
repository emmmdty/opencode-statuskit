# opencode-statuskit for OpenCode 1.x (legacy, 1.0.0)

This is the **OpenCode 1.18.x** line of opencode-statuskit. It is **frozen at
1.0.0**: no new features, only compatibility fixes if a real bug is found.

OpenCode 2.x users should use the main installer in the repository root.

## What it does

The same two features as the 2.x line, implemented for the old plugin API:

- `status-title`: terminal title `🟢` idle, `🟡` working, `🔴` attention.
- `status-done`: `done HH:MM` in `session_prompt_right`.

OpenCode 1.x has no directory-based plugin discovery. The plugins are single
files in `tui-plugins/` and are registered in `tui.json`.

## Install

Linux, macOS, and WSL:

```sh
cd opencode-statuskit
./legacy/opencode-1/install.sh
```

From the repository root, the dispatcher also detects OpenCode 1.x automatically:

```sh
./install.sh
```

Options:

```sh
./legacy/opencode-1/install.sh --without-title
./legacy/opencode-1/install.sh --shell /bin/zsh
./legacy/opencode-1/install.sh --shell /usr/bin/fish
```

What the installer does:

- copies `plugins/status-title.js` and `plugins/status-done.tsx` to
  `~/.config/opencode/tui-plugins/`
- adds `./tui-plugins/status-title.js` and `./tui-plugins/status-done.tsx` to
  `~/.config/opencode/tui.json`
- adds an `OPENCODE_DISABLE_TERMINAL_TITLE=1` block to the shell profile when
  the title plugin is installed (zsh, bash, or fish)
- leaves other `tui.json` keys and shell profile content alone
- is idempotent

OpenCode 1.x reads plugins at startup. **Restart OpenCode** after installing;
there is no hot reload on this line.

## tmux

The title env var only reaches new tmux sessions. Either:

```sh
tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1
```

or restart the tmux server.

## Uninstall

```sh
./legacy/opencode-1/uninstall.sh
```

This removes the two plugin files, their `tui.json` entries, and the marked
shell profile block. It leaves other `tui.json` keys and profile content alone.

## Native Windows

Native Windows OpenCode 1.x is **not supported** by this legacy line. The V1
title feature depends on a POSIX shell environment variable. Use WSL and the
installer above, or upgrade to OpenCode 2.x and use the main installer.

## Differences from the 2.x line

| | 1.x legacy | 2.x current |
|---|---|---|
| OpenCode | 1.18.x | 2.x |
| Plugin entry | `export default { id, tui }` | `Plugin.define` |
| Config | `tui.json` | `cli.json` |
| Plugin location | `tui-plugins/*.js(x)` | `plugins/<name>/tui.ts(x)` |
| done slot | `session_prompt_right` | `prompt.footer.status` |
| Events | `event.properties` | `event.data` |
| Title suppression | `OPENCODE_DISABLE_TERMINAL_TITLE=1` | `terminal.title: false` |
| Reload | restart OpenCode | hot reload |

## Tested

- OpenCode 1.18.29 (Linux)
- OpenCode 1.18.30 (Linux, isolated re-check)

The 2.x line is tested on OpenCode 2.2.7 and 2.3.0.

## Security

No network requests, no telemetry, no background service. The plugins are two
small JavaScript/TypeScript files that can be read before installing.
