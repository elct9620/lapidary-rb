import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "queryInput", "resultsList", "status"]

  async search(event) {
    event.preventDefault()

    const type = this.typeSelectTarget.value
    const q = this.queryInputTarget.value.trim()
    const params = new URLSearchParams()

    if (type) params.set("type", type)
    if (q) params.set("q", q)
    params.set("limit", "20")
    params.set("offset", "0")

    this.statusTarget.textContent = "Searching..."
    this.resultsListTarget.innerHTML = ""

    try {
      const response = await fetch(`/graph/nodes?${params}`)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this.renderResults(data.nodes, data.total)
    } catch (error) {
      this.statusTarget.textContent = `Error: ${error.message}`
    }
  }

  renderResults(nodes, total) {
    this.statusTarget.textContent = `${total} node${total === 1 ? "" : "s"} found`
    this.resultsListTarget.innerHTML = ""

    nodes.forEach(node => {
      const li = document.createElement("li")
      li.className = "px-3 py-2 cursor-pointer hover:bg-gray-100 rounded text-sm truncate"
      li.dataset.action = "click->search#selectNode"
      li.dataset.nodeId = node.id
      li.dataset.nodeType = node.type
      li.dataset.nodeData = JSON.stringify(node.data)

      const badge = this.typeBadge(node.type)
      const name = node.data.display_name || node.id.split("://")[1]
      li.innerHTML = `${badge} <span>${this.escapeHtml(name)}</span>`

      this.resultsListTarget.appendChild(li)
    })
  }

  selectNode(event) {
    const li = event.currentTarget
    this.dispatch("node-selected", {
      detail: {
        nodeId: li.dataset.nodeId,
        nodeType: li.dataset.nodeType,
        nodeData: JSON.parse(li.dataset.nodeData)
      }
    })
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
