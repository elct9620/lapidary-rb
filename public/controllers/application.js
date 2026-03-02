import { Application } from "@hotwired/stimulus"
import SearchController from "./search_controller.js"
import GraphController from "./graph_controller.js"
import FilterController from "./filter_controller.js"
import DetailController from "./detail_controller.js"

const app = Application.start()
app.register("search", SearchController)
app.register("graph", GraphController)
app.register("filter", FilterController)
app.register("detail", DetailController)
