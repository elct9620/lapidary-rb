# auto_register: false
# frozen_string_literal: true

module Graph
  # Graph query endpoint for exploring the knowledge graph
  class API < Lapidary::BaseController
    get '/graph/nodes' do
      result = validate_params!('graph.node_query_contract')

      use_case = UseCases::QueryNodes.new(
        node_repository: container['graph.repositories.node_repository']
      )
      output = use_case.call(
        type: result[:type],
        query: result[:q],
        limit: result[:limit] || 20,
        offset: result[:offset] || 0
      )

      content_type :json
      JSON.generate(container['graph.serializers.node_list_serializer'].call(output))
    rescue Entities::GraphQueryError => e
      logger.warn(self, "Graph query error: #{e.message}")
      halt_json 500, error: 'internal server error'
    end

    get '/graph/neighbors' do
      result = validate_params!

      use_case = UseCases::QueryNeighbors.new(
        neighbor_repository: container['graph.repositories.neighbor_repository']
      )
      output = use_case.call(
        node_id: result[:node_id],
        direction: result[:direction] ? Entities::Direction.new(value: result[:direction]) : Entities::Direction::BOTH,
        observed_after: result[:observed_after],
        observed_before: result[:observed_before]
      )

      halt_json 404, error: 'node not found' unless output

      content_type :json
      JSON.generate(container['graph.serializers.neighbor_serializer'].call(output))
    rescue Entities::GraphQueryError => e
      logger.warn(self, "Graph query error: #{e.message}")
      halt_json 500, error: 'internal server error'
    end

    private

    def validate_params!(contract_key = 'graph.contract')
      result = container[contract_key].call(params)

      if result.failure?
        field, messages = result.errors.to_h.first
        halt_json 400, error: "#{field} #{messages.first}"
      end

      result
    end
  end
end
