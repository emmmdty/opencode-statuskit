import { Plugin } from "@opencode/plugin/tui"
import { createSignal, Show } from "solid-js"

function fmt(ts: number) {
  const d = new Date(ts)
  const now = new Date()
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`
  const sameDay =
    d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()
  if (sameDay) return hm
  return `${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")} ${hm}`
}

export default Plugin.define({
  id: "local.status-done",
  setup(context) {
    if (process.env.OPENCODE_STATUSKIT_DONE === "0") return

    const [done, setDone] = createSignal(new Map<string, number>())

    function markDone(sessionID: string | undefined) {
      if (!sessionID) return
      setDone((prev) => {
        const next = new Map(prev)
        next.set(sessionID, Date.now())
        return next
      })
    }

    function clearDone(sessionID: string | undefined) {
      if (!sessionID) return
      setDone((prev) => {
        if (!prev.has(sessionID)) return prev
        const next = new Map(prev)
        next.delete(sessionID)
        return next
      })
    }

    function lastIdleAt(sessionID: string) {
      const messages = context.data.session.message.list(sessionID)
      if (!messages) return undefined
      for (let index = messages.length - 1; index >= 0; index--) {
        const message = messages[index]
        if (message.type === "idle") return message.time?.created
      }
      return undefined
    }

    // Prefer the event timestamp, then fall back to the session's projected
    // idle marker. A plugin hot-loaded after a turn, or an event missed during
    // a reconnect, still shows the last completion time.
    function doneAt(sessionID: string) {
      if (context.data.session.status(sessionID) === "running") return undefined
      const info = context.data.session.get(sessionID)
      const busy = info?.time?.busy
      const live = done().get(sessionID)
      if (live !== undefined) {
        if (busy !== undefined && busy > live) return undefined
        return live
      }
      const idle = lastIdleAt(sessionID)
      if (idle !== undefined && (busy === undefined || busy <= idle)) return idle
      return undefined
    }

    const unsubscribes = [
      context.data.on("session.execution.succeeded", (event) => markDone(event.data.sessionID)),
      context.data.on("session.execution.failed", (event) => markDone(event.data.sessionID)),
      context.data.on("session.execution.interrupted", (event) => {
        if (event.data.reason !== "shutdown") markDone(event.data.sessionID)
      }),
      context.data.on("session.execution.started", (event) => clearDone(event.data.sessionID)),
      context.data.on("session.status", (event) => {
        if (event.data.status.type === "busy" || event.data.status.type === "retry") clearDone(event.data.sessionID)
      }),
      context.data.on("session.idle", (event) => markDone(event.data.sessionID)),
      context.data.on("session.deleted", (event) => clearDone(event.data.sessionID)),
    ]

    const unregister = context.ui.slot({
      append: "prompt.footer.status",
      render: (input) => {
        const sessionID = input.sessionID
        if (!sessionID) return null
        // Show must own the reactive reads: the slot component body runs once,
        // so reading doneAt() directly here would not re-render on updates.
        return (
          <Show when={doneAt(sessionID)}>
            {(ts) => (
              <box flexShrink={0}>
                <text wrapMode="none" fg={context.theme.text.muted}>{` done ${fmt(ts())}`}</text>
              </box>
            )}
          </Show>
        )
      },
    })

    return () => {
      for (const unsubscribe of unsubscribes) unsubscribe()
      unregister()
    }
  },
})
