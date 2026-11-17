import { build } from "esbuild"
import { mkdir } from "node:fs/promises"
import { fileURLToPath } from "node:url"

const outDir = fileURLToPath(new URL("../tests/.tmp/", import.meta.url))
await mkdir(outDir, { recursive: true })

const common = {
  bundle: true,
  platform: "node",
  format: "esm",
  target: "node20",
  external: ["solid-js", "@opencode/plugin/tui", "@opentui/core"],
  alias: {
    "@opentui/solid/jsx-runtime": fileURLToPath(new URL("../tests/fake-jsx-runtime.ts", import.meta.url)),
  },
  jsx: "automatic",
  jsxImportSource: "@opentui/solid",
  logLevel: "warning",
}

await build({
  ...common,
  entryPoints: [fileURLToPath(new URL("../plugins/v2/status-done/tui.tsx", import.meta.url))],
  outfile: fileURLToPath(new URL("../tests/.tmp/status-done.mjs", import.meta.url)),
})

await build({
  ...common,
  entryPoints: [fileURLToPath(new URL("../legacy/opencode-1/plugins/status-done.tsx", import.meta.url))],
  outfile: fileURLToPath(new URL("../tests/.tmp/status-done-v1.mjs", import.meta.url)),
})
