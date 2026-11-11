import { Controller } from "@hotwired/stimulus"

// The calendar page: FullCalendar (loaded as a global script) wired to the JSON API.
// - shaded "Free" background spaces show the open time within working hours
// - drag a task (or a jot, which becomes a task) from the side list onto the calendar to block time
// - drag or resize events and blocks to move them (repeating events: just that occurrence)
// - drag a "Due" chip into a time slot to block time for that task
// - click an empty slot to add an event; click an event to edit it
export default class extends Controller {
  static targets = ["calendar", "tasks"]
  static values = { eventsUrl: String, tasksUrl: String, jotsUrl: String, newUrl: String, date: String, view: String, dayStart: String, dayEnd: String }

  connect() {
    if (!window.FullCalendar) return
    const phone = window.matchMedia("(max-width: 720px)").matches
    const { Calendar, Draggable } = window.FullCalendar

    if (this.hasTasksTarget) {
      this.draggable = new Draggable(this.tasksTarget, {
        itemSelector: ".drag-task",
        longPressDelay: 250,
        eventData: (el) => ({
          title: el.dataset.title,
          duration: { minutes: parseInt(el.dataset.minutes || "30", 10) },
          create: false,
          extendedProps: { taskId: el.dataset.taskId, jotId: el.dataset.jotId },
        }),
      })
    }

    this.calendar = new Calendar(this.calendarTarget, {
      initialView: this.viewValue || (phone ? "timeGridDay" : "timeGridWeek"),
      initialDate: this.dateValue || undefined,
      headerToolbar: phone
        ? { left: "prev,next today", center: "title", right: "timeGridDay,listWeek,dayGridMonth" }
        : { left: "prev,next today", center: "title", right: "timeGridDay,timeGridWeek,dayGridMonth,listWeek" },
      buttonText: { today: "Today", day: "Day", week: "Week", month: "Month", list: "List" },
      height: "auto",
      lazyFetching: false,
      nowIndicator: true,
      firstDay: 1,
      editable: true,
      droppable: true,
      selectable: true,
      selectMirror: true,
      longPressDelay: 300,
      slotDuration: "00:30:00",
      snapDuration: "00:15:00",
      scrollTime: this.dayStartValue || "08:00",
      businessHours: { daysOfWeek: [1, 2, 3, 4, 5], startTime: this.dayStartValue || "08:00", endTime: this.dayEndValue || "18:00" },
      eventTimeFormat: { hour: "numeric", minute: "2-digit", meridiem: "short" },
      events: (info, ok, fail) => this.load(info).then(ok).catch(fail),
      select: (info) => this.newEvent(info),
      eventClick: (info) => this.open(info),
      eventDrop: (info) => this.moved(info),
      eventResize: (info) => this.moved(info),
      eventReceive: (info) => this.received(info),
      eventDidMount: (info) => {
        const p = info.event.extendedProps
        if (p.kind === "time_block") info.el.classList.add("fc-time-block")
        if (p.kind === "due") info.el.classList.add("fc-due")
        if (p.done) info.el.classList.add("fc-done")
      },
    })
    this.calendar.render()
  }

  disconnect() {
    this.draggable?.destroy()
    this.calendar?.destroy()
  }

  async load(info) {
    const range = new URLSearchParams({ start: info.start.toISOString(), end: info.end.toISOString() })
    const days = new URLSearchParams({
      status: "open", due_after: info.startStr.slice(0, 10), due_before: info.endStr.slice(0, 10), top_level_only: "false", limit: "500",
    })
    const [events, tasks] = await Promise.all([this.get(`${this.eventsUrlValue}?${range}`), this.get(`${this.tasksUrlValue}?${days}`)])
    const items = events.map((e) => ({
      id: `${e.id}|${e.occurrence || ""}`,
      title: e.title,
      start: e.start,
      end: e.end,
      allDay: e.all_day,
      color: e.color,
      extendedProps: { eventId: e.id, occurrence: e.occurrence, kind: e.kind, recurring: e.recurring, taskId: e.task_id, done: e.task_status === "done" },
    }))
    tasks.forEach((t) => {
      const timed = !!t.due_time
      items.push({
        id: `task-${t.id}`,
        title: `Due: ${t.title}`,
        start: timed ? `${t.due_date}T${t.due_time}` : t.due_date,
        allDay: !timed,
        durationEditable: false,
        color: "transparent",
        textColor: "var(--text)",
        extendedProps: { kind: "due", taskId: t.id, minutes: t.estimate_minutes || 30 },
      })
    })
    if (this.calendar?.view.type.startsWith("timeGrid")) items.push(...this.freeGaps(info, items))
    return items
  }

