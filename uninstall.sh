#!/bin/sh
# opencode-statuskit uninstaller. Reverses install.sh.
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
  if command -v node >/dev/null 2>&1 && [ -f "$TUI_JSON" ]; then
    if ! node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const drop = ["./tui-plugins/status-title.js", "./tui-plugins/status-done.tsx"];
      let cfg;
      try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
      catch { console.error("tui.json is not strict JSON; remove entries manually: " + JSON.stringify(drop)); process.exit(2); }
      if (Array.isArray(cfg.plugin)) cfg.plugin = cfg.plugin.filter((p) => !drop.includes(p));
      if (cfg.plugin && cfg.plugin.length === 0) delete cfg.plugin;
      const tmp = path + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
      fs.renameSync(tmp, path);
    ' "$TUI_JSON"; then
      echo "!! remove manually from $TUI_JSON: $WANT" >&2
    fi
  else
    echo "!! check $TUI_JSON manually: remove $WANT if present" >&2
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

done. the kv key "terminal_title_enabled" (if previously set) was left untouched;
toggle it back via the opencode command palette ("Enable terminal title") if desired.
EOF
