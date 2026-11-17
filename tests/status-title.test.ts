import test from "node:test"
import assert from "node:assert/strict"
import plugin from "../plugins/v2/status-title/tui"
import { makeHarness, flush, type HarnessOptions } from "./harness"

async function setup(t: any, options: HarnessOptions = {}) {
  const harness = makeHarness(options)
  const dispose = await plugin.setup(harness.context as any)
  t.after(() => dispose?.())
  return harness
}

test("home route shows the green OpenCode title", async (t) => {
  const harness = await setup(t)
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | OpenCode")
})

test("session title follows idle, busy, permission, and success", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.setRoute({ type: "session", sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | Build")

  harness.emit("session.execution.started", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟡 | Build")

  harness.setPermissions("s1", [{ id: "p1" }])
  harness.emit("permission.asked", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🔴 | Build")

  harness.setPermissions("s1", [])
  harness.emit("permission.replied", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟡 | Build")

  harness.emit("session.execution.succeeded", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | Build")
})

test("a retry clears as soon as the next step starts", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.setRoute({ type: "session", sessionID: "s1" })
  harness.emit("session.execution.started", { sessionID: "s1" })
  harness.emit("session.retry.scheduled", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🔴 | Build")

  harness.emit("session.step.started", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟡 | Build")
})

test("a child failure stays yellow while the parent runs, then turns red", async (t) => {
  const harness = await setup(t, {
    sessions: [
      { id: "parent", title: "Parent" },
      { id: "child", title: "Child", parentID: "parent" },
    ],
  })
  harness.setRoute({ type: "session", sessionID: "parent" })
  harness.emit("session.execution.started", { sessionID: "parent" })
  harness.emit("session.execution.started", { sessionID: "child" })
  harness.emit("session.execution.failed", { sessionID: "child" })
  await flush()
  assert.equal(harness.lastTitle(), "🟡 | Parent")

  harness.emit("session.execution.succeeded", { sessionID: "parent" })
  await flush()
  assert.equal(harness.lastTitle(), "🔴 | Parent")

  harness.emit("session.deleted", { sessionID: "child" })
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | Parent")
})

test("a form request raises attention until it is cancelled", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Forms" }] })
  harness.setRoute({ type: "session", sessionID: "s1" })
  harness.setForms("s1", [{ id: "f1" }])
  harness.emit("form.created", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🔴 | Forms")

  harness.setForms("s1", [])
  harness.emit("form.cancelled", { sessionID: "s1" })
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | Forms")
})

test("the fallback title uses the project basename and short session id", async (t) => {
  const harness = await setup(t, {
    directory: "/tmp/my-project",
    sessions: [
      {
        id: "abcdef12",
        title: "New session - 2026-11-17T12:00:00.000Z",
        location: { directory: "/tmp/my-project" },
      },
    ],
  })
  harness.setRoute({ type: "session", sessionID: "abcdef12" })
  await flush()
  assert.equal(harness.lastTitle(), "🟢 | my-project abcdef12")
})

test("OPENCODE_DISABLE_STATUS_TITLE stops all title writes", async (t) => {
  process.env.OPENCODE_DISABLE_STATUS_TITLE = "1"
  t.after(() => {
    delete process.env.OPENCODE_DISABLE_STATUS_TITLE
  })
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Off" }] })
  harness.setRoute({ type: "session", sessionID: "s1" })
  harness.emit("session.execution.started", { sessionID: "s1" })
  await flush()
  assert.equal(harness.titles.length, 0)
})