  // Background "Free" spaces: working hours minus timed events and blocks, 15 minutes or longer.
  freeGaps(info, items) {
    const [sh, sm] = (this.dayStartValue || "08:00").split(":").map(Number)
    const [eh, em] = (this.dayEndValue || "18:00").split(":").map(Number)
    const busy = items
      .filter((i) => !i.allDay && i.end && i.extendedProps.kind !== "due")
      .map((i) => [new Date(i.start), new Date(i.end)])
      .sort((a, b) => a[0] - b[0])
    const gaps = []
    const now = new Date()
    for (let day = new Date(info.start); day < info.end; day.setDate(day.getDate() + 1)) {
      const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), sh, sm)
      const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate(), eh, em)
      if (dayEnd <= now) continue
      let cursor = dayStart < now ? new Date(Math.ceil(now / 900e3) * 900e3) : dayStart
      const push = (from, to) => {
        const minutes = Math.round((to - from) / 60000)
        if (minutes >= 15) gaps.push({ start: from, end: to, display: "background", classNames: ["fc-free"], title: `Free ${this.duration(minutes)}`, extendedProps: { kind: "free" } })
      }
      for (const [s, e] of busy) {
        if (e <= cursor || s >= dayEnd) continue
        if (s > cursor) push(cursor, s)
        if (e > cursor) cursor = new Date(e)
        if (cursor >= dayEnd) break
      }
      if (cursor < dayEnd) push(cursor, dayEnd)
    }
    return gaps
  }

  duration(minutes) {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    return h && m ? `${h}h ${m}m` : h ? `${h}h` : `${m}m`
  }

  newEvent(info) {
    const params = new URLSearchParams({ start: info.startStr, end: info.endStr, all_day: info.allDay })
    this.calendar.unselect()
    Turbo.visit(`${this.newUrlValue}?${params}`)
  }

  open(info) {
    info.jsEvent.preventDefault()
    const p = info.event.extendedProps
    if (p.kind === "free") return
    if (p.kind === "due" || (p.kind === "time_block" && p.taskId)) return Turbo.visit(`/tasks/${p.taskId}/edit`)
    const q = p.recurring && p.occurrence ? `?occurrence=${encodeURIComponent(p.occurrence)}` : ""
    Turbo.visit(`/events/${p.eventId}/edit${q}`)
  }

  async moved(info) {
    const ev = info.event
    const p = ev.extendedProps
    try {
      if (p.kind === "due") {
        if (ev.allDay) {
          await this.send("PATCH", `${this.tasksUrlValue}/${p.taskId}`, { due_date: ev.startStr.slice(0, 10) })
        } else {
          await this.send("POST", `${this.tasksUrlValue}/${p.taskId}/schedule`, { start: ev.start.toISOString(), duration_minutes: p.minutes })
        }
        return this.calendar.refetchEvents()
      }
      let url = `${this.eventsUrlValue}/${p.eventId}`
      if (p.recurring) {
        if (!confirm("This is a repeating event. Move just this one?")) return info.revert()
        url += `?occurrence=${encodeURIComponent(p.occurrence)}`
      }
      const body = ev.allDay
        ? { start: ev.startStr.slice(0, 10), end: (ev.endStr || ev.startStr).slice(0, 10), all_day: true }
        : { start: ev.start.toISOString(), end: (ev.end || new Date(ev.start.getTime() + 3600e3)).toISOString(), all_day: false }
      await this.send("PATCH", url, body)
      this.calendar.refetchEvents()
    } catch (err) {
      alert(err.message)
      info.revert()
    }
  }

  async received(info) {
    const ev = info.event
    const { taskId, jotId } = ev.extendedProps
    try {
      const start = ev.allDay ? `${ev.startStr.slice(0, 10)}T${this.dayStartValue || "09:00"}` : ev.start.toISOString()
      const minutes = Math.round(((ev.end || ev.start) - ev.start) / 60000) || undefined
      if (jotId) {
        await this.send("POST", `${this.jotsUrlValue}/${jotId}/convert`, { schedule_start: start, duration_minutes: minutes })
        this.tasksTarget.querySelector(`[data-jot-id="${jotId}"]`)?.remove()
      } else {
        await this.send("POST", `${this.tasksUrlValue}/${taskId}/schedule`, { start, duration_minutes: minutes })
        this.tasksTarget.querySelector(`[data-task-id="${taskId}"]`)?.remove()
      }
    } catch (err) {
      alert(err.message)
    } finally {
      ev.remove()
      this.calendar.refetchEvents()
    }
  }

  async get(url) {
    const res = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    if (!res.ok) throw new Error(`Couldn't load the calendar (${res.status})`)
    return res.json()
  }

  async send(method, url, body) {
    const res = await fetch(url, {
      method,
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify(body),
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error || `Request failed (${res.status})`)
    }
    return res.status === 204 ? null : res.json()
  }
}
