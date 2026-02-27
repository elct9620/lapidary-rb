# frozen_string_literal: true

module Graph
  module Serializers
    # Serializes QueryNodes output into a JSON-compatible hash.
    class NodeListSerializer
      def call(output)
        {
          nodes: output[:nodes].map { |node| serialize_node(node) },
          total: output[:total],
          limit: output[:limit],
          offset: output[:offset]
        }
      end

      private

      def serialize_node(node)
        { id: node.id, type: node.type, data: node.data }
      end
    end
  end
end
