# frozen_string_literal: true

module Graph
  module Serializers
    # Serializes QueryNeighbors output into a JSON-compatible hash.
    class NeighborSerializer
      include NodeSerializer

      def call(output)
        {
          node: serialize_node(output[:node]),
          neighbors: output[:neighbors].map { |neighbor| serialize_neighbor(neighbor) }
        }
      end

      private

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
end
