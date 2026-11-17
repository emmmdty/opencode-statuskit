# @opencode-status-done

OpenCode 2 TUI plugin: append the last completion time to the prompt footer.

```
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

- Shows `done HH:MM` after a turn succeeds, fails, or is interrupted.
- Hides while the session is running or retrying.
- Falls back to the session's last idle marker after a hot reload, reconnect, or restart.

## Install

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh --without-title
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithoutTitle
```

## npm

This package is prepared for the second distribution phase. A TUI-only package is configured in `cli.json`:

```json
{
  "plugins": ["opencode-status-done"]
}
```

## License

MIT. See the repository `LICENSE`.
