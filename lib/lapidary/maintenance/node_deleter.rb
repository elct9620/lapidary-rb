# frozen_string_literal: true

module Lapidary
  module Maintenance
    # Deletes an orphan node (one with no edges) from the graph.
    # Refuses to delete nodes that still have active or archived edges.
    class NodeDeleter
      include Dependency['database']

      class NodeNotFoundError < StandardError; end
      class NodeHasEdgesError < StandardError; end

      def call(node_id)
        raise NodeNotFoundError, "node not found: #{node_id}" unless database[:nodes].where(id: node_id).any?

        if database[:edges].where(Sequel.or(source: node_id, target: node_id)).any?
          raise NodeHasEdgesError, "node still has edges: #{node_id}"
        end

        database[:nodes].where(id: node_id).delete
      end
    end
  end
end
