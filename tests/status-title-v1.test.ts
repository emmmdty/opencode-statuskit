import test from "node:test"
import assert from "node:assert/strict"

// @ts-ignore V1 source has no type declarations
import plugin from "../legacy/opencode-1/plugins/status-title.js"

interface V1Options {
  directory?: string
  sessions?: Array<{ id: string; title?: string; parentID?: string }>
}

async function flush(ms = 40) {
  await new Promise((resolve) => setTimeout(resolve, ms))
}

function makeV1Harness(options: V1Options = {}) {
  const handlers = new Map<string, Set<(event: any) => void>>()
  const titles: string[] = []
  const sessions = new Map<string, any>()
  const permissions = new Map<string, any[]>()
  const questions = new Map<string, any[]>()
  const route = { current: { name: "home" } as any }
  let dispose: (() => void) | undefined
  const directory = options.directory ?? "/tmp/project"

  for (const session of options.sessions ?? []) {
    sessions.set(session.id, { location: { directory }, ...session })
  }

  const api = {
    client: {
      session: {
        get: async ({ sessionID }: { sessionID: string }) => ({ data: sessions.get(sessionID) ?? { id: sessionID } }),
      },
    },
    state: {
      path: { directory },
      session: {
        status: () => undefined,
        permission: (id: string) => permissions.get(id) ?? [],
        question: (id: string) => questions.get(id) ?? [],
      },
    },
    route,
    renderer: {
      setTerminalTitle: (title: string) => titles.push(title),
    },
    event: {
      on(type: string, handler: (event: any) => void) {
        if (!handlers.has(type)) handlers.set(type, new Set())
        handlers.get(type)!.add(handler)
        return () => handlers.get(type)?.delete(handler)
      },
    },
    lifecycle: {
      onDispose(fn: () => void) {
        dispose = fn
      },
    },
  }

  function emit(type: string, properties: any = {}) {
    for (const handler of handlers.get(type) ?? []) handler({ type, properties })
  }

  return {
    api,
    emit,
    titles,
    lastTitle: () => titles[titles.length - 1],
    setRoute: (next: any) => {
      route.current = next
    },
    setPermissions: (id: string, items: any[]) => permissions.set(id, items),
    setQuestions: (id: string, items: any[]) => questions.set(id, items),
    dispose: () => dispose?.(),
  }
}

async function setup(t: any, options: V1Options = {}) {
  const harness = makeV1Harness(options)
  await plugin.tui(harness.api)
  t.after(() => harness.dispose())
  return harness
}

test("legacy title: home route is green OpenCode", async (t) => {
  const h = await setup(t)
  await flush()
  assert.equal(h.lastTitle(), "🟢 | OpenCode")
})

test("legacy title: idle, busy, permission, and idle", async (t) => {
  const h = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  h.emit("session.created", { sessionID: "s1", info: { id: "s1", title: "Build" } })
  h.setRoute({ name: "session", params: { sessionID: "s1" } })
  h.emit("session.updated", { sessionID: "s1", info: { id: "s1", title: "Build" } })
  await flush()
  assert.equal(h.lastTitle(), "🟢 | Build")

  h.emit("session.status", { sessionID: "s1", status: { type: "busy" } })
  await flush()
  assert.equal(h.lastTitle(), "🟡 | Build")

  h.setPermissions("s1", [{ id: "p1" }])
  h.emit("session.updated", { sessionID: "s1", info: { id: "s1", title: "Build" } })
  await flush()
  assert.equal(h.lastTitle(), "🔴 | Build")

  h.setPermissions("s1", [])
  h.emit("session.updated", { sessionID: "s1", info: { id: "s1", title: "Build" } })
  await flush()
  assert.equal(h.lastTitle(), "🟡 | Build")

  h.emit("session.idle", { sessionID: "s1" })
  await flush()
  assert.equal(h.lastTitle(), "🟢 | Build")
})

test("legacy title: retry is red and the next busy clears it", async (t) => {
  const h = await setup(t, { sessions: [{ id: "s1", title: "Build" }] })
  h.emit("session.created", { sessionID: "s1", info: { id: "s1", title: "Build" } })
  h.setRoute({ name: "session", params: { sessionID: "s1" } })
  h.emit("session.status", { sessionID: "s1", status: { type: "retry" } })
  await flush()
  assert.equal(h.lastTitle(), "🔴 | Build")

  h.emit("session.status", { sessionID: "s1", status: { type: "busy" } })
  await flush()
  assert.equal(h.lastTitle(), "🟡 | Build")
})

test("legacy title: a child error raises the parent and busy clears it", async (t) => {
  const h = await setup(t, {
    sessions: [
      { id: "parent", title: "Parent" },
      { id: "child", title: "Child", parentID: "parent" },
    ],
  })
  h.emit("session.created", { sessionID: "parent", info: { id: "parent", title: "Parent" } })
  h.emit("session.created", { sessionID: "child", info: { id: "child", title: "Child", parentID: "parent" } })
  h.setRoute({ name: "session", params: { sessionID: "parent" } })
  h.emit("session.error", { sessionID: "child", error: { name: "UnknownError" } })
  await flush()
  assert.equal(h.lastTitle(), "🔴 | Parent")

  h.emit("session.status", { sessionID: "parent", status: { type: "busy" } })
  await flush()
  assert.equal(h.lastTitle(), "🟡 | Parent")
})

test("legacy title: fallback uses the project basename and short id", async (t) => {
  const h = await setup(t, {
    directory: "/tmp/my-project",
    sessions: [{ id: "abcdef12", title: "New session - 2026-11-17T12:00:00.000Z" }],
  })
  h.emit("session.created", {
    sessionID: "abcdef12",
    info: { id: "abcdef12", title: "New session - 2026-11-17T12:00:00.000Z" },
  })
  h.setRoute({ name: "session", params: { sessionID: "abcdef12" } })
  h.emit("session.updated", {
    sessionID: "abcdef12",
    info: { id: "abcdef12", title: "New session - 2026-11-17T12:00:00.000Z" },
  })
  await flush()
  assert.equal(h.lastTitle(), "🟢 | my-project abcdef12")
})

test("legacy title: OPENCODE_DISABLE_STATUS_TITLE disables writes", async (t) => {
  process.env.OPENCODE_DISABLE_STATUS_TITLE = "1"
  t.after(() => {
    delete process.env.OPENCODE_DISABLE_STATUS_TITLE
  })
  const h = await setup(t, { sessions: [{ id: "s1", title: "Off" }] })
  h.emit("session.created", { sessionID: "s1", info: { id: "s1", title: "Off" } })
  h.setRoute({ name: "session", params: { sessionID: "s1" } })
  h.emit("session.status", { sessionID: "s1", status: { type: "busy" } })
  await flush()
  assert.equal(h.titles.length, 0)
})
