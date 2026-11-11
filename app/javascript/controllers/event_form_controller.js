import { Controller } from "@hotwired/stimulus"

// Switches the event form between timed and all-day inputs.
export default class extends Controller {
  static targets = ["allDay", "timed", "dated", "timedInput", "datedInput"]

  toggleAllDay() {
    const allDay = this.allDayTarget.checked
    this.timedTarget.hidden = allDay
    this.datedTarget.hidden = !allDay
    this.timedInputTargets.forEach((el) => (el.disabled = allDay))
    this.datedInputTargets.forEach((el) => (el.disabled = !allDay))
    if (allDay) {
      const [start, end] = this.timedInputTargets.map((el) => el.value.slice(0, 10))
      const [ds, de] = this.datedInputTargets
      if (start) ds.value = start
      if (end) de.value = end
    }
  }
}
