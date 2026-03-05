import { Controller } from "@hotwired/stimulus"
import { typeBadge, escapeHtml } from "./helpers.js"

const REDMINE_BASE_URL = "https://bugs.ruby-lang.org"

function redmineSourceUrl(sourceType, sourceId, parentEntityId) {
  if (sourceType === "issue" && sourceId) {
    return `${REDMINE_BASE_URL}/issues/${sourceId}`
  }
  if (sourceType === "journal" && parentEntityId) {
    return `${REDMINE_BASE_URL}/issues/${parentEntityId}`
  }
  return null
}

function redmineSearchUrl(name) {
  return `${REDMINE_BASE_URL}/search?q=${encodeURIComponent(name)}`
}

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
      .map(([k, v]) => `<li class="flex justify-between min-w-0"><span class="text-gray-500 shrink-0">${escapeHtml(k)}</span><span class="font-medium break-all">${escapeHtml(String(v))}</span></li>`)
      .join("")

    const nodeName = id.includes("://") ? id.split("://")[1] : id
    const searchUrl = redmineSearchUrl(nodeName)
    const searchLink = `<a href="${escapeHtml(searchUrl)}" target="_blank" rel="noopener noreferrer" class="text-indigo-600 hover:underline text-xs break-all">Search on bugs.ruby-lang.org ↗</a>`

    this.contentTarget.innerHTML = `
      <h3 class="font-semibold text-lg mb-2">${escapeHtml(label)}</h3>
      <dl class="space-y-1 text-sm mb-3">
        <div class="flex justify-between">
          <dt class="text-gray-500">Type</dt>
          <dd>${typeBadge(type)}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-gray-500">ID</dt>
          <dd class="font-mono text-xs break-all">${escapeHtml(id)}</dd>
        </div>
      </dl>
      <div class="mb-3">${searchLink}</div>
      ${dataEntries ? `<h4 class="font-medium text-sm text-gray-600 mb-1">Data</h4><ul class="space-y-1 text-sm">${dataEntries}</ul>` : ""}
    `
  }

  showEdge(event) {
    const { source, target, relationship, observations, archivedAt } = event.detail

    const obsHtml = (observations || []).map(obs => {
      const sourceUrl = redmineSourceUrl(obs.source_entity_type, obs.source_entity_id, obs.parent_entity_id)
      const sourceLabel = `${escapeHtml(obs.source_entity_type || "")} #${obs.source_entity_id || ""}`
      const sourceContent = sourceUrl
        ? `<a href="${escapeHtml(sourceUrl)}" target="_blank" rel="noopener noreferrer" class="text-indigo-600 hover:underline break-all">${sourceLabel} ↗</a>`
        : sourceLabel

      return `
        <li class="border-l-2 border-gray-200 pl-3 py-1">
          <div class="text-xs text-gray-400">${escapeHtml(obs.observed_at || "")}</div>
          <div class="text-sm">${escapeHtml(obs.evidence || "(no evidence)")}</div>
          <div class="text-xs text-gray-500 mt-0.5">Source: ${sourceContent}</div>
        </li>
      `
    }).join("")

    const archivedBadge = archivedAt
      ? `<div class="flex justify-between">
          <dt class="text-gray-500">Status</dt>
          <dd><span class="inline-block px-1.5 py-0.5 text-xs font-medium rounded bg-gray-100 text-gray-600">Archived</span></dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-gray-500">Archived At</dt>
          <dd class="text-xs">${escapeHtml(archivedAt)}</dd>
        </div>`
      : ""

    this.contentTarget.innerHTML = `
      <h3 class="font-semibold text-lg mb-2">${escapeHtml(relationship)}</h3>
      <dl class="space-y-1 text-sm mb-3">
        <div class="flex justify-between">
          <dt class="text-gray-500">From</dt>
          <dd class="font-mono text-xs break-all">${escapeHtml(source)}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-gray-500">To</dt>
          <dd class="font-mono text-xs break-all">${escapeHtml(target)}</dd>
        </div>
        ${archivedBadge}
      </dl>
      <h4 class="font-medium text-sm text-gray-600 mb-2">Observations (${observations ? observations.length : 0})</h4>
      <ul class="space-y-2">${obsHtml || '<li class="text-sm text-gray-400">No observations</li>'}</ul>
    `
  }

  clear() {
    this.showPlaceholder()
  }
}
