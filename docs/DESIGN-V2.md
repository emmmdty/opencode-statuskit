# opencode-statuskit — V2 design

Date: 2026-11-12 · Host baseline: OpenCode **2.2.7** (stock) · Status: ported, isolated runtime verification passed

V1 design history is in `docs/DESIGN.md`. V1 plugin code remains in `plugins/status-title.js` and `plugins/status-done.tsx` for reference only; the installer does not use it.

## 1. Why V1 stopped working

V2 has three intentional breaking changes:

- Plugin implementations use a new API. V1's default-exported async function returning hooks is not called.
- Terminal client settings moved from layered `tui.json(c)` to one global `cli.json`.
- V2 discovers local plugins as **directories**, not individual files.

The old install registered files such as `./tui-plugins/status-title.js`. V2 skips configured file paths with a log warning and never loads them. The old slot name `session_prompt_right` no longer exists, and event payloads moved from `event.properties` to `event.data`.

## 2. V2 host facts used by this kit

### 2.1 Discovery and loading

- Global discovery directory: `<config>/plugins/<name>/`.
- Conventional entrypoints: `<name>/tui.ts`, `<name>/tui.tsx`, or a package.json `exports` map with `./tui`.
- Local plugin directories are watched and hot-reloaded when files change.
- A TUI-only directory needs no server entry (`index.ts`).
- `cli.json` `plugins` entries may name a package, a directory, a `file://` URL, or `./relative` directory. Files are skipped.

The installer therefore creates:

```text
~/.config/opencode/plugins/status-title/tui.ts
~/.config/opencode/plugins/status-done/tui.tsx
```

No `plugins` entry is needed; discovery finds both directories. Stale V1 entries are removed.

### 2.2 API surface

```ts
import { Plugin } from "@opencode/plugin/tui"

export default Plugin.define({
  id: "local.status-title",
  setup(context) {
    // context.data.on(...), context.ui.slot(...), context.renderer, ...
    return () => {
      // cleanup
    }
  },
})
```

- Events: `context.data.on(type, handler)`, handler receives `{ type, data, ... }`; unsubscribe function returned.
- Sessions: `context.data.session.get/list/family/root/status/sync/invalidate`.
- Permissions/forms: `context.data.session.permission.list(sessionID)`, `context.data.session.form.list(sessionID)`.
- Theme: `context.theme.text.muted` (reactive when read inside a slot render).
- Renderer: `context.renderer.setTerminalTitle(string)`.
- Route: `context.ui.router.current()` returns `{ type: "home" }`, `{ type: "session", sessionID }`, or `{ type: "plugin", name, ... }`.
- Slot for the prompt's right-side info row: `prompt.footer.status` (input `{ sessionID?, mode, showDetails }`).
- Slot renders must return JSX or `null`; a bare string raises an orphan-text error.

### 2.3 Events used

| Event | Use |
|---|---|
| `session.created` | cache parentID; refresh title |
| `session.forked` | cache parentID |
| `session.renamed` | refresh title |
| `session.deleted` | drop per-session state |
| `session.status` | source of `busy` / `retry` / `idle` status |
| `session.retry.scheduled` | attention (🔴) while retrying |
| `session.step.started` | retry resumed; clear retry attention |
| `session.reasoning.started` / `session.text.started` / `session.tool.called` | activity; clear retry attention |
| `session.compaction.started` | activity; clear retry attention |
| `session.execution.started` | busy (🟡); clears stale errors |
| `session.execution.succeeded` | idle; done timestamp |
| `session.execution.failed` | attention (🔴); done timestamp |
| `session.execution.interrupted` | idle; done timestamp (except shutdown) |
| `session.idle` | deprecated fallback; stale-error cleanup |
| `permission.asked` / `permission.replied` | refresh attention |
| `form.created` / `form.replied` / `form.cancelled` | refresh attention |

`context.data.session.status()` only reports `idle | running`, so the plugin also tracks raw `session.status` values (including `retry`) in its own map.

## 3. Plugin specifications

### 3.1 status-title

- State precedence: 🔴 (any session in the current subtree has a pending permission/form or a retry) > 🟡 (anything in the subtree running) > 🟢.
- A failed turn is only shown as 🔴 when the subtree has stopped working. While a parent or sibling is still running, a child failure stays 🟡 until the work settles.
- Retry attention is cleared as soon as the retry actually resumes (`session.step.started`, reasoning/text/tool/compaction activity). A transient retry therefore does not keep the title red for the rest of the turn.
- Subtree resolution uses the host family index plus `parentID` chains, so a subagent's busy/error state reaches its parent. A child failure raises the parent to 🔴 after the subtree stops; continuing the parent (busy) clears the subtree error, matching the V1 fix for stuck red titles.
- Errors older than 10 seconds are cleared on the next idle/success/interrupt event.
- Title text: custom session title when present, otherwise `<project basename> <short session id>`. Fallback titles (`New session - <ISO>`, `Child session - <ISO>`) are treated as absent.
- Non-session routes: `🟢 | OpenCode` on home, `🟢 | <plugin route name>` otherwise.
- Self-healing: writes on events (25 ms debounce) plus a 1 s interval. Control characters are stripped; all renderer calls are guarded.
- Feature flag: `OPENCODE_DISABLE_STATUS_TITLE` (truthy except `0`/`false`).
- The built-in writer is disabled with `terminal.title: false` in `cli.json`. This replaces V1's `OPENCODE_DISABLE_TERMINAL_TITLE` environment variable.

