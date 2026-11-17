import test from "node:test"
import assert from "node:assert/strict"

// Built by scripts/build-test-plugin.mjs with a renderer-free JSX runtime.
// @ts-expect-error generated file
import plugin from "./.tmp/status-done-v1.mjs"

function makeV1DoneHarness() {
  const handlers = new Map<string, Set<(event: any) => void>>()
  let render: ((ctx: any, props: any) => any) | undefined

  const api = {
    event: {
      on(type: string, handler: (event: any) => void) {
        if (!handlers.has(type)) handlers.set(type, new Set())
        handlers.get(type)!.add(handler)
        return () => handlers.get(type)?.delete(handler)
      },
    },
    slots: {
      register(options: any) {
        render = options.slots.session_prompt_right
        return () => {
          render = undefined
        }
      },
    },
  }

  function emit(type: string, properties: any = {}) {
    for (const handler of handlers.get(type) ?? []) handler({ type, properties })
  }

  return {
    api,
    emit,
    render: () => {
      assert.ok(render, "session_prompt_right was not registered")
      return render!({ theme: { current: { textMuted: "#888888" } } }, { session_id: "s1" })
    },
    hasSlot: () => Boolean(render),
  }
}

async function setup(t: any) {
  const harness = makeV1DoneHarness()
  const dispose = await plugin.tui(harness.api)
  t.after(() => dispose?.())
  return harness
}

test("legacy done: registers session_prompt_right and renders nothing initially", async (t) => {
  const h = await setup(t)
  assert.ok(h.hasSlot())
  assert.ok(!h.render())
})

test("legacy done: session.idle renders done HH:MM", async (t) => {
  const h = await setup(t)
  h.emit("session.idle", { sessionID: "s1" })
  const element: any = h.render()
  assert.equal(element.type, "box")
  assert.equal(element.props.children.type, "text")
  assert.match(element.props.children.props.children, /^ done \d{2}:\d{2}$/)
})

test("legacy done: busy clears the time", async (t) => {
  const h = await setup(t)
  h.emit("session.idle", { sessionID: "s1" })
  assert.ok(h.render())
  h.emit("session.status", { sessionID: "s1", status: { type: "busy" } })
  assert.ok(!h.render())
})

test("legacy done: session.deleted clears the time", async (t) => {
  const h = await setup(t)
  h.emit("session.idle", { sessionID: "s1" })
  assert.ok(h.render())
  h.emit("session.deleted", { sessionID: "s1" })
  assert.ok(!h.render())
})

test("legacy done: OPENCODE_STATUSKIT_DONE=0 disables the slot", async (t) => {
  process.env.OPENCODE_STATUSKIT_DONE = "0"
  t.after(() => {
    delete process.env.OPENCODE_STATUSKIT_DONE
  })
  const h = await setup(t)
  assert.equal(h.hasSlot(), false)
})
