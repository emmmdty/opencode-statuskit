#!/bin/sh
# opencode-statuskit legacy uninstaller for OpenCode 1.18.x.
# Reverses legacy/opencode-1/install.sh.
set -eu

MARKER="opencode-statuskit"
CFG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
TUI_DEST="$CFG_DIR/tui-plugins"
TUI_JSON="$CFG_DIR/tui.json"
WANT='["./tui-plugins/status-title.js","./tui-plugins/status-done.tsx"]'

echo "==> removing plugin files"
rm -f "$TUI_DEST/status-title.js" "$TUI_DEST/status-done.tsx"
rmdir "$TUI_DEST" 2>/dev/null || true

remove_tui_json() {
  if [ ! -f "$TUI_JSON" ]; then
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    if ! node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const drop = ["./tui-plugins/status-title.js", "./tui-plugins/status-done.tsx"];
      let cfg;
      try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
      catch {
        console.error("tui.json is not strict JSON; remove entries manually: " + JSON.stringify(drop));
        process.exit(0);
      }
      if (!Array.isArray(cfg.plugin)) process.exit(0);
      const next = cfg.plugin.filter((entry) => !drop.includes(entry));
      if (next.length === cfg.plugin.length) process.exit(0);
      if (next.length === 0) delete cfg.plugin;
      else cfg.plugin = next;
      const tmp = path + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
      fs.renameSync(tmp, path);
    ' "$TUI_JSON"; then
      echo "!! could not clean $TUI_JSON" >&2
    fi
  else
    echo "!! node not found; check $TUI_JSON and remove: $WANT" >&2
  fi
}

echo "==> removing tui.json entries"
remove_tui_json

echo "==> removing env blocks from shell rcs"
for rc in "$HOME/.zshenv" "${ZDOTDIR:-$HOME}/.zshenv" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish" "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"; do
  [ -f "$rc" ] || continue
  if grep -q ">>> $MARKER" "$rc"; then
    TMP=$(mktemp)
    awk -v m="$MARKER" 'BEGIN{skip=0} $0 ~ ("^# >>> " m " >>>$"){skip=1;next} $0 ~ ("^# <<< " m " <<<$"){skip=0;next} skip==0{print}' "$rc" > "$TMP"
    mv "$TMP" "$rc"
    echo "    cleaned: $rc"
  fi
done

cat <<'EOF'

done. tui.json was left otherwise untouched.
  - if you set OPENCODE_DISABLE_TERMINAL_TITLE manually outside the marked
    block, remove it from your shell profile yourself.
EOF
