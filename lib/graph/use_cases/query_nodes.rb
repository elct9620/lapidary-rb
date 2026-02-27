# auto_register: false
# frozen_string_literal: true

module Graph
  module UseCases
    # Lists and searches knowledge graph nodes with type filtering,
    # keyword search, and pagination.
    class QueryNodes
      def initialize(node_repository:)
        @node_repository = node_repository
      end

      def call(type: nil, query: nil, limit: 20, offset: 0)
        nodes = @node_repository.search(type: type, query: query, limit: limit, offset: offset)
        total = @node_repository.count(type: type, query: query)

        { nodes: nodes, total: total, limit: limit, offset: offset }
      end
    end
  end
end
