# auto_register: false
# frozen_string_literal: true

module Maintenance
  module UseCases
    # Renames a node ID across nodes, edges, and observations tables.
    # Delegates FK-safe graph transformation to the repository.
    class RenameNode
      def initialize(repository:)
        @repository = repository
      end

      def call(old_id, new_id)
        raise Entities::NodeNotFoundError, "node not found: #{old_id}" unless @repository.node_exists?(old_id)

        @repository.rename(old_id, new_id)
      end
    end
  end
end
