# frozen_string_literal: true

module Graph
  module Serializers
    # Serializes QueryNeighbors output into a JSON-compatible hash.
    class NeighborSerializer
      include NodeSerializer

      def call(output)
        @include_archived = output[:include_archived]
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
        result = {
          source: edge.source,
          target: edge.target,
          relationship: edge.relationship,
          observations: edge.observations.map { |obs| serialize_observation(obs) }
        }
        result[:archived_at] = edge.archived_at&.iso8601 if @include_archived
        result
      end

      def serialize_observation(observation)
        {
          observed_at: observation.observed_at&.iso8601,
          source_entity_type: observation.source_entity_type,
          source_entity_id: observation.source_entity_id,
          evidence: observation.evidence
        }
      end
    end
  end
end
