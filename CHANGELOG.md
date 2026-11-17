# Changelog

All notable changes to opencode-statuskit.

## 2.0.3 - 2026-11-17

Adds the OpenCode 1.18.x legacy line. The 2.x plugin behavior is unchanged from 2.0.2.

### Added

- `legacy/opencode-1/` restores the V1 plugins and installers for OpenCode 1.18.x, frozen at 1.0.0.
- The root `install.sh` detects `opencode --version` and dispatches to the 1.x or 2.x installer.
- Legacy installer tests and V1 title/done tests; `npm test` and `npm run test:installer` cover both lines.
- README sections for the legacy line, including `tui.json`, `tui-plugins/`, and `OPENCODE_DISABLE_TERMINAL_TITLE`.

### Changed

- README upgrade instructions now cover tag-based clones, `main` clones, and release tarballs separately.
- The 2.x Windows installer warns and stops when it detects OpenCode 1.x; native Windows 1.x is directed to WSL.
- The root shell installer is now a dispatcher; the 2.x implementation lives in `install-v2.sh`.

### Fixed

- Tag-based installs no longer get incorrect `git pull` upgrade advice.

## 2.0.2 - 2026-11-17

Distribution release. Plugin behavior is unchanged from 2.0.1.

### Added

- `install.ps1` and `uninstall.ps1` for Windows, with no Node.js dependency.
- Repository tests for the title state machine, the done slot, and the Unix/PowerShell installers.
- CI matrix for Ubuntu, macOS, and Windows (Node 22), including PowerShell 5.1 and 7.
- Release workflow that builds `.tar.gz`, `.zip`, and `SHA256SUMS` and creates a GitHub Release.
- npm package manifests for `opencode-status-title` and `opencode-status-done` (prepared, not published).
- `SECURITY.md`, an issue form, and a release notes template.

### Changed

- `install.sh` copies the plugins and exits 0 when Node is missing or `cli.json` is JSONC, printing the manual edit instead of failing.
- README now covers Windows, upgrade, compatibility, troubleshooting, security, and development.
- V1 plugin archives moved out of `plugins/` (restored as `legacy/opencode-1/` in 2.0.3).

### Fixed

- The installer notes now say when `terminal.title` was not changed automatically.

## 2.0.1 - 2026-11-17

### Fixed

- `status-done` now updates through a reactive `Show` instead of reading the signal only when the slot component is created.
- `status-done` falls back to the session's last projected idle marker when the plugin is hot-loaded after a turn, reconnects, or misses the terminal event.
- Windows native OpenCode 2.3.0 verified end-to-end: plugin discovery, `Plugin.define` execution, terminal title updates, and `done HH:MM` rendering in `prompt.footer.status`.

## 2.0.0 - 2026-11-17

First release for OpenCode 2.x, verified on OpenCode 2.2.7.

### Added

- `status-title` TUI plugin for OpenCode 2: terminal title shows `🟢` idle, `🟡` working, and `🔴` attention (permission/form pending, retrying, or a stopped subtree with an error).
- `status-done` TUI plugin for OpenCode 2: shows `done HH:MM` in the prompt footer after a turn ends.
- Directory-based local plugin layout (`plugins/status-title/tui.ts`, `plugins/status-done/tui.tsx`) discovered by OpenCode 2.
- `CHANGELOG.md` and package version metadata.

### Changed

- Ported both plugins from the V1 hook API to `Plugin.define` / `setup(context)`.
- Installer now installs v2 plugin directories and sets `terminal.title: false` in `cli.json` instead of injecting `OPENCODE_DISABLE_TERMINAL_TITLE` into shell rc files.
- Installer migrates and removes V1 `tui-plugins/` files, stale `tui.json`/`cli.json` entries, and the old shell rc block.
- Updated README, HANDOVER, and V2 design documentation; V1 design is marked historical.

### Fixed

- False red title during normal work:
  - retry attention is cleared as soon as the retry resumes (`session.step.started`, reasoning/text/tool/compaction activity);
  - historical errors no longer override yellow while any subtree member is still running;
  - errors surface as red only after the subtree stops;
  - subagent busy/error state still propagates to the parent, and continuing the parent clears it.

## Legacy line (OpenCode 1.x)

### 1.0.0 - 2026-11-17

- Restored the V1 title and done plugins for OpenCode 1.18.x under `legacy/opencode-1/`.
- Added `legacy/opencode-1/install.sh` and `uninstall.sh` using `tui.json`, `tui-plugins/`, and the `OPENCODE_DISABLE_TERMINAL_TITLE` shell block.
- Added V1 installer tests and V1 title/done unit tests.
- Frozen: no new features; only compatibility fixes if a real bug is found.
