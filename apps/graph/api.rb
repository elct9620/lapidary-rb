# auto_register: false
# frozen_string_literal: true

module Graph
  # Graph query endpoint for exploring the knowledge graph
  class API < Lapidary::BaseController
    get '/graph/neighbors' do
      result = validate_params!

      use_case = UseCases::QueryNeighbors.new(
        neighbor_repository: container['graph.repositories.neighbor_repository']
      )
      output = use_case.call(
        node_id: result[:node_id],
        direction: result[:direction] || 'both',
        observed_after: result[:observed_after],
        observed_before: result[:observed_before]
      )

      halt_json 404, error: 'node not found' unless output

      content_type :json
      JSON.generate(serialize(output))
    rescue Entities::GraphQueryError => e
      logger.warn(self, e.message)
      halt_json 500, error: 'internal server error'
    end

    private

    def validate_params!
      result = container['graph.contract'].call(params)

      if result.failure?
        field, messages = result.errors.to_h.first
        halt_json 400, error: "#{field} #{messages.first}"
      end

      result
    end

    def serialize(output)
      {
        node: serialize_node(output[:node]),
        neighbors: output[:neighbors].map { |neighbor| serialize_neighbor(neighbor) }
      }
    end

    def serialize_node(node)
      { id: node.id, type: node.type, data: node.data }
    end

    def serialize_neighbor(neighbor)
      {
        node: serialize_node(neighbor.node),
        edges: neighbor.edges.map { |edge| serialize_edge(edge) }
      }
    end

    def serialize_edge(edge)
      {
        source: edge.source,
        target: edge.target,
        relationship: edge.relationship,
        observations: edge.observations
      }
    end
  end
end
