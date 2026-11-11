import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  async copy(event) {
    event.preventDefault()
    const button = event.currentTarget
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
      const label = button.textContent
      button.textContent = "Copied"
      setTimeout(() => (button.textContent = label), 1500)
    } catch {
      window.getSelection().selectAllChildren(this.sourceTarget)
    }
  }
}
