# @opencode-status-title

OpenCode 2 TUI plugin: show the current session state in the terminal title.

| Title | Meaning |
|---|---|
| `🟢 \| task` | Idle or finished |
| `🟡 \| task` | Working, including subagents |
| `🔴 \| task` | Permission/form pending, retrying, or the subtree stopped with an error |

## Install

The supported installation is the installer in the main repository. It copies the plugin directory and sets `terminal.title` to `false` in `cli.json` so the built-in title writer does not fight the plugin.

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## npm

This package is prepared for the second distribution phase. A TUI-only package is configured in `cli.json`:

```json
{
  "plugins": ["opencode-status-title"]
}
```

You must also set `terminal.title` to `false` in `cli.json`.

## License

MIT. See the repository `LICENSE`.
