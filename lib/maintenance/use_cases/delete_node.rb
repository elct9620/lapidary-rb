# auto_register: false
# frozen_string_literal: true

module Maintenance
  module UseCases
    # Deletes a node from the graph. Automatically purges any archived edges
    # and their observations. Refuses to delete nodes with active edges.
    class DeleteNode
      def initialize(repository:)
        @repository = repository
      end

      def call(node_id)
        raise Entities::NodeNotFoundError, "node not found: #{node_id}" unless @repository.node_exists?(node_id)

        if @repository.active_edges?(node_id)
          raise Entities::ActiveEdgesError,
                "node still has active edges: #{node_id}"
        end

        @repository.delete_with_archived_edges(node_id)
      end
    end
  end
end
