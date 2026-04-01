# frozen_string_literal: true

module Maintenance
  module Repositories
    # Repository for node deletion operations.
    # Handles existence checks, active edge detection, and cascading deletes.
    class NodeDeletionRepository
      include Lapidary::Dependency['database']

      def node_exists?(node_id)
        nodes.where(id: node_id).any?
      end

      def active_edges?(node_id)
        edges_for(node_id).where(archived_at: nil).any?
      end

      def delete_with_archived_edges(node_id)
        database.transaction do
          purge_archived_edges(node_id)
          nodes.where(id: node_id).delete
        end
      end

      private

      def nodes
        database[:nodes]
      end

      def edges_for(node_id)
        database[:edges].where(Sequel.or(source: node_id, target: node_id))
      end

      def purge_archived_edges(node_id)
        edges_for(node_id).each do |edge|
          database[:observations].where(edge_source: edge[:source], edge_target: edge[:target],
                                        edge_relationship: edge[:relationship]).delete
        end
        edges_for(node_id).delete
      end
    end
  end
end
