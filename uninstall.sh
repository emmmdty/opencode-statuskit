#!/bin/sh
# opencode-statuskit uninstaller for OpenCode 2.x. Reverses install.sh.
set -eu

MARKER="opencode-statuskit"
CFG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
PLUGIN_DIR="$CFG_DIR/plugins"
LEGACY_DIR="$CFG_DIR/tui-plugins"
CLI_JSON="$CFG_DIR/cli.json"
TUI_JSON="$CFG_DIR/tui.json"

echo "==> removing plugin files"
rm -rf "$PLUGIN_DIR/status-title" "$PLUGIN_DIR/status-done"
rmdir "$PLUGIN_DIR" 2>/dev/null || true
rm -f "$LEGACY_DIR/status-title.js" "$LEGACY_DIR/status-done.tsx"
rmdir "$LEGACY_DIR" 2>/dev/null || true

echo "==> removing legacy v1 entries"
if command -v node >/dev/null 2>&1; then
  for file in "$CLI_JSON" "$TUI_JSON"; do
    [ -f "$file" ] || continue
    if ! node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const stale = ["./tui-plugins/status-title.js", "./tui-plugins/status-done.tsx"];
      let cfg;
      try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
      catch { console.error("not strict JSON; remove legacy entries manually: " + path); process.exit(0); }
      let changed = false;
      for (const key of ["plugins", "plugin"]) {
        if (!Array.isArray(cfg[key])) continue;
        const next = cfg[key].filter((entry) => !stale.includes(entry));
        if (next.length !== cfg[key].length) {
          changed = true;
          if (next.length === 0) delete cfg[key];
          else cfg[key] = next;
        }
      }
      if (!changed) process.exit(0);
      const tmp = path + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
      fs.renameSync(tmp, path);
    ' "$file"; then
      echo "!! could not clean $file" >&2
    fi
  done
else
  echo "!! node not found; check $CLI_JSON and $TUI_JSON for legacy entries" >&2
fi

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

done. cli.json was left otherwise untouched.
  - If terminal.title is still false and you want OpenCode's built-in title
    back, remove that line from ~/.config/opencode/cli.json.
EOF
