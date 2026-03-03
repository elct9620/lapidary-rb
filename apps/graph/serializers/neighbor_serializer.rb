# frozen_string_literal: true

module Graph
  module Serializers
    # Serializes QueryNeighbors output into a JSON-compatible hash.
    class NeighborSerializer
      include NodeSerializer

      def call(output)
        include_archived = output[:include_archived]
        {
          node: serialize_node(output[:node]),
          neighbors: output[:neighbors].map { |neighbor| serialize_neighbor(neighbor, include_archived) }
        }
      end

      private

      def serialize_neighbor(neighbor, include_archived)
        {
          node: serialize_node(neighbor.node),
          edges: neighbor.edges.map { |edge| serialize_edge(edge, include_archived) }
        }
      end

      def serialize_edge(edge, include_archived)
        result = {
          source: edge.source,
          target: edge.target,
          relationship: edge.relationship,
          observations: edge.observations.map { |obs| serialize_observation(obs) }
        }
        result[:archived_at] = edge.archived_at&.iso8601 if include_archived
        result
      end

      def serialize_observation(observation)
        result = {
          observed_at: observation.observed_at&.iso8601,
          source_entity_type: observation.source_entity_type,
          source_entity_id: observation.source_entity_id,
          evidence: observation.evidence
        }
        result[:parent_entity_id] = observation.parent_entity_id if observation.parent_entity_id
        result
      end
    end
  end
end
