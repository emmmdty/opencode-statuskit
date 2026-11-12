import { Plugin } from "@opencode/plugin/tui"
import { basename as pathBasename } from "node:path"

const SYMBOL = {
  idle: "🟢",
  busy: "🟡",
  attention: "🔴",
}

const FALLBACK_TITLE = /^(New session|Child session) - \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
const IDLE_ERROR_GRACE_MS = 10000

function clean(value: unknown, fallback: string) {
  const text = String(value ?? "")
    .replace(/[\u0000-\u001f\u007f-\u009f\u00ad\u200b-\u200f\u202a-\u202e]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
  return text || fallback
}

function compact(value: string, max = 48) {
  const chars = Array.from(value)
  if (chars.length <= max) return value
  return chars.slice(0, max - 3).join("") + "..."
}

function basename(input: string | undefined) {
  const path = clean(input, "OpenCode").replace(/\/+$/, "")
  return pathBasename(path) || "OpenCode"
}

function isDisabled() {
  const disabled = process.env.OPENCODE_DISABLE_STATUS_TITLE
  return Boolean(disabled && disabled !== "0" && disabled.toLowerCase() !== "false")
}

export default Plugin.define({
  id: "local.status-title",
  setup(context) {
    if (isDisabled()) return

    const errored = new Map<string, number>()
    const retry = new Set<string>()
    const statuses = new Map<string, "idle" | "retry" | "busy">()
    const parents = new Map<string, string>()
    const syncing = new Set<string>()
    const unsubscribes: Array<() => void> = []
    let disposed = false
    let scheduled = false
    let timer: ReturnType<typeof setTimeout> | undefined

    // The host keeps a session family index (root + descendants). Resolve the
    // descendants of one session so a subagent's state can reach its parent.
    function descendants(sessionID: string) {
      const ids = new Set<string>([sessionID])
      for (const id of context.data.session.family(sessionID) ?? []) {
        if (id === sessionID) continue
        let current: string | undefined = id
        const seen = new Set<string>()
        while (current && !seen.has(current)) {
          seen.add(current)
          const parent: string | undefined =
            context.data.session.get(current)?.parentID ?? parents.get(current)
          if (!parent) break
          if (parent === sessionID) {
            ids.add(id)
            break
          }
          current = parent
        }
      }
      return [...ids]
    }

    function forget(sessionID: string) {
      errored.delete(sessionID)
      retry.delete(sessionID)
      statuses.delete(sessionID)
      syncing.delete(sessionID)
    }

    function forgetDeep(sessionID: string) {
      forget(sessionID)
      for (const [child, parent] of parents) {
        if (parent === sessionID) forgetDeep(child)
      }
      parents.delete(sessionID)
    }

    function clearErroredDeep(sessionID: string) {
      for (const id of descendants(sessionID)) errored.delete(id)
    }

    function clearStaleErroredDeep(sessionID: string, now: number) {
      for (const id of descendants(sessionID)) {
        const at = errored.get(id)
        if (at !== undefined && now - at > IDLE_ERROR_GRACE_MS) errored.delete(id)
      }
    }

    function statusOf(sessionID: string) {
      // The host marks a session running on execution start; raw status events
      // cover retry and any execution event the data store has not seen yet.
      if (context.data.session.status(sessionID) === "running") return "busy"
      return statuses.get(sessionID) ?? "idle"
    }

    function hasAttention(sessionID: string) {
      for (const id of descendants(sessionID)) {
        if (errored.has(id) && statusOf(id) !== "busy") return true
        if (retry.has(id) || statusOf(id) === "retry") return true
        const permissions = context.data.session.permission.list(id)
        if (permissions && permissions.length > 0) return true
        const forms = context.data.session.form.list(id)
        if (forms && forms.length > 0) return true
      }
      return false
    }

    function stateFor(sessionID: string) {
      if (hasAttention(sessionID)) return "attention"
      for (const id of descendants(sessionID)) {
        if (statusOf(id) === "busy") return "busy"
      }
      return "idle"
    }

    function displayTitle(sessionID: string) {
      const info = context.data.session.get(sessionID)
      if (!info && !syncing.has(sessionID)) {
        syncing.add(sessionID)
        void context.data.session.sync(sessionID).catch(() => syncing.delete(sessionID))
      }

      const title = info?.title
      if (title && !FALLBACK_TITLE.test(title)) {
        return compact(clean(title, sessionID.slice(0, 8)))
      }

      const directory =
        info?.location?.directory ?? context.location?.directory ?? context.data.location.default().directory
      return compact(`${basename(directory)} ${sessionID.slice(0, 8)}`)
    }

    function setTitle() {
      if (disposed) return
      if (isDisabled()) return
      try {
        if (context.renderer.isDestroyed) return

        const route = context.ui.router.current()
        let next = `${SYMBOL.idle} | OpenCode`

        if (route.type === "session") {
          next = `${SYMBOL[stateFor(route.sessionID)]} | ${displayTitle(route.sessionID)}`
        } else if (route.type === "plugin") {
          next = `${SYMBOL.idle} | ${compact(clean(route.name, "OpenCode"))}`
        }

        context.renderer.setTerminalTitle(next)
      } catch {
        // The renderer can disappear while the TUI is shutting down.
      }
    }

    function scheduleTitleUpdate() {
      if (scheduled || disposed) return
      scheduled = true
      setTimeout(() => {
        scheduled = false
        setTitle()
      }, 25)
    }

    function subscribe() {
      unsubscribes.push(
        context.data.on("session.created", (event) => {
          const { sessionID, parentID } = event.data
          if (parentID) parents.set(sessionID, parentID)
          scheduleTitleUpdate()
        }),
        context.data.on("session.forked", (event) => {
          parents.set(event.data.sessionID, event.data.parentID)
          scheduleTitleUpdate()
        }),
        context.data.on("session.renamed", () => scheduleTitleUpdate()),
        context.data.on("session.deleted", (event) => {
          forgetDeep(event.data.sessionID)
          scheduleTitleUpdate()
        }),
        context.data.on("session.status", (event) => {
          const { sessionID, status } = event.data
          statuses.set(sessionID, status.type)
          retry.delete(sessionID)
          if (status.type === "retry") retry.add(sessionID)
          if (status.type === "busy") clearErroredDeep(sessionID)
          if (status.type === "idle") clearStaleErroredDeep(sessionID, Date.now())
          scheduleTitleUpdate()
        }),
        context.data.on("session.retry.scheduled", (event) => {
          retry.add(event.data.sessionID)
          scheduleTitleUpdate()
        }),
        context.data.on("session.execution.started", (event) => {
          statuses.set(event.data.sessionID, "busy")
          retry.delete(event.data.sessionID)
          clearErroredDeep(event.data.sessionID)
          scheduleTitleUpdate()
        }),
        context.data.on("session.execution.succeeded", (event) => {
          statuses.set(event.data.sessionID, "idle")
          retry.delete(event.data.sessionID)
          clearStaleErroredDeep(event.data.sessionID, Date.now())
          scheduleTitleUpdate()
        }),
        context.data.on("session.execution.failed", (event) => {
          statuses.set(event.data.sessionID, "idle")
          retry.delete(event.data.sessionID)
          errored.set(event.data.sessionID, Date.now())
          scheduleTitleUpdate()
        }),
        context.data.on("session.execution.interrupted", (event) => {
          statuses.set(event.data.sessionID, "idle")
          retry.delete(event.data.sessionID)
          clearStaleErroredDeep(event.data.sessionID, Date.now())
          scheduleTitleUpdate()
        }),
        context.data.on("session.idle", (event) => {
          statuses.set(event.data.sessionID, "idle")
          retry.delete(event.data.sessionID)
          clearStaleErroredDeep(event.data.sessionID, Date.now())
          scheduleTitleUpdate()
        }),
        context.data.on("permission.asked", () => scheduleTitleUpdate()),
        context.data.on("permission.replied", () => scheduleTitleUpdate()),
        context.data.on("form.created", () => scheduleTitleUpdate()),
        context.data.on("form.replied", () => scheduleTitleUpdate()),
        context.data.on("form.cancelled", () => scheduleTitleUpdate()),
      )
    }

    subscribe()
    timer = setInterval(setTitle, 1000)
    setTitle()

    return () => {
      disposed = true
      if (timer) clearInterval(timer)
      for (const unsubscribe of unsubscribes.splice(0)) unsubscribe()
    }
  },
})
