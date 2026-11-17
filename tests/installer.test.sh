#!/bin/sh
# Installer acceptance test for Linux and macOS. Uses only throwaway config
# directories and does not touch the real OpenCode config.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/statuskit-installer.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_no_file() {
  [ ! -e "$1" ] || fail "unexpected file: $1"
}

assert_contains() {
  grep -q "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
  if grep -q "$2" "$1"; then fail "did not expect '$2' in $1"; fi
}

json() {
  node -e '
    const fs = require("fs");
    const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const path = process.argv[2].split(".");
    let value = cfg;
    for (const key of path) value = value?.[key];
    if (value === undefined) process.exit(1);
    if (typeof value === "object") console.log(JSON.stringify(value));
    else console.log(String(value));
  ' "$1" "$2"
}

HOME_DIR="$TMP/home"
XDG_DIR="$TMP/xdg"
mkdir -p "$HOME_DIR" "$XDG_DIR"
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$XDG_DIR"
export ZDOTDIR="$HOME_DIR"

# 1. Fresh install preserves unrelated cli.json keys and removes stale entries.
CFG="$TMP/c1/opencode"
mkdir -p "$CFG"
cat > "$CFG/cli.json" <<'EOF'
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "terminal": { "title": true, "theme": "dark" },
  "keybinds": { "leader": "ctrl+x" },
  "plugins": ["./tui-plugins/status-title.js", "keep-me"]
}
EOF

OPENCODE_CONFIG_DIR="$CFG" "$ROOT/install.sh" > "$TMP/install1.log"
assert_file "$CFG/plugins/status-title/tui.ts"
assert_file "$CFG/plugins/status-done/tui.tsx"
[ "$(json "$CFG/cli.json" terminal.title)" = "false" ] || fail "terminal.title was not false"
[ "$(json "$CFG/cli.json" terminal.theme)" = "dark" ] || fail "terminal.theme was lost"
[ "$(json "$CFG/cli.json" keybinds.leader)" = "ctrl+x" ] || fail "keybinds were lost"
[ "$(json "$CFG/cli.json" plugins)" = '["keep-me"]' ] || fail "stale plugin entry was not removed"

# 2. Idempotent rerun.
OPENCODE_CONFIG_DIR="$CFG" "$ROOT/install.sh" > "$TMP/install2.log"
assert_file "$CFG/plugins/status-title/tui.ts"

# 3. Legacy v1 files, tui.json entries, and the shell rc block are removed.
CFG2="$TMP/c2/opencode"
mkdir -p "$CFG2/tui-plugins"
printf '%s\n' 'const x = "local.status-title"' > "$CFG2/tui-plugins/status-title.js"
printf '%s\n' 'const x = "local.status-done"' > "$CFG2/tui-plugins/status-done.tsx"
cat > "$CFG2/tui.json" <<'EOF'
{ "plugin": ["./tui-plugins/status-title.js", "keep-this"] }
EOF
cat > "$HOME_DIR/.zshenv" <<'EOF'
# >>> opencode-statuskit >>>
export OPENCODE_DISABLE_TERMINAL_TITLE=1
# <<< opencode-statuskit <<<
export KEEP_ME=1
EOF
OPENCODE_CONFIG_DIR="$CFG2" "$ROOT/install.sh" > "$TMP/install3.log"
assert_no_file "$CFG2/tui-plugins/status-title.js"
assert_no_file "$CFG2/tui-plugins/status-done.tsx"
[ "$(json "$CFG2/tui.json" plugin)" = '["keep-this"]' ] || fail "tui.json stale entry was not removed"
assert_not_contains "$HOME_DIR/.zshenv" "opencode-statuskit"
assert_contains "$HOME_DIR/.zshenv" "KEEP_ME=1"

# 4. --without-title copies only done and leaves terminal.title alone.
CFG3="$TMP/c3/opencode"
mkdir -p "$CFG3"
cat > "$CFG3/cli.json" <<'EOF'
{ "terminal": { "title": true } }
EOF
OPENCODE_CONFIG_DIR="$CFG3" "$ROOT/install.sh" --without-title > "$TMP/install4.log"
assert_no_file "$CFG3/plugins/status-title/tui.ts"
assert_file "$CFG3/plugins/status-done/tui.tsx"
[ "$(json "$CFG3/cli.json" terminal.title)" = "true" ] || fail "--without-title changed terminal.title"

# 5. JSONC prints manual instructions, exits 0, and still copies the plugins.
CFG4="$TMP/c4/opencode"
mkdir -p "$CFG4"
cat > "$CFG4/cli.json" <<'EOF'
{
  // a comment keeps this file from being strict JSON
  "terminal": { "title": true }
}
EOF
set +e
OPENCODE_CONFIG_DIR="$CFG4" "$ROOT/install.sh" > "$TMP/install5.log" 2>&1
STATUS=$?
set -e
[ "$STATUS" -eq 0 ] || fail "JSONC install exited $STATUS, expected 0"
assert_file "$CFG4/plugins/status-title/tui.ts"
assert_file "$CFG4/plugins/status-done/tui.tsx"
assert_contains "$TMP/install5.log" "not strict JSON"
assert_contains "$CFG4/cli.json" "// a comment"

# 6. No Node: install still succeeds and asks for a manual cli.json edit.
CFG5="$TMP/c5/opencode"
mkdir -p "$CFG5"
cat > "$CFG5/cli.json" <<'EOF'
{ "terminal": { "title": true } }
EOF
BIN="$TMP/bin"
mkdir -p "$BIN"
for tool in cp mkdir grep awk mktemp rm rmdir cat dirname mv; do
  tool_path=$(command -v "$tool") || fail "missing test tool: $tool"
  ln -s "$tool_path" "$BIN/$tool"
done
set +e
env -i HOME="$HOME_DIR" ZDOTDIR="$ZDOTDIR" XDG_CONFIG_HOME="$XDG_DIR" \
  OPENCODE_CONFIG_DIR="$CFG5" PATH="$BIN" /bin/sh "$ROOT/install.sh" > "$TMP/install6.log" 2>&1
STATUS=$?
set -e
[ "$STATUS" -eq 0 ] || fail "no-node install exited $STATUS, expected 0"
assert_file "$CFG5/plugins/status-title/tui.ts"
assert_file "$CFG5/plugins/status-done/tui.tsx"
assert_contains "$TMP/install6.log" "node not found"
[ "$(json "$CFG5/cli.json" terminal.title)" = "true" ] || fail "no-node install should not change cli.json"

# 7. Uninstall removes plugin directories but leaves cli.json otherwise intact.
OPENCODE_CONFIG_DIR="$CFG" "$ROOT/uninstall.sh" > "$TMP/uninstall.log"
assert_no_file "$CFG/plugins/status-title/tui.ts"
assert_no_file "$CFG/plugins/status-done/tui.tsx"
[ "$(json "$CFG/cli.json" terminal.title)" = "false" ] || fail "uninstall changed terminal.title"
[ "$(json "$CFG/cli.json" terminal.theme)" = "dark" ] || fail "uninstall lost terminal.theme"
[ "$(json "$CFG/cli.json" keybinds.leader)" = "ctrl+x" ] || fail "uninstall lost keybinds"
[ "$(json "$CFG/cli.json" plugins)" = '["keep-me"]' ] || fail "uninstall lost unrelated plugin entry"

echo "installer tests: ok"
