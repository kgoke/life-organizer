import { Controller } from "@hotwired/stimulus"

// Shows the custom RRULE field when "Custom rule…" is picked.
export default class extends Controller {
  static targets = ["select", "custom"]

  toggle() {
    this.customTarget.classList.toggle("hidden", this.selectTarget.value !== "custom")
  }
}
