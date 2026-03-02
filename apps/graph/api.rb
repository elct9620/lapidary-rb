# auto_register: false
# frozen_string_literal: true

module Graph
  # Graph query endpoint for exploring the knowledge graph
  class API < Lapidary::BaseController
    error Entities::GraphQueryError do
      logger.warn(self, "Graph query error: #{env['sinatra.error'].message}")
      halt_json 500, error: 'internal server error'
    end

    get '/graph/nodes' do
      result = validate_with_contract!('graph.node_query_contract', params, status: 400)

      output = build_query_nodes(result)

      respond_json(container['graph.serializers.node_list_serializer'].call(output))
    end

    get '/graph/neighbors' do
      result = validate_with_contract!('graph.contract', params, status: 400)

      output = build_query_neighbors(result)
      halt_json 404, error: 'node not found' unless output

      respond_json(container['graph.serializers.neighbor_serializer'].call(output))
    end

    private

    def build_query_nodes(result)
      use_case = UseCases::QueryNodes.new(
        node_repository: container['graph.repositories.node_repository']
      )
      use_case.call(
        type: result[:type],
        query: result[:q],
        limit: result[:limit] || 20,
        offset: result[:offset] || 0,
        include_orphans: result[:include_orphans] || false
      )
    end

    def build_query_neighbors(result)
      use_case = UseCases::QueryNeighbors.new(
        neighbor_repository: container['graph.repositories.neighbor_repository']
      )
      use_case.call(
        node_id: result[:node_id],
        direction: Entities::Direction.parse(result[:direction]),
        observed_after: result[:observed_after],
        observed_before: result[:observed_before],
        include_archived: result[:include_archived] || false
      )
    end
  end
end
