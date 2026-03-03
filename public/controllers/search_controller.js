import { Controller } from "@hotwired/stimulus"
import { typeBadge, escapeHtml } from "./helpers.js"
import { LoadingGuard } from "./loading_guard.js"

export default class extends Controller {
  static targets = ["typeSelect", "queryInput", "resultsList", "status", "loadMoreButton", "submitButton", "loadMoreBtn"]

  connect() {
    this.pageSize = 20
    this.currentOffset = 0
    this.currentTotal = 0

    this.searchGuard = new LoadingGuard({
      onShow: () => {
        this.statusTarget.textContent = "Searching..."
        this.statusTarget.classList.add("text-indigo-600")
        this.statusTarget.classList.remove("text-gray-500")
        this.submitButtonTarget.innerHTML = `<svg class="animate-spin inline-block h-4 w-4 mr-1 -mt-0.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>Searching...`
      },
      onHide: () => {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.innerHTML = "Search"
      }
    })

    this.loadMoreGuard = new LoadingGuard({
      onShow: () => {
        this.loadMoreBtnTarget.textContent = "Loading..."
      },
      onHide: () => {
        this.loadMoreBtnTarget.disabled = false
        this.loadMoreBtnTarget.textContent = "Load More"
      }
    })
  }

  async search(event) {
    event.preventDefault()
    this.currentOffset = 0
    this.resultsListTarget.innerHTML = ""
    this.submitButtonTarget.disabled = true
    this.searchGuard.show()
    await this.fetchNodes(false)
  }

  async loadMore() {
    this.currentOffset += this.pageSize
    this.loadMoreBtnTarget.disabled = true
    this.loadMoreGuard.show()
    await this.fetchNodes(true)
  }

  async fetchNodes(append) {
    const type = this.typeSelectTarget.value
    const q = this.queryInputTarget.value.trim()
    const params = new URLSearchParams()

    if (type) params.set("type", type)
    if (q) params.set("q", q)
    params.set("limit", String(this.pageSize))
    params.set("offset", String(this.currentOffset))
    params.set("include_orphans", "true")

    try {
      const response = await fetch(`/graph/nodes?${params}`)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this.currentTotal = data.total
      this.renderResults(data.nodes, data.total, append)
      this.updateLoadMoreButton()
    } catch (error) {
      this.statusTarget.textContent = `Error: ${error.message}`
      this.statusTarget.classList.remove("text-indigo-600")
      this.statusTarget.classList.add("text-red-600")
    } finally {
      this.searchGuard.hide()
      this.loadMoreGuard.hide()
    }
  }

  renderResults(nodes, total, append) {
    this.statusTarget.textContent = `${total} node${total === 1 ? "" : "s"} found`
    this.statusTarget.classList.remove("text-indigo-600", "text-red-600")
    this.statusTarget.classList.add("text-gray-500")

    if (!append) {
      this.resultsListTarget.innerHTML = ""
    }

    nodes.forEach(node => {
      const li = document.createElement("li")
      li.className = "px-3 py-2 cursor-pointer hover:bg-gray-100 rounded text-sm truncate"
      li.dataset.action = "click->search#selectNode"
      li.dataset.nodeId = node.id
      li.dataset.nodeType = node.type
      li.dataset.nodeData = JSON.stringify(node.data)

      const badge = typeBadge(node.type)
      const name = node.data.display_name || node.id.split("://")[1]
      li.innerHTML = `${badge} <span>${escapeHtml(name)}</span>`

      this.resultsListTarget.appendChild(li)
    })
  }

  updateLoadMoreButton() {
    if (this.currentOffset + this.pageSize < this.currentTotal) {
      this.loadMoreButtonTarget.classList.remove("hidden")
    } else {
      this.loadMoreButtonTarget.classList.add("hidden")
    }
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
}
