#!/bin/sh
# Linux smoke test: boot the real OpenCode TUI in a throwaway config and check
# that both plugins load without errors. It does not touch the real config.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if ! command -v opencode >/dev/null 2>&1; then
  echo "smoke: skipped (opencode not found)"
  exit 0
fi
if ! command -v script >/dev/null 2>&1; then
  echo "smoke: skipped (script not found)"
  exit 0
fi
if ! command -v timeout >/dev/null 2>&1; then
  echo "smoke: skipped (timeout not found)"
  exit 0
fi

TEST=$(mktemp -d "${TMPDIR:-/tmp}/statuskit-smoke.XXXXXX")
trap 'rm -rf "$TEST"' EXIT

mkdir -p "$TEST/config/opencode/plugins/status-title" \
         "$TEST/config/opencode/plugins/status-done" \
         "$TEST/state" "$TEST/data" "$TEST/cache"

cp "$ROOT/plugins/v2/status-title/tui.ts" "$TEST/config/opencode/plugins/status-title/"
cp "$ROOT/plugins/v2/status-done/tui.tsx" "$TEST/config/opencode/plugins/status-done/"

cat > "$TEST/config/opencode/cli.json" <<'EOF'
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "terminal": { "title": false }
}
EOF

LOG="$TEST/tty.log"
set +e
timeout 12 script -qec "env XDG_CONFIG_HOME=$TEST/config XDG_STATE_HOME=$TEST/state \
  XDG_DATA_HOME=$TEST/data XDG_CACHE_HOME=$TEST/cache OPENCODE_DB=:memory: \
  opencode --standalone --print-logs" "$LOG" >/dev/null 2>&1
STATUS=$?
set -e

# 124 is expected: timeout stops the interactive TUI.
case "$STATUS" in
  0|124|143) ;;
  *) echo "smoke: opencode exited with status $STATUS" >&2; tail -40 "$LOG" >&2 || true; exit 1 ;;
esac

if ! grep -q "plugin reconciliation completed" "$LOG"; then
  echo "smoke: plugin reconciliation line not found" >&2
  tail -60 "$LOG" >&2 || true
  exit 1
fi

if grep -Eiq "plugin.*(failed|error)|(failed|error).*plugin" "$LOG"; then
  echo "smoke: plugin load error found" >&2
  grep -Ei "plugin.*(failed|error)|(failed|error).*plugin" "$LOG" >&2 || true
  exit 1
fi

echo "smoke: ok"
