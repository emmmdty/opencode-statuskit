# AGENTS.md

This repository ships two OpenCode 2 TUI plugins, a frozen OpenCode 1.x
legacy line, and their installers. Keep the plugin code small and the
installers boring.

## Commands

```sh
npm install
npm test
npm run typecheck
npm run test:installer
npm run smoke        # Linux, needs opencode and script(1)
```

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\installer.test.ps1
pwsh -File .\tests\installer.test.ps1
```

## Rules

- The OpenCode 1.18.x legacy line is in `legacy/opencode-1/`. It is supported and
  frozen at 1.0.0; keep it separate from `plugins/v2/`.
- Do not test against the real `~/.config/opencode`. Use `OPENCODE_CONFIG_DIR`
  for the shell installers and `-ConfigDir` for the PowerShell scripts.
- Keep all installers idempotent and preserve unrelated config keys.
- Do not add runtime dependencies to the plugins. `@opencode/plugin` is provided
  by OpenCode; `solid-js` and `@opentui/*` are peers.
- A plugin slot must return JSX or `null`, never a bare string.
- Update `CHANGELOG.md` and `docs/releases/<tag>.md` for every release.
- Run `npm test`, `npm run typecheck`, and `npm run test:installer` before
  committing a release change.

## Layout

- `plugins/v2/status-title/tui.ts` — terminal title state machine (OpenCode 2.x).
- `plugins/v2/status-done/tui.tsx` — prompt footer done time (OpenCode 2.x).
- `legacy/opencode-1/` — frozen OpenCode 1.18.x line; `tui.json` + `tui-plugins/`.
- `tests/` — Node test runner; done tests use a renderer-free JSX runtime.
- `docs/DESIGN-V2.md` — 2.x host facts and isolated test recipe.
- `docs/DESIGN.md` — 1.x legacy design.
- `docs/DISTRIBUTION.md` — distribution decisions and status.
- `docs/RELEASING.md` — release, rollback, and npm steps.
