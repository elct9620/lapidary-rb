import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["directionSelect", "observedAfter", "observedBefore"]

  apply() {
    this.dispatch("filter-changed", {
      detail: {
        direction: this.directionSelectTarget.value,
        observedAfter: this.observedAfterTarget.value
          ? new Date(this.observedAfterTarget.value).toISOString()
          : "",
        observedBefore: this.observedBeforeTarget.value
          ? new Date(this.observedBeforeTarget.value).toISOString()
          : ""
      }
    })
  }
}
