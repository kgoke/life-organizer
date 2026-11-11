import { Controller } from "@hotwired/stimulus"

// The quick jot box: Ctrl/Cmd+Enter saves, and the box grows as you type.
export default class extends Controller {
  static targets = ["input"]

  keydown(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }

  grow() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = `${Math.min(el.scrollHeight, 320)}px`
  }
}
