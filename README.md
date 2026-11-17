# opencode-statuskit

OpenCode TUI status plugins for **OpenCode 2.x** (verified on **2.2.7** Linux and **2.3.0** Windows). Current release: **2.0.1** (see `CHANGELOG.md`). Two independently installable plugins:

| Plugin | What it does | Needs config |
|---|---|---|
| `status-title` | Terminal window/tab title shows session state: `🟡 \| task` (working), `🟢 \| …` (idle/done), `🔴 \| …` (permission/form pending, retrying, or turn died from an error). Shows the session name. | `terminal.title: false` (installer sets it) |
| `status-done` | Appends `done 12:23` to the input prompt info line, right after the built-in model/timer segment, when the current session's last turn finished. | none |

Example of `status-done` in place:

```
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

## Install

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh                  # both plugins
./install.sh --without-title  # only the done plugin; leaves an existing title install untouched
```

OpenCode 2 discovers local plugins from `~/.config/opencode/plugins/<name>/tui.ts(x)` and hot-reloads them. No restart or shell environment variables are required.

What the installer touches:

- copies `plugins/v2/status-title/tui.ts` → `~/.config/opencode/plugins/status-title/tui.ts`
- copies `plugins/v2/status-done/tui.tsx` → `~/.config/opencode/plugins/status-done/tui.tsx`
- sets `terminal.title` to `false` in `~/.config/opencode/cli.json` when the title plugin is installed, so the built-in `OC | …` writer does not fight it (requires `node`; prints manual instructions for JSONC files)
- removes legacy v1 `tui-plugins/status-title.js` / `status-done.tsx` files and their stale `tui.json`/`cli.json` entries
- removes the obsolete V1 `OPENCODE_DISABLE_TERMINAL_TITLE` block from shell rc files if the old installer added one
- does **not** add new shell rc changes

`--shell` is still accepted for compatibility but is ignored: v2 reads the title switch from `cli.json`, not an environment variable.

## Uninstall

```sh
./uninstall.sh
```

This removes the plugin directories, legacy v1 files/entries, and any old installer shell-rc blocks. It leaves `terminal.title` untouched; remove that line from `cli.json` if you want the built-in title back.

## Feature flags

| Env var | Effect |
|---|---|
| `OPENCODE_DISABLE_STATUS_TITLE=1` | disables the `status-title` plugin |
| `OPENCODE_STATUSKIT_DONE=0` | disables the `status-done` plugin |

V1's `OPENCODE_DISABLE_TERMINAL_TITLE` is not used by OpenCode 2; use `terminal.title` in `cli.json` instead.

## Notes & known limits

- `status-done` keeps event times in memory and falls back to the session's last projected idle marker, so a hot-loaded plugin, reconnect, or restart can still show the last completion time.
- The plugins use the v2 TUI API (`Plugin.define`, `prompt.footer.status`, `context.data`). V1 plugin code does not run in v2; the old files remain in `plugins/` only as historical reference.
- The title plugin writes once per second so any external title writer self-heals within a second; `terminal.title: false` avoids the flicker entirely.
- If OpenCode later ships a richer terminal-title configuration, `status-title` can be retired in favor of it.

## Development

See `docs/DESIGN-V2.md` for the v2 design and the isolated testing recipe. `docs/DESIGN.md` documents the historical v1 implementation.

## License

MIT. See `LICENSE`.

