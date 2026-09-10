import { createSignal } from "solid-js"

function fmt(ts) {
  const d = new Date(ts)
  const now = new Date()
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`
  const sameDay =
    d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()
  if (sameDay) return hm
  return `${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")} ${hm}`
}

export default {
  id: "local.status-done",
  tui: async (api) => {
    if (process.env.OPENCODE_STATUSKIT_DONE === "0") return

    const [done, setDone] = createSignal(new Map())

    api.event.on("session.idle", (event) => {
      const sessionID = event.properties?.sessionID
      if (!sessionID) return
      setDone((prev) => {
        const next = new Map(prev)
        next.set(sessionID, Date.now())
        return next
      })
    })

    api.event.on("session.status", (event) => {
      const sessionID = event.properties?.sessionID
      const type = event.properties?.status?.type
      if (!sessionID || type !== "busy") return
      setDone((prev) => {
        if (!prev.has(sessionID)) return prev
        const next = new Map(prev)
        next.delete(sessionID)
        return next
      })
    })

    api.event.on("session.deleted", (event) => {
      const sessionID = event.properties?.sessionID ?? event.properties?.info?.id
      if (!sessionID) return
      setDone((prev) => {
        if (!prev.has(sessionID)) return prev
        const next = new Map(prev)
        next.delete(sessionID)
        return next
      })
    })

    api.slots.register({
      order: 300,
      slots: {
        session_prompt_right(ctx, props) {
          const ts = done().get(props?.session_id)
          if (!ts) return null
          const theme = ctx?.theme?.current
          return (
            <box flexShrink={0} wrapMode="none">
              <text fg={theme?.textMuted}>{` · done ${fmt(ts)}`}</text>
            </box>
          )
        },
      },
    })
  },
}