### 3.2 status-done

- Records `Date.now()` on `session.execution.succeeded`, `failed`, and `interrupted` (not `shutdown`).
- Clears the record when that session starts executing (`execution.started`) or reports `busy`/`retry`.
- Renders `done HH:MM` (cross-day: `MM-DD HH:MM`) in `prompt.footer.status` using `theme.text.muted`.
- In-memory only; cleaned on `session.deleted`.
- Feature flag: `OPENCODE_STATUSKIT_DONE=0`.

## 4. Installer specification

- POSIX sh, `set -eu`, idempotent.
- Copies the two v2 plugin directories into `<config>/plugins/`.
- Updates `cli.json` with `node` when the title plugin is installed: creates the file with `$schema` if absent, preserves other keys, sets `terminal.title = false`. Strict JSON only; JSONC files print manual instructions and exit 2.
- Removes recognizable legacy V1 files from `tui-plugins/` and stale V1 entries from `cli.json` (`plugins`) and `tui.json` (`plugin`).
- Removes the obsolete V1 `OPENCODE_DISABLE_TERMINAL_TITLE` marked block from shell rc files.
- `--without-title` copies only the done plugin and does not change `terminal.title`.
- Uninstall removes plugin directories, legacy files/entries, and old marked shell-rc blocks; it leaves `terminal.title` alone (documented).

## 5. Isolated test recipe

No real config, state, auth, or database is touched:

```bash
TEST=$(mktemp -d /tmp/sk-v2.XXXX)
mkdir -p "$TEST/config/opencode/plugins/status-title" "$TEST/config/opencode/plugins/status-done" \
         "$TEST/state" "$TEST/data" "$TEST/cache"
cp <repo>/plugins/v2/status-title/tui.ts   "$TEST/config/opencode/plugins/status-title/"
cp <repo>/plugins/v2/status-done/tui.tsx   "$TEST/config/opencode/plugins/status-done/"
cat > "$TEST/config/opencode/cli.json" <<'EOF'
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "terminal": { "title": false }
}
EOF

cd /tmp
XDG_CONFIG_HOME="$TEST/config" XDG_STATE_HOME="$TEST/state" \
XDG_DATA_HOME="$TEST/data" XDG_CACHE_HOME="$TEST/cache" \
OPENCODE_DB=:memory: opencode --standalone --print-logs
```

Run it under a pseudo-terminal when scripting the check:

```bash
timeout 12 script -qec "env XDG_CONFIG_HOME=... opencode --standalone --print-logs" tty.log
```

Checks:

1. `plugin reconciliation completed ... plugins=16` (14 built-ins + 2 kit plugins), no load errors.
2. Home route emits OSC title `🟢 | OpenCode`.
3. A session route emits `🟢 | <title>`; terminal title changes to `🟡` while executing, `🔴` on retry/failure, and back to `🟢` on success.
4. A child execution failure raises the parent title to 🔴; continuing the parent clears it.
5. After an execution-succeeded event, the prompt footer contains ` done HH:MM`.

## 6. Verification record (2026-11-12)

All checks used the isolated recipe above and the stock 2.2.7 binary.

- Both plugins loaded by directory discovery (`tui.ts`, `tui.tsx`) with no errors.
- OSC title sequence observed across simulated events:
  `🟢 | statuskit state test` → `🟡 | …` → `🔴 | …` (retry/failure) → `🟡 | …` → `🟢 | …`.
- Child-session events observed raising/lowering the parent title:
  `🟢 parent` → `🟡 parent` (child busy) → `🔴 parent` (child failed) → `🟡 parent` (parent resumes) → `🟢 parent`.
- Both plugins active in one TUI: `🟢 → 🟡 → 🔴 → 🟡 → 🟢` title sequence and `done 17:48` rendered together.
- False-red regression (2026-11-17): retry recovery via `session.step.started` returns the title to 🟡 without waiting for the turn to end; a child failure is suppressed while the parent is still running and only surfaces 🔴 after the subtree stops.
- `done 17:24` rendered in `prompt.footer.status` after a simulated successful turn.
- TypeScript check passed with `@opencode/plugin@2.2.7`, `@opentui/core@0.8.1`, `@opentui/solid@0.8.1`, `solid-js@1.9.17`, strict mode.
- Installer exercised in a throwaway `$XDG_CONFIG_HOME` with legacy V1 files/entries: fresh install, idempotent rerun, and uninstall all preserved unrelated `cli.json` keys and left no kit files behind.
- Real install on the author's machine hot-reloaded the running TUI: plugin count went from 14 to 16 with no plugin errors.
