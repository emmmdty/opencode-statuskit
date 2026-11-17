# opencode-statuskit

[![CI](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml/badge.svg)](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/emmmdty/opencode-statuskit)](https://github.com/emmmdty/opencode-statuskit/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Terminal status for the **OpenCode 2 TUI**: see what the session is doing without switching windows.

```
🟡 | Build the release        ← working
🔴 | Build the release        ← permission, form, retry, or a stopped error
🟢 | Build the release        ← idle or finished
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

Two independently installable plugins:

| Plugin | What it does | Needs config |
|---|---|---|
| `status-title` | Terminal window/tab title shows session state: `🟡` working, `🟢` idle/done, `🔴` needs attention. Includes subagent state. | `terminal.title: false` (installer sets it) |
| `status-done` | Appends `done 12:23` to the prompt info line after the last turn finishes. | none |

Current release: **[v2.0.2](https://github.com/emmmdty/opencode-statuskit/releases/tag/v2.0.2)**. Tested on OpenCode **2.2.7** (Linux) and **2.3.0** (Linux and Windows).

## Install

### Linux and macOS

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh                  # both plugins
./install.sh --without-title  # only done; leaves an existing title install untouched
```

### Windows

```powershell
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithoutTitle
```

OpenCode 2 discovers local plugins from `~/.config/opencode/plugins/<name>/tui.ts(x)` and hot-reloads them. No restart or shell environment variables are required.

## What the installers touch

- copy `plugins/v2/status-title/tui.ts` → `<config>/plugins/status-title/tui.ts`
- copy `plugins/v2/status-done/tui.tsx` → `<config>/plugins/status-done/tui.tsx`
- set `terminal.title` to `false` in `<config>/cli.json` when the title plugin is installed, so the built-in `OC | …` writer does not fight it
- remove legacy v1 `tui-plugins/status-title.js` / `status-done.tsx` files and their stale `tui.json` / `cli.json` entries
- remove the obsolete V1 `OPENCODE_DISABLE_TERMINAL_TITLE` block from shell rc files if the old installer added one
- not add new shell rc changes

`install.sh` uses `node` to merge an existing `cli.json`. If Node is missing, or the file is JSONC (comments or trailing commas), the plugins are still copied and the script prints the manual edit. `install.ps1` uses built-in PowerShell JSON handling and needs no Node.

`--shell` is accepted for compatibility but ignored: v2 reads the title switch from `cli.json`, not an environment variable.

## Upgrade

Re-run the installer for the new version. It is idempotent and preserves unrelated `cli.json` keys.

```sh
git pull
./install.sh
```

On Windows, re-run `install.ps1`.

## Uninstall

```sh
./uninstall.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

This removes the plugin directories, legacy v1 files/entries, and old shell-rc blocks. It leaves `terminal.title` untouched; remove that line from `cli.json` if you want the built-in title back.

## Requirements and compatibility

| Host | Status |
|---|---|
| Linux, OpenCode 2.2.7 | tested |
| Linux, OpenCode 2.3.0 | tested |
| Windows, OpenCode 2.3.0 | tested (installer tested in PowerShell 5.1 and 7) |
| macOS | installer covered by CI; TUI not yet verified on Terminal/iTerm2 |

- OpenCode 2.x only. V1 plugins do not run in v2.
- `status-title` needs a terminal that accepts OSC 2 title sequences. Windows Terminal, iTerm2, Kitty, WezTerm, Ghostty, and VS Code generally work. In tmux, the pane title changes; the outer terminal title depends on `set-titles`.
- `status-done` renders in `prompt.footer.status`.
- The desktop app is not supported; this kit targets the terminal TUI.

## Feature flags

| Env var | Effect |
|---|---|
| `OPENCODE_DISABLE_STATUS_TITLE=1` | disables `status-title` |
| `OPENCODE_STATUSKIT_DONE=0` | disables `status-done` |

V1's `OPENCODE_DISABLE_TERMINAL_TITLE` is not used by OpenCode 2; use `terminal.title` in `cli.json` instead.

## Troubleshooting

- **The terminal title does not change.** Check that `terminal.title` is `false` in `cli.json`. Check the terminal supports OSC 2. In tmux, look at the pane title; the outer title follows `set-titles`.
- **The title flashes `OC | …`.** The built-in writer is still enabled. Set `terminal.title` to `false`.
- **`done` does not appear.** Confirm the plugin is loaded (plugin count/no errors in the log) and that the turn actually ended. The footer hides while a session is running or retrying.
- **`install.sh` says JSONC.** Add `"terminal": { "title": false }` to `cli.json` manually; the plugins are already copied.
- **Windows blocks the script.** Run it with `powershell -ExecutionPolicy Bypass -File .\install.ps1`; do not paste it into an admin shell.

## Security

- No network requests, telemetry, or background service.
- The plugins are small TypeScript files that can be read before installing.
- `status-title` writes the terminal title; `status-done` renders text in the prompt footer. Neither reads prompts or message content beyond session state and the last idle timestamp.

## Notes and known limits

- `status-done` keeps event times in memory and falls back to the session's last projected idle marker, so a hot-loaded plugin, reconnect, or restart can still show the last completion time.
- The title plugin writes once per second so any external title writer self-heals within a second; `terminal.title: false` avoids the flicker entirely.
- If OpenCode later ships richer terminal-title configuration, `status-title` can be retired in favor of it.
- The plugins use the v2 TUI API (`Plugin.define`, `prompt.footer.status`, `context.data`). V1 code remains in `archive/v1/` only as historical reference.

## Development

```sh
npm install
npm test
npm run typecheck
npm run test:installer
npm run smoke   # Linux, needs opencode and script(1)
```

See `docs/DESIGN-V2.md` for the v2 design and the isolated testing recipe. `docs/DESIGN.md` documents the historical v1 implementation.

## License

MIT. See `LICENSE`.
