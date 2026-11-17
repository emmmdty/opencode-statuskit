#!/bin/sh
# Legacy OpenCode 1.x installer and dispatcher test. Uses throwaway configs.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/statuskit-legacy.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() { [ -f "$1" ] || fail "expected file: $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "unexpected file: $1"; }
assert_contains() { grep -q "$2" "$1" || fail "expected '$2' in $1"; }
assert_not_contains() { if grep -q "$2" "$1"; then fail "did not expect '$2' in $1"; fi; }

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
BIN="$TMP/bin"
mkdir -p "$HOME_DIR" "$XDG_DIR" "$BIN"
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$XDG_DIR"
export ZDOTDIR="$HOME_DIR"
export SHELL=/bin/zsh

cat > "$BIN/opencode" <<'EOF'
#!/bin/sh
case "${FAKE_OPENCODE_VERSION:-2}" in
  1) echo "opencode v1.18.29" ;;
  *) echo "opencode v2.3.0" ;;
esac
EOF
chmod +x "$BIN/opencode"
export PATH="$BIN:$PATH"
export FAKE_OPENCODE_VERSION=1

# 1. Legacy install.
CFG="$TMP/c1/opencode"
mkdir -p "$CFG"
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG" "$ROOT/legacy/opencode-1/install.sh" > "$TMP/legacy-install.log"
assert_file "$CFG/tui-plugins/status-title.js"
assert_file "$CFG/tui-plugins/status-done.tsx"
[ "$(json "$CFG/tui.json" plugin)" = '["./tui-plugins/status-title.js","./tui-plugins/status-done.tsx"]' ] || fail "tui.json plugin entries"
assert_contains "$HOME_DIR/.zshenv" "OPENCODE_DISABLE_TERMINAL_TITLE=1"
assert_contains "$HOME_DIR/.zshenv" ">>> opencode-statuskit >>>"

# 2. Idempotent.
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG" "$ROOT/legacy/opencode-1/install.sh" > "$TMP/legacy-install2.log"
[ "$(grep -c '>>> opencode-statuskit >>>' "$HOME_DIR/.zshenv")" -eq 1 ] || fail "duplicate shell block"

# 3. --without-title.
CFG2="$TMP/c2/opencode"
HOME2="$TMP/home2"
mkdir -p "$CFG2" "$HOME2"
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG2" HOME="$HOME2" ZDOTDIR="$HOME2" "$ROOT/legacy/opencode-1/install.sh" --without-title > "$TMP/legacy-install3.log"
assert_file "$CFG2/tui-plugins/status-done.tsx"
assert_no_file "$CFG2/tui-plugins/status-title.js"
[ "$(json "$CFG2/tui.json" plugin)" = '["./tui-plugins/status-done.tsx"]' ] || fail "without-title tui.json"
assert_no_file "$HOME2/.zshenv"

# 4. JSONC tui.json is left intact, plugins are copied, exit 0.
CFG3="$TMP/c3/opencode"
mkdir -p "$CFG3"
cat > "$CFG3/tui.json" <<'EOF'
{
  // comment
  "plugin": []
}
EOF
set +e
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG3" "$ROOT/legacy/opencode-1/install.sh" > "$TMP/legacy-jsonc.log" 2>&1
STATUS=$?
set -e
[ "$STATUS" -eq 0 ] || fail "JSONC legacy install exited $STATUS"
assert_file "$CFG3/tui-plugins/status-title.js"
assert_contains "$TMP/legacy-jsonc.log" "not strict JSON"
assert_contains "$CFG3/tui.json" "// comment"

# 5. Uninstall.
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG" "$ROOT/legacy/opencode-1/uninstall.sh" > "$TMP/legacy-uninstall.log"
assert_no_file "$CFG/tui-plugins/status-title.js"
assert_no_file "$CFG/tui-plugins/status-done.tsx"
assert_not_contains "$HOME_DIR/.zshenv" "opencode-statuskit"

# 6. Dispatcher: OpenCode 1.x goes to the legacy installer.
CFG4="$TMP/c4/opencode"
mkdir -p "$CFG4"
FAKE_OPENCODE_VERSION=1 OPENCODE_CONFIG_DIR="$CFG4" "$ROOT/install.sh" > "$TMP/dispatch-v1.log"
assert_file "$CFG4/tui-plugins/status-title.js"
assert_file "$CFG4/tui-plugins/status-done.tsx"
assert_contains "$TMP/dispatch-v1.log" "legacy installer"

# 7. Dispatcher: OpenCode 2.x goes to the current installer.
CFG5="$TMP/c5/opencode"
mkdir -p "$CFG5"
FAKE_OPENCODE_VERSION=2 OPENCODE_CONFIG_DIR="$CFG5" "$ROOT/install.sh" > "$TMP/dispatch-v2.log"
assert_file "$CFG5/plugins/status-title/tui.ts"
assert_file "$CFG5/plugins/status-done/tui.tsx"
[ "$(json "$CFG5/cli.json" terminal.title)" = "false" ] || fail "dispatcher v2 cli.json"
assert_contains "$TMP/dispatch-v2.log" "current installer"

echo "legacy installer tests: ok"
