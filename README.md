# opencode-statuskit

[![CI](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml/badge.svg)](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/emmmdty/opencode-statuskit)](https://github.com/emmmdty/opencode-statuskit/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) | [中文](README.zh-CN.md)

Terminal status for the **OpenCode 2 TUI**, plus a frozen legacy line for **OpenCode 1.18.x**:

```
🟡 | Build the release        ← working
🔴 | Build the release        ← permission, form, retry, or a stopped error
🟢 | Build the release        ← idle or finished
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

Two independently installable plugins:

| Plugin | What it does | Needs config |
|---|---|---|
| `status-title` | Terminal window/tab title shows session state: `🟡` working, `🟢` idle/done, `🔴` needs attention. Includes subagent state. | `terminal.title: false` on 2.x; `OPENCODE_DISABLE_TERMINAL_TITLE=1` on 1.x |
| `status-done` | Appends `done 12:23` to the prompt info line after the last turn finishes. | none |

Current: **[v2.0.3](https://github.com/emmmdty/opencode-statuskit/releases/tag/v2.0.3)** for OpenCode 2.x. Legacy line: **1.0.0** for OpenCode 1.18.x, frozen.

## Install

### OpenCode 2.x: Linux and macOS

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh                  # auto-detects 2.x
./install.sh --without-title  # only done; leaves an existing title install untouched
```

### OpenCode 2.x: Windows

```powershell
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithoutTitle
```

OpenCode 2 discovers local plugins from `~/.config/opencode/plugins/<name>/tui.ts(x)` and hot-reloads them. No restart or shell environment variables are required.

### OpenCode 1.x: legacy (Linux, macOS, WSL)

```sh
cd opencode-statuskit
./install.sh                      # auto-detects 1.x and uses the legacy installer
# or run it directly:
./legacy/opencode-1/install.sh
./legacy/opencode-1/install.sh --without-title
./legacy/opencode-1/install.sh --shell /bin/zsh
```

The legacy line uses `tui.json` and `tui-plugins/`, and **restarts OpenCode 1.x** are required. Native Windows OpenCode 1.x is not supported; use WSL. See [`legacy/opencode-1/README.md`](legacy/opencode-1/README.md).

The root `install.sh` checks `opencode --version` and dispatches to the 1.x or 2.x installer. If the version cannot be detected, it installs the 2.x plugins and prints the legacy path.

## What the installers touch

### OpenCode 2.x

- copy `plugins/v2/status-title/tui.ts` → `<config>/plugins/status-title/tui.ts`
- copy `plugins/v2/status-done/tui.tsx` → `<config>/plugins/status-done/tui.tsx`
- set `terminal.title` to `false` in `<config>/cli.json` when the title plugin is installed
- remove legacy v1 `tui-plugins/status-*.js(x)` files and stale `tui.json` / `cli.json` entries
- remove the obsolete V1 `OPENCODE_DISABLE_TERMINAL_TITLE` block from shell rc files
- not add new shell rc changes

`install.sh` uses `node` to merge an existing `cli.json`. If Node is missing, or the file is JSONC, the plugins are still copied and the script prints the manual edit. `install.ps1` uses built-in PowerShell JSON handling and needs no Node.

### OpenCode 1.x legacy

- copy `legacy/opencode-1/plugins/status-title.js` and `status-done.tsx` → `<config>/tui-plugins/`
- add `./tui-plugins/status-title.js` and `./tui-plugins/status-done.tsx` to `<config>/tui.json`
- add an `OPENCODE_DISABLE_TERMINAL_TITLE=1` block to the shell profile (zsh, bash, or fish) when the title plugin is installed
- leave other `tui.json` keys and shell profile content alone
- be idempotent

## Upgrade

### OpenCode 2.x

Re-run the installer from the new version. It is idempotent and preserves unrelated `cli.json` keys. **Do not uninstall first.**

If you cloned a tag (for example `git clone --branch v2.0.2 --depth 1`), fetch and check out the new tag:

```sh
cd opencode-statuskit
git fetch --tags
git checkout v2.0.2   # replace with the new release tag
./install.sh
```

If you cloned `main`:

```sh
git pull
./install.sh
```

If you downloaded a release tarball, download the new tarball and `SHA256SUMS`, verify, extract, then run `./install.sh` from the new directory.

On Windows, re-run `install.ps1` after updating the checkout or extracting the new zip.

### OpenCode 1.x legacy

The legacy line is frozen at **1.0.0**. There are no routine upgrades. If a 1.0.x patch is released, download the new release and run `legacy/opencode-1/install.sh` from it.

## Uninstall

OpenCode 2.x:

```sh
./uninstall.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

OpenCode 1.x legacy:

```sh
./legacy/opencode-1/uninstall.sh
```

The 2.x uninstaller also removes leftover V1 files/entries and old shell-rc blocks. It leaves `terminal.title` untouched; remove that line from `cli.json` if you want the built-in title back. The legacy uninstaller leaves `tui.json` otherwise intact.

## Requirements and compatibility

| Host | Status |
|---|---|
| Linux, OpenCode 2.2.7 | tested |
| Linux, OpenCode 2.3.0 | tested |
| Windows, OpenCode 2.3.0 | tested (installer tested in PowerShell 5.1 and 7) |
| macOS, OpenCode 2.x | installer covered by CI; TUI not yet verified on Terminal/iTerm2 |
| Linux/macOS/WSL, OpenCode 1.18.x | legacy 1.0.0, supported and frozen |
| Native Windows, OpenCode 1.x | not supported; use WSL |

- The 1.x and 2.x plugin APIs are not compatible. The root installer dispatches by major version.
- `status-title` needs a terminal that accepts OSC 2 title sequences. Windows Terminal, iTerm2, Kitty, WezTerm, Ghostty, and VS Code generally work. In tmux, the pane title changes; the outer terminal title depends on `set-titles`.
- `status-done` renders in `prompt.footer.status` on 2.x and `session_prompt_right` on 1.x.
- The desktop app is not supported; this kit targets the terminal TUI.

## Feature flags

| Env var | Effect |
|---|---|
| `OPENCODE_DISABLE_STATUS_TITLE=1` | disables `status-title` on both lines |
| `OPENCODE_STATUSKIT_DONE=0` | disables `status-done` on both lines |
| `OPENCODE_DISABLE_TERMINAL_TITLE=1` | 1.x only: suppresses the built-in title writer; the legacy installer adds it |

On 2.x, use `terminal.title` in `cli.json` instead of `OPENCODE_DISABLE_TERMINAL_TITLE`.

## Troubleshooting

- **2.x: the terminal title does not change.** Check that `terminal.title` is `false` in `cli.json`. Check the terminal supports OSC 2. In tmux, look at the pane title; the outer title follows `set-titles`.
- **2.x: the title flashes `OC | …`.** The built-in writer is still enabled. Set `terminal.title` to `false`.
- **2.x: `done` does not appear.** Confirm the plugin is loaded and the turn ended. The footer hides while a session is running or retrying.
- **2.x: `install.sh` says JSONC.** Add `"terminal": { "title": false }` to `cli.json` manually; the plugins are already copied.
- **1.x: the title does not change.** Confirm `OPENCODE_DISABLE_TERMINAL_TITLE=1` is in the shell that launches OpenCode, restart OpenCode, and in tmux run `tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1`.
- **1.x: `done` does not appear.** Check that `tui.json` contains both `./tui-plugins/status-*.js(x)` entries, then restart OpenCode.
- **Windows blocks the script.** Run it with `powershell -ExecutionPolicy Bypass -File .\install.ps1`; do not paste it into an admin shell.

## Security

- No network requests, telemetry, or background service.
- The plugins are small JavaScript/TypeScript files that can be read before installing.
- `status-title` writes the terminal title; `status-done` renders text in the prompt footer. Neither reads prompts or message content beyond session state and the last idle timestamp.

## Notes and known limits

- 2.x: `status-done` keeps event times in memory and falls back to the session's last projected idle marker, so a hot-loaded plugin, reconnect, or restart can still show the last completion time.
- 2.x: the title plugin writes once per second so any external title writer self-heals within a second; `terminal.title: false` avoids the flicker entirely.
- 1.x legacy: plugins are loaded at startup only; restart OpenCode after installing or upgrading. The line is frozen at 1.0.0.
- If OpenCode later ships richer terminal-title configuration, `status-title` can be retired in favor of it.
- The 2.x plugins use `Plugin.define`, `prompt.footer.status`, and `context.data`. The 1.x code in `legacy/opencode-1/` uses `event.properties`, `tui.json`, and `session_prompt_right`.

## Development

```sh
npm install
npm test
npm run typecheck
npm run test:installer   # Unix: both 1.x and 2.x installers
npm run smoke            # 2.x Linux, needs opencode and script(1)
```

On Windows, run `tests\installer.test.ps1` in Windows PowerShell 5.1 and PowerShell 7. See `docs/DESIGN-V2.md` for the 2.x design and `docs/DESIGN.md` for the 1.x design.

## License

MIT. See `LICENSE`.
