import { build } from "esbuild"
import { mkdir } from "node:fs/promises"
import { fileURLToPath } from "node:url"

const outDir = fileURLToPath(new URL("../tests/.tmp/", import.meta.url))
await mkdir(outDir, { recursive: true })

await build({
  entryPoints: [fileURLToPath(new URL("../plugins/v2/status-done/tui.tsx", import.meta.url))],
  outfile: fileURLToPath(new URL("../tests/.tmp/status-done.mjs", import.meta.url)),
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
})
