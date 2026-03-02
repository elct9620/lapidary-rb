import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

const NODE_COLORS = {
  Rubyist: "#3B82F6",
  CoreModule: "#10B981",
  Stdlib: "#F59E0B"
}

export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    this.cy = null
    this.filters = { direction: "both", observedAfter: "", observedBefore: "" }
    this.loadedNodes = new Set()
  }

  initCytoscape() {
    if (this.cy) return

    this.cy = cytoscape({
      container: this.canvasTarget,
      style: [
        {
          selector: "node",
          style: {
            label: "data(label)",
            "background-color": "data(color)",
            color: "#1F2937",
            "font-size": "12px",
            "text-valign": "bottom",
            "text-margin-y": 6,
            width: 36,
            height: 36,
            "text-max-width": "100px",
            "text-wrap": "ellipsis"
          }
        },
        {
          selector: "node:selected",
          style: {
            "border-width": 3,
            "border-color": "#6366F1"
          }
        },
        {
          selector: "edge",
          style: {
            label: "data(label)",
            "curve-style": "bezier",
            "target-arrow-shape": "triangle",
            "arrow-scale": 1.2,
            "line-color": "#9CA3AF",
            "target-arrow-color": "#9CA3AF",
            "font-size": "10px",
            color: "#6B7280",
            "text-rotation": "autorotate",
            width: 2
          }
        },
        {
          selector: "edge:selected",
          style: {
            "line-color": "#6366F1",
            "target-arrow-color": "#6366F1",
            width: 3
          }
        }
      ],
      layout: { name: "grid" },
      minZoom: 0.2,
      maxZoom: 3
    })

    this.cy.on("tap", "node", (evt) => this.onNodeTap(evt))
    this.cy.on("tap", "edge", (evt) => this.onEdgeTap(evt))
    this.cy.on("tap", (evt) => {
      if (evt.target === this.cy) this.onBackgroundTap()
    })
  }

  async loadNode(event) {
    const { nodeId } = event.detail
    this.initCytoscape()
    this.loadedNodes.clear()
    this.cy.elements().remove()
    await this.fetchAndRenderNeighbors(nodeId)
  }

  async fetchAndRenderNeighbors(nodeId) {
    if (this.loadedNodes.has(nodeId)) return
    this.loadedNodes.add(nodeId)

    const params = new URLSearchParams({ node_id: nodeId })
    if (this.filters.direction) params.set("direction", this.filters.direction)
    if (this.filters.observedAfter) params.set("observed_after", this.filters.observedAfter)
    if (this.filters.observedBefore) params.set("observed_before", this.filters.observedBefore)

    try {
      const response = await fetch(`/graph/neighbors?${params}`)
      if (!response.ok) return

      const data = await response.json()
      this.addNodeToGraph(data.node)

      data.neighbors.forEach(neighbor => {
        this.addNodeToGraph(neighbor.node)
        neighbor.edges.forEach(edge => this.addEdgeToGraph(edge))
      })

      this.runLayout()
    } catch (error) {
      console.error("Failed to fetch neighbors:", error)
    }
  }

  addNodeToGraph(node) {
    if (this.cy.getElementById(node.id).length > 0) return

    this.cy.add({
      group: "nodes",
      data: {
        id: node.id,
        label: node.data.display_name || node.id.split("://")[1],
        color: NODE_COLORS[node.type] || "#6B7280",
        nodeType: node.type,
        nodeData: node.data
      }
    })
  }

  addEdgeToGraph(edge) {
    const edgeId = `${edge.source}-${edge.relationship}-${edge.target}`
    if (this.cy.getElementById(edgeId).length > 0) return

    this.cy.add({
      group: "edges",
      data: {
        id: edgeId,
        source: edge.source,
        target: edge.target,
        label: edge.relationship,
        relationship: edge.relationship,
        observations: edge.observations
      }
    })
  }

  runLayout() {
    this.cy.layout({
      name: "cose",
      animate: true,
      animationDuration: 500,
      nodeRepulsion: () => 8000,
      idealEdgeLength: () => 120,
      padding: 40
    }).run()
  }

  async onNodeTap(evt) {
    const node = evt.target
    this.dispatch("node-detail", {
      detail: {
        id: node.id(),
        type: node.data("nodeType"),
        data: node.data("nodeData"),
        label: node.data("label")
      }
    })
    await this.fetchAndRenderNeighbors(node.id())
  }

  onEdgeTap(evt) {
    const edge = evt.target
    this.dispatch("edge-detail", {
      detail: {
        source: edge.data("source"),
        target: edge.data("target"),
        relationship: edge.data("relationship"),
        observations: edge.data("observations")
      }
    })
  }

  onBackgroundTap() {
    this.dispatch("clear-detail")
  }

  async applyFilters(event) {
    const { direction, observedAfter, observedBefore } = event.detail
    this.filters = { direction, observedAfter, observedBefore }

    if (this.loadedNodes.size === 0) return

    const centerNodeId = [...this.loadedNodes][0]
    this.loadedNodes.clear()
    this.cy.elements().remove()
    await this.fetchAndRenderNeighbors(centerNodeId)
  }
}
