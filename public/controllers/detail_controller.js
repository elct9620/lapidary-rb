import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.showPlaceholder()
  }

  showPlaceholder() {
    this.contentTarget.innerHTML = `
      <p class="text-gray-400 text-sm">Select a node or edge in the graph to view details.</p>
    `
  }

  showNode(event) {
    const { id, type, data, label } = event.detail
    const dataEntries = Object.entries(data || {})
      .map(([k, v]) => `<li class="flex justify-between"><span class="text-gray-500">${this.escapeHtml(k)}</span><span class="font-medium">${this.escapeHtml(String(v))}</span></li>`)
      .join("")

    this.contentTarget.innerHTML = `
      <h3 class="font-semibold text-lg mb-2">${this.escapeHtml(label)}</h3>
      <dl class="space-y-1 text-sm mb-3">
        <div class="flex justify-between">
          <dt class="text-gray-500">Type</dt>
          <dd>${this.typeBadge(type)}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-gray-500">ID</dt>
          <dd class="font-mono text-xs break-all">${this.escapeHtml(id)}</dd>
        </div>
      </dl>
      ${dataEntries ? `<h4 class="font-medium text-sm text-gray-600 mb-1">Data</h4><ul class="space-y-1 text-sm">${dataEntries}</ul>` : ""}
    `
  }

  showEdge(event) {
    const { source, target, relationship, observations } = event.detail

    const obsHtml = (observations || []).map(obs => `
      <li class="border-l-2 border-gray-200 pl-3 py-1">
        <div class="text-xs text-gray-400">${this.escapeHtml(obs.observed_at || "")}</div>
        <div class="text-sm">${this.escapeHtml(obs.evidence || "(no evidence)")}</div>
        <div class="text-xs text-gray-500 mt-0.5">Source: ${this.escapeHtml(obs.source_entity_type || "")} #${obs.source_entity_id || ""}</div>
      </li>
    `).join("")

    this.contentTarget.innerHTML = `
      <h3 class="font-semibold text-lg mb-2">${this.escapeHtml(relationship)}</h3>
      <dl class="space-y-1 text-sm mb-3">
        <div class="flex justify-between">
          <dt class="text-gray-500">From</dt>
          <dd class="font-mono text-xs break-all">${this.escapeHtml(source)}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-gray-500">To</dt>
          <dd class="font-mono text-xs break-all">${this.escapeHtml(target)}</dd>
        </div>
      </dl>
      <h4 class="font-medium text-sm text-gray-600 mb-2">Observations (${observations ? observations.length : 0})</h4>
      <ul class="space-y-2">${obsHtml || '<li class="text-sm text-gray-400">No observations</li>'}</ul>
    `
  }

  clear() {
    this.showPlaceholder()
  }

  typeBadge(type) {
    const colors = {
      Rubyist: "bg-blue-100 text-blue-800",
      CoreModule: "bg-green-100 text-green-800",
      Stdlib: "bg-amber-100 text-amber-800"
    }
    const cls = colors[type] || "bg-gray-100 text-gray-800"
    return `<span class="inline-block px-1.5 py-0.5 text-xs font-medium rounded ${cls}">${type}</span>`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
