export type EventHandler = (event: { type: string; data: any }) => void

export interface SessionInfo {
  id: string
  title?: string
  parentID?: string
  location?: { directory?: string }
  time?: { busy?: number; created?: number; updated?: number }
}

export interface HarnessOptions {
  route?: any
  sessions?: SessionInfo[]
  directory?: string
}

/**
 * Minimal fake of the OpenCode TUI plugin context.
 *
 * It implements only the members the two statuskit plugins use. Pass it to
 * `plugin.setup(context as any)` and drive state with `emit`, `setRoute`, and
 * the setter helpers.
 */
export function makeHarness(options: HarnessOptions = {}) {
  const handlers = new Map<string, Set<EventHandler>>()
  const titles: string[] = []
  const sessions = new Map<string, SessionInfo>()
  const permissions = new Map<string, any[]>()
  const forms = new Map<string, any[]>()
  const messages = new Map<string, any[]>()
  const running = new Set<string>()
  const slots: any[] = []
  const directory = options.directory ?? "/tmp/project"
  let route: any = options.route ?? { type: "home" }

  const addSession = (session: SessionInfo) => {
    sessions.set(session.id, {
      location: { directory },
      time: {},
      ...session,
    })
  }
  for (const session of options.sessions ?? []) addSession(session)

  // The host family index returns the root and all descendants. Reconstruct it
  // from the parentID chain so tests can model subagents.
  function family(id: string): string[] {
    let root = id
    const seen = new Set<string>()
    while (!seen.has(root)) {
      seen.add(root)
      const parent = sessions.get(root)?.parentID
      if (!parent) break
      root = parent
    }
    const result = [root]
    for (const [sessionID, session] of sessions) {
      if (sessionID === root) continue
      let current: SessionInfo | undefined = session
      const chain = new Set<string>()
      while (current?.parentID && !chain.has(current.parentID)) {
        chain.add(current.parentID)
        if (current.parentID === root) {
          result.push(sessionID)
          break
        }
        current = sessions.get(current.parentID)
      }
    }
    return result
  }

  const context = {
    app: { version: "2.3.0", channel: "stable" },
    data: {
      on(type: string, handler: EventHandler) {
        if (!handlers.has(type)) handlers.set(type, new Set())
        handlers.get(type)!.add(handler)
        return () => {
          handlers.get(type)?.delete(handler)
        }
      },
      listen() {
        return () => {}
      },
      session: {
        get: (id: string) => sessions.get(id),
        list: () => [...sessions.values()],
        family,
        root: (id: string) => family(id)[0] ?? id,
        status: (id: string) => (running.has(id) ? "running" : "idle"),
        sync: async () => {},
        invalidate: () => {},
        cost: () => 0,
        pending: { list: () => [], sync: async () => {}, invalidate: () => {} },
        message: {
          list: (id: string) => messages.get(id) ?? [],
          get: () => undefined,
          sync: async () => {},
          invalidate: () => {},
        },
        permission: {
          list: (id: string) => permissions.get(id) ?? [],
          sync: async () => {},
          invalidate: () => {},
        },
        form: {
          list: (id: string) => forms.get(id) ?? [],
          sync: async () => {},
          invalidate: () => {},
          reply: async () => {},
          cancel: async () => {},
        },
      },
      location: {
        default: () => ({ directory }),
        sync: async () => {},
        invalidate: () => {},
      },
    },
    ui: {
      router: {
        current: () => route,
        navigate: () => {},
        register: () => () => {},
      },
      slot: (opts: any) => {
        slots.push(opts)
        return () => {}
      },
      toast: { show: () => {} },
      dialog: {},
      tabs: { enabled: () => false },
      model: { current: () => undefined, variant: { list: () => [], set: () => false } },
    },
    renderer: {
      isDestroyed: false,
      setTerminalTitle: (title: string) => {
        titles.push(title)
      },
      nativeScene: {},
      idle: async () => {},
    },
    theme: { text: { muted: "#888888", base: "#ffffff" } },
    location: { directory },
    options: {},
    storage: {
      store: () => [{}, () => {}],
      memory: () => [{}, () => {}],
    },
    keymap: {
      layer: () => () => {},
      dispatch: () => {},
      shortcuts: () => [],
      commands: () => [],
    },
    attention: { notify: async () => ({ ok: true }) },
    client: {},
  }

  function emit(type: string, data: any = {}) {
    for (const handler of handlers.get(type) ?? []) handler({ type, data })
  }

  return {
    context,
    emit,
    titles,
    slots,
    addSession,
    setRoute: (next: any) => {
      route = next
      emit("session.renamed", {})
    },
    setRunning: (id: string, value = true) => {
      if (value) running.add(id)
      else running.delete(id)
    },
    setPermissions: (id: string, items: any[]) => permissions.set(id, items),
    setForms: (id: string, items: any[]) => forms.set(id, items),
    setMessages: (id: string, items: any[]) => messages.set(id, items),
    lastTitle: () => titles[titles.length - 1],
  }
}

export async function flush(ms = 40) {
  await new Promise((resolve) => setTimeout(resolve, ms))
}
