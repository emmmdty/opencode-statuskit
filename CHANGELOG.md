# Changelog

All notable changes to opencode-statuskit.

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
