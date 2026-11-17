# AGENTS.md

This repository ships two OpenCode 2 TUI plugins and their installers. Keep the
plugin code small and the installers boring.

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

- Do not test against the real `~/.config/opencode`. Use `OPENCODE_CONFIG_DIR`
  for `install.sh` / `uninstall.sh` and `-ConfigDir` for the PowerShell scripts.
- Keep both installers idempotent and preserve unrelated `cli.json` keys.
- Do not add runtime dependencies to the plugins. `@opencode/plugin` is provided
  by OpenCode; `solid-js` and `@opentui/*` are peers.
- V1 code in `archive/v1/` is historical; do not install or import it.
- A plugin slot must return JSX or `null`, never a bare string.
- Update `CHANGELOG.md` and `docs/releases/<tag>.md` for every release.
- Run `npm test`, `npm run typecheck`, and `npm run test:installer` before
  committing a release change.

## Layout

- `plugins/v2/status-title/tui.ts` — terminal title state machine.
- `plugins/v2/status-done/tui.tsx` — prompt footer done time.
- `tests/` — Node test runner; the done test uses a renderer-free JSX runtime.
- `docs/DESIGN-V2.md` — host facts and isolated test recipe.
- `docs/DISTRIBUTION.md` — distribution decisions and status.
- `docs/RELEASING.md` — release, rollback, and npm steps.
