#!/bin/sh
# opencode-statuskit installer dispatcher.
# Detects the OpenCode major version and runs the matching installer.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

detect_major() {
  if command -v opencode >/dev/null 2>&1; then
    opencode --version 2>/dev/null \
      | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' \
      | head -n 1 \
      | sed 's/^v//' \
      | cut -d. -f1
  fi
}

MAJOR=$(detect_major || true)
case "${MAJOR:-}" in
  1)
    echo "==> OpenCode 1.x detected; using the legacy installer (1.0.0)"
    exec "$KIT_DIR/legacy/opencode-1/install.sh" "$@"
    ;;
  2)
    echo "==> OpenCode 2.x detected; using the current installer"
    exec "$KIT_DIR/install-v2.sh" "$@"
    ;;
  "")
    echo "==> could not detect the OpenCode version; installing the OpenCode 2.x plugins"
    echo "    OpenCode 1.x users: run legacy/opencode-1/install.sh"
    exec "$KIT_DIR/install-v2.sh" "$@"
    ;;
  *)
    echo "==> OpenCode $MAJOR.x detected; installing the OpenCode 2.x plugins"
    echo "    if this is OpenCode 1.x, run legacy/opencode-1/install.sh"
    exec "$KIT_DIR/install-v2.sh" "$@"
    ;;
esac
