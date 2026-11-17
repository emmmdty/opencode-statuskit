#!/bin/sh
# opencode-statuskit installer for OpenCode 2.x. POSIX sh, idempotent.
# Usage: install.sh [--shell SHELL] [--without-title]
set -eu

MARKER="opencode-statuskit"
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CFG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
PLUGIN_DIR="$CFG_DIR/plugins"
LEGACY_DIR="$CFG_DIR/tui-plugins"
CLI_JSON="$CFG_DIR/cli.json"
TUI_JSON="$CFG_DIR/tui.json"

WITH_TITLE=1
TITLE_UPDATED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --shell)
      [ $# -ge 2 ] || { echo "missing value for --shell" >&2; exit 1; }
      echo "==> --shell is no longer needed: OpenCode 2 reads terminal.title from cli.json"
      shift 2
      ;;
    --without-title) WITH_TITLE=0; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "==> config dir: $CFG_DIR"
mkdir -p "$PLUGIN_DIR"

echo "==> copying plugins"
mkdir -p "$PLUGIN_DIR/status-done"
cp "$KIT_DIR/plugins/v2/status-done/tui.tsx" "$PLUGIN_DIR/status-done/tui.tsx"
if [ "$WITH_TITLE" -eq 1 ]; then
  mkdir -p "$PLUGIN_DIR/status-title"
  cp "$KIT_DIR/plugins/v2/status-title/tui.ts" "$PLUGIN_DIR/status-title/tui.ts"
fi

# v1 installed single files here. They are never loaded by v2, so remove only
# files that are recognizably ours, then leave the directory if it has others.
remove_legacy() {
  for file in "$LEGACY_DIR/status-title.js" "$LEGACY_DIR/status-done.tsx"; do
    [ -f "$file" ] || continue
    if grep -q 'local\.status-title' "$file" 2>/dev/null || grep -q 'local\.status-done' "$file" 2>/dev/null; then
      rm -f "$file"
      echo "    removed legacy v1 plugin: $file"
    else
      echo "    left unrecognized file alone: $file"
    fi
  done
  rmdir "$LEGACY_DIR" 2>/dev/null || true
}
remove_legacy

# V1 injected OPENCODE_DISABLE_TERMINAL_TITLE into shell rcs. V2 ignores that
# variable and uses cli.json, so remove only the marked block we added.
remove_legacy_rc_blocks() {
  for rc in "$HOME/.zshenv" "${ZDOTDIR:-$HOME}/.zshenv" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish" "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"; do
    [ -f "$rc" ] || continue
    grep -q ">>> $MARKER" "$rc" || continue
    TMP=$(mktemp)
    awk -v m="$MARKER" 'BEGIN{skip=0} $0 ~ ("^# >>> " m " >>>$"){skip=1;next} $0 ~ ("^# <<< " m " <<<$"){skip=0;next} skip==0{print}' "$rc" > "$TMP"
    mv "$TMP" "$rc"
    echo "    removed obsolete v1 env block: $rc"
  done
}
remove_legacy_rc_blocks

merge_cli_json() {
  if command -v node >/dev/null 2>&1; then
    if node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const writeTitle = process.argv[2] === "1";
      const stale = [
        "./tui-plugins/status-title.js",
        "./tui-plugins/status-done.tsx",
      ];
      let cfg = {};
      if (fs.existsSync(path)) {
        const raw = fs.readFileSync(path, "utf8");
        try { cfg = JSON.parse(raw); }
        catch {
          console.error("cli.json is not strict JSON (comments/trailing commas detected). Edit manually:");
          if (writeTitle) {
            console.error("  set terminal.title to false (keep other terminal keys)");
            console.error("  remove legacy plugin entries: " + stale.join(", "));
          }
          console.error("  plugins are already copied to " + process.argv[3]);
          process.exit(2);
        }
      }
      if (writeTitle) {
        if (!cfg.terminal || typeof cfg.terminal !== "object" || Array.isArray(cfg.terminal)) cfg.terminal = {};
        cfg.terminal.title = false;
      }
      if (Array.isArray(cfg.plugins)) {
        cfg.plugins = cfg.plugins.filter((entry) => !stale.includes(entry));
        if (cfg.plugins.length === 0) delete cfg.plugins;
      }
      if (!cfg.$schema) cfg.$schema = "https://opencode.ai/v2/cli.json";
      const tmp = path + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
      fs.renameSync(tmp, path);
    ' "$CLI_JSON" "$WITH_TITLE" "$PLUGIN_DIR"; then
      if [ "$WITH_TITLE" -eq 1 ]; then
        TITLE_UPDATED=1
      fi
    else
      status=$?
      if [ "$status" -eq 2 ]; then
        echo "!! plugins are installed, but $CLI_JSON was not changed automatically." >&2
        echo "   follow the manual instructions above." >&2
      else
        echo "!! failed to update $CLI_JSON automatically." >&2
        if [ "$WITH_TITLE" -eq 1 ]; then
          echo '   set "terminal": { "title": false } manually so the built-in title writer does not fight the plugin.' >&2
        fi
        exit 2
      fi
    fi
  else
    if [ -f "$CLI_JSON" ]; then
      echo "!! node not found; plugins are installed, but $CLI_JSON was not updated." >&2
      echo "   edit it manually:" >&2
      if [ "$WITH_TITLE" -eq 1 ]; then
        echo '   - set "terminal": { "title": false } (keep other terminal keys)' >&2
      fi
      echo '   - remove legacy "./tui-plugins/status-*.js(x)" entries if present' >&2
    else
      if [ "$WITH_TITLE" -eq 1 ]; then
        printf '{\n  "$schema": "https://opencode.ai/v2/cli.json",\n  "terminal": {\n    "title": false\n  }\n}\n' > "$CLI_JSON"
        TITLE_UPDATED=1
      else
        printf '{\n  "$schema": "https://opencode.ai/v2/cli.json"\n}\n' > "$CLI_JSON"
      fi
    fi
  fi
}

echo "==> updating cli.json"
merge_cli_json

echo "==> cleaning legacy tui.json entries"
if [ -f "$TUI_JSON" ] && command -v node >/dev/null 2>&1; then
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const stale = ["./tui-plugins/status-title.js", "./tui-plugins/status-done.tsx"];
    let cfg;
    try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
    catch { process.exit(0); }
    if (!Array.isArray(cfg.plugin)) process.exit(0);
    const next = cfg.plugin.filter((entry) => !stale.includes(entry));
    if (next.length === cfg.plugin.length) process.exit(0);
    if (next.length === 0) delete cfg.plugin;
    else cfg.plugin = next;
    const tmp = path + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
    fs.renameSync(tmp, path);
  ' "$TUI_JSON"
fi

cat <<EOF

done. notes:
  - OpenCode 2 discovers plugins from $PLUGIN_DIR/<name>/tui.ts(x)
    and hot-reloads them; no shell environment variables are needed.
EOF
if [ "$WITH_TITLE" -eq 1 ]; then
  if [ "$TITLE_UPDATED" -eq 1 ]; then
    cat <<'EOF'
  - terminal.title=false is set by this installer so the built-in "OC | ..."
    writer does not overwrite the status title. Remove that line manually if you
    uninstall the title plugin and want the built-in title back.
EOF
  else
    cat <<'EOF'
  - terminal.title was NOT changed automatically. Set "terminal": { "title": false }
    in cli.json manually so the built-in title writer does not fight the plugin.
EOF
  fi
fi
cat <<'EOF'
  - the old OPENCODE_DISABLE_TERMINAL_TITLE environment variable is ignored by
    OpenCode 2; this installer removes the marked block the V1 installer added.
EOF
