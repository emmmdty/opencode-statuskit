# Contributing

Thanks for trying opencode-statuskit.

## Before opening an issue

- Search existing issues.
- Include the OpenCode version (`opencode --version`), OS, terminal, plugin
  version, and the relevant `cli.json` keys.
- For a title problem, say whether the terminal title changes at all, and
  whether you use tmux or a multiplexer.
- For a security issue, use the private advisory link in `SECURITY.md`.

## Development

```sh
npm install
npm test
npm run typecheck
npm run test:installer
npm run smoke        # Linux, needs opencode and script(1)
```

On Windows, run `tests\installer.test.ps1` in both Windows PowerShell 5.1 and
PowerShell 7.

## Installer changes

- Test with a throwaway `OPENCODE_CONFIG_DIR` or `-ConfigDir`; never test against
  the real config.
- The installers must be idempotent and preserve unrelated `cli.json` keys.
- `install.sh` must not fail when Node is missing or `cli.json` is JSONC; it
  prints the manual edit and exits 0.
- `install.ps1` must stay compatible with Windows PowerShell 5.1.

## Plugin changes

- Keep the two plugins independent.
- The OpenCode 1.18.x line lives in `legacy/opencode-1/` and is frozen at 1.0.0. Only compatibility fixes go there; new features go in `plugins/v2/`.
- Do not add runtime dependencies.
- A slot render must return JSX or `null` (both lines).
- Add or update tests in `tests/`.
- Update `docs/DESIGN-V2.md` if the 2.x event/state behavior changes; update `docs/DESIGN.md` for the 1.x line.

## Pull requests

- One logical change per PR.
- Describe the user-visible effect and the tests you ran.
- Do not bump versions or create tags in a feature PR; releases are handled by
  the maintainer.
