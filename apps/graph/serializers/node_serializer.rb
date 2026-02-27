# frozen_string_literal: true

module Graph
  module Serializers
    # Shared serialization logic for converting Node entities to JSON-compatible hashes.
    module NodeSerializer
      private

      def serialize_node(node)
        { id: node.id, type: node.type, data: node.data }
      end
    end
  end
end
