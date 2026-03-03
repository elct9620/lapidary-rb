const TYPE_BADGE_COLORS = {
  Rubyist: "bg-blue-100 text-blue-800",
  CoreModule: "bg-green-100 text-green-800",
  Stdlib: "bg-amber-100 text-amber-800"
}

export function typeBadge(type) {
  const cls = TYPE_BADGE_COLORS[type] || "bg-gray-100 text-gray-800"
  return `<span class="inline-block px-1.5 py-0.5 text-xs font-medium rounded ${cls}">${type}</span>`
}

export function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
