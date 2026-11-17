import test from "node:test"
import assert from "node:assert/strict"
import { makeHarness, type HarnessOptions } from "./harness"

// Built by scripts/build-test-plugin.mjs with a renderer-free JSX runtime.
// @ts-expect-error generated file
import plugin from "./.tmp/status-done.mjs"

async function setup(t: any, options: HarnessOptions = {}) {
  const harness = makeHarness(options)
  const dispose = await plugin.setup(harness.context as any)
  t.after(() => dispose?.())
  return harness
}

function render(harness: ReturnType<typeof makeHarness>) {
  const slot = harness.slots[0]
  assert.equal(slot.append, "prompt.footer.status")
  return slot.render({ sessionID: "s1", mode: "normal", showDetails: false })
}

test("registers the prompt footer slot and renders nothing before a turn ends", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  assert.equal(harness.slots.length, 1)
  assert.equal(harness.slots[0].append, "prompt.footer.status")
  assert.ok(!render(harness))
})

test("renders done HH:MM after a successful turn and clears on the next turn", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.emit("session.execution.succeeded", { sessionID: "s1" })
  const element: any = render(harness)
  assert.equal(element.type, "box")
  assert.equal(element.props.children.type, "text")
  assert.match(element.props.children.props.children, /^ done \d{2}:\d{2}$/)

  harness.emit("session.execution.started", { sessionID: "s1" })
  assert.ok(!render(harness))
})

test("falls back to the last projected idle marker", async (t) => {
  const at = new Date()
  at.setHours(12, 34, 0, 0)
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.setMessages("s1", [{ type: "idle", time: { created: at.getTime() } }])
  const element: any = render(harness)
  assert.equal(element.type, "box")
  assert.equal(element.props.children.props.children, " done 12:34")
})

test("hides a stale done time when the session has started again", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.emit("session.execution.succeeded", { sessionID: "s1" })
  const live = render(harness)
  assert.ok(live)

  const session = harness.context.data.session.get("s1") as any
  session.time = { busy: Date.now() + 1000 }
  assert.ok(!render(harness))
})

test("clears the time when the session is deleted", async (t) => {
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  harness.emit("session.execution.succeeded", { sessionID: "s1" })
  assert.ok(render(harness))
  harness.emit("session.deleted", { sessionID: "s1" })
  assert.ok(!render(harness))
})

test("OPENCODE_STATUSKIT_DONE=0 disables the slot", async (t) => {
  process.env.OPENCODE_STATUSKIT_DONE = "0"
  t.after(() => {
    delete process.env.OPENCODE_STATUSKIT_DONE
  })
  const harness = await setup(t, { sessions: [{ id: "s1", title: "Off" }] })
  assert.equal(harness.slots.length, 0)
})
