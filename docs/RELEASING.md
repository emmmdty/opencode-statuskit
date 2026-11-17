# Releasing

## Preflight

Run from a clean checkout:

```sh
npm ci
npm test
npm run typecheck
npm run test:installer
npm run smoke        # Linux: needs opencode and script(1)
```

On Windows, run both:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\installer.test.ps1
pwsh -File .\tests\installer.test.ps1
```

## Version and notes

1. Bump `version` in `package.json`, `plugins/v2/status-title/package.json`, and `plugins/v2/status-done/package.json`.
2. Add the release section to `CHANGELOG.md`.
3. Write `docs/releases/v<version>.md`.
4. Commit and push `main`; wait for CI to pass.

## Tag and release

```sh
git tag -a v2.0.2 -m "v2.0.2"
git push origin v2.0.2
```

The `Release` workflow runs tests, builds `opencode-statuskit-<version>.tar.gz`, `.zip`, and `SHA256SUMS`, then creates the GitHub Release from `docs/releases/<tag>.md`.

Verify:

```sh
gh release view v2.0.2
gh release download v2.0.2 --pattern SHA256SUMS
sha256sum -c SHA256SUMS
```

Download the release tarball on a clean Linux/macOS/Windows machine and follow the README install steps.

## Rollback

If the release is broken:

1. Delete the GitHub Release and the tag:
   ```sh
   gh release delete v2.0.2 --yes
   git push origin :refs/tags/v2.0.2
   git tag -d v2.0.2
   ```
2. Revert the release commit on `main` or cut a patch release.
3. Never move a tag that users may already have downloaded; publish a new patch version instead.

## npm (second phase)

The two package directories are prepared but not published.

```sh
cd plugins/v2/status-title
npm pack
npm publish --access public
```

Test the tarball in an isolated OpenCode config first. A TUI-only package goes in `cli.json`:

```json
{
  "plugins": ["opencode-status-title"]
}
```

The title package still requires `terminal.title` to be `false`; the installer remains the only path that sets it automatically.
