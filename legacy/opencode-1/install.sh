#!/bin/sh
# opencode-statuskit legacy installer for OpenCode 1.18.x.
# POSIX sh, idempotent. This line is frozen at 1.0.0.
# Usage: install.sh [--shell SHELL] [--without-title]
set -eu

MARKER="opencode-statuskit"
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CFG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
TUI_DEST="$CFG_DIR/tui-plugins"
TUI_JSON="$CFG_DIR/tui.json"

SHELL_OVERRIDE=""
WITH_TITLE=1
TUI_UPDATED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --shell)
      [ $# -ge 2 ] || { echo "missing value for --shell" >&2; exit 1; }
      SHELL_OVERRIDE="$2"
      shift 2
      ;;
    --without-title) WITH_TITLE=0; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if command -v opencode >/dev/null 2>&1; then
  VERSION=$(opencode --version 2>/dev/null | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | sed 's/^v//' || true)
  case "${VERSION:-}" in
    2.*|3.*|4.*|5.*|6.*|7.*|8.*|9.*)
      echo "!! this is the legacy OpenCode 1.x installer; detected OpenCode $VERSION" >&2
      echo "   for OpenCode 2.x use the top-level install.sh instead." >&2
      ;;
  esac
fi

echo "==> config dir: $CFG_DIR"
mkdir -p "$TUI_DEST"

echo "==> copying plugins"
cp "$KIT_DIR/plugins/status-done.tsx" "$TUI_DEST/status-done.tsx"
if [ "$WITH_TITLE" -eq 1 ]; then
  cp "$KIT_DIR/plugins/status-title.js" "$TUI_DEST/status-title.js"
  WANT_JSON='["./tui-plugins/status-title.js","./tui-plugins/status-done.tsx"]'
else
  WANT_JSON='["./tui-plugins/status-done.tsx"]'
fi

merge_tui_json() {
  if command -v node >/dev/null 2>&1; then
    if node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const want = JSON.parse(process.argv[2]);
      let cfg = {};
      if (fs.existsSync(path)) {
        const raw = fs.readFileSync(path, "utf8");
        try { cfg = JSON.parse(raw); }
        catch {
          console.error("tui.json is not strict JSON (comments/trailing commas detected). Merge manually:");
          console.error("  plugin: " + JSON.stringify(want));
          console.error("  plugins are already copied to " + process.argv[3]);
          process.exit(2);
        }
      }
      if (!Array.isArray(cfg.plugin)) cfg.plugin = [];
      for (const p of want) if (!cfg.plugin.includes(p)) cfg.plugin.push(p);
      if (!cfg.$schema) cfg.$schema = "https://opencode.ai/tui.json";
      const tmp = path + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + "\n");
      fs.renameSync(tmp, path);
    ' "$TUI_JSON" "$WANT_JSON" "$TUI_DEST"; then
      TUI_UPDATED=1
    else
      STATUS=$?
      if [ "$STATUS" -eq 2 ]; then
        echo "!! plugins are installed, but $TUI_JSON was not changed automatically." >&2
        echo "   follow the manual instructions above." >&2
      else
        echo "!! failed to merge $TUI_JSON automatically." >&2
        echo "   add manually: \"plugin\": $WANT_JSON" >&2
        exit 2
      fi
    fi
  else
    if [ -f "$TUI_JSON" ]; then
      echo "!! node not found; plugins are installed, but $TUI_JSON was not updated." >&2
      echo "   add manually: \"plugin\": $WANT_JSON" >&2
    else
      printf '{\n  "$schema": "https://opencode.ai/tui.json",\n  "plugin": %s\n}\n' "$WANT_JSON" > "$TUI_JSON"
      TUI_UPDATED=1
    fi
  fi
}

echo "==> registering plugins in tui.json"
merge_tui_json

write_block() {
  # $1 = rc file, $2 = export line
  rc="$1"
  [ -f "$rc" ] || : > "$rc"
  if grep -q ">>> $MARKER" "$rc"; then
    echo "    already present: $rc"
    return 0
  fi
  # Appending to a file without a trailing newline would merge the marker with
  # the last line and break the rc with a ">>>" redirection syntax error.
  if [ -n "$(tail -c 1 "$rc")" ]; then
    printf '\n' >> "$rc"
  fi
  TMPB=$(mktemp)
  {
    printf '# >>> %s >>>\n' "$MARKER"
    printf '%s\n' "$2"
    printf '# <<< %s <<<\n' "$MARKER"
  } > "$TMPB"
  guard=$(grep -n 'case \$- in' "$rc" 2>/dev/null | head -n 1 | cut -d: -f1 || true)
  if [ -n "${guard:-}" ] && [ "$guard" -le 15 ]; then
    awk -v n="$guard" -v b="$TMPB" 'NR==n{while((getline l < b)>0) print l} {print}' "$rc" > "$rc.new"
    mv "$rc.new" "$rc"
  else
    cat "$TMPB" >> "$rc"
  fi
  rm -f "$TMPB"
  echo "    injected: $rc"
}

TITLE_ENV_OK=0
if [ "$WITH_TITLE" -eq 1 ]; then
  echo "==> injecting OPENCODE_DISABLE_TERMINAL_TITLE (title feature)"
  SH="${SHELL_OVERRIDE:-${SHELL:-}}"
  case "$SH" in
    */zsh)
      write_block "${ZDOTDIR:-$HOME}/.zshenv" 'export OPENCODE_DISABLE_TERMINAL_TITLE=1'
      TITLE_ENV_OK=1
      ;;
    */bash)
      write_block "$HOME/.bashrc" 'export OPENCODE_DISABLE_TERMINAL_TITLE=1'
      write_block "$HOME/.bash_profile" 'export OPENCODE_DISABLE_TERMINAL_TITLE=1'
      TITLE_ENV_OK=1
      ;;
    */fish)
      FISH_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
      mkdir -p "$(dirname "$FISH_CFG")"
      write_block "$FISH_CFG" 'set -gx OPENCODE_DISABLE_TERMINAL_TITLE 1'
      TITLE_ENV_OK=1
      ;;
    "")
      echo "!! cannot detect shell (\$SHELL empty). plugins are installed, but the" >&2
      echo "   title feature needs this at opencode launch:" >&2
      echo "     export OPENCODE_DISABLE_TERMINAL_TITLE=1" >&2
      echo "   re-run with --shell /path/to/shell, or use --without-title to skip it." >&2
      ;;
    *)
      echo "!! unsupported shell: $SH. plugins are installed, but the title feature" >&2
      echo "   needs this at opencode launch:" >&2
      echo "     export OPENCODE_DISABLE_TERMINAL_TITLE=1" >&2
      echo "   re-run with --shell /path/to/shell, or use --without-title to skip it." >&2
      ;;
  esac
else
  echo "==> skipping title env (--without-title)"
fi

cat <<EOF

done. legacy OpenCode 1.x line 1.0.0.
  - running OpenCode 1.x instances load plugins at startup only; restart them.
  - tmux users: the env var only reaches new sessions:
      tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1
    or restart the tmux server.
  - the done feature needs no env var; the terminal-title feature does.
    without it the title may briefly flicker on route changes.
EOF
if [ "$WITH_TITLE" -eq 1 ] && [ "$TITLE_ENV_OK" -eq 0 ]; then
  echo "  - this installer could not add the title env var automatically; add it" 
  echo "    to your shell profile as shown above." 
fi
if [ "$TUI_UPDATED" -eq 0 ]; then
  echo "  - tui.json was not updated automatically; add the plugin entries above."
fi
