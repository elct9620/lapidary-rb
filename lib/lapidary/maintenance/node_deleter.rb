# frozen_string_literal: true

module Lapidary
  module Maintenance
    # Deletes a node from the graph. Automatically purges any archived edges
    # and their observations. Refuses to delete nodes with active edges.
    class NodeDeleter
      include Dependency['database']

      class NodeNotFoundError < StandardError; end
      class NodeHasActiveEdgesError < StandardError; end

      def call(node_id)
        raise NodeNotFoundError, "node not found: #{node_id}" unless node_exists?(node_id)

        edges = edges_for(node_id)
        raise NodeHasActiveEdgesError, "node still has active edges: #{node_id}" if edges.where(archived_at: nil).any?

        database.transaction do
          purge_archived_edges(edges)
          database[:nodes].where(id: node_id).delete
        end
      end

      private

      def node_exists?(node_id)
        database[:nodes].where(id: node_id).any?
      end

      def edges_for(node_id)
        database[:edges].where(Sequel.or(source: node_id, target: node_id))
      end

      def purge_archived_edges(edges_dataset)
        edges_dataset.each do |edge|
          database[:observations].where(edge_source: edge[:source], edge_target: edge[:target],
                                        edge_relationship: edge[:relationship]).delete
        end
        edges_dataset.delete
      end
    end
  end
end
