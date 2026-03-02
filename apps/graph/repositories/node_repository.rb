# frozen_string_literal: true

module Graph
  module Repositories
    # Read-only repository for querying knowledge graph nodes with filtering and pagination.
    class NodeRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport
      include NodeBuilder

      table :nodes
      wraps_errors Entities::GraphQueryError

      def search(type: nil, query: nil, limit: 20, offset: 0, include_orphans: false)
        with_error_wrapping do
          apply_filters(dataset, type, query, include_orphans)
            .limit(limit, offset)
            .map { |row| build_node(row) }
        end
      end

      def count(type: nil, query: nil, include_orphans: false)
        with_error_wrapping do
          apply_filters(dataset, type, query, include_orphans).count
        end
      end

      private

      def apply_filters(scope, type, query, include_orphans)
        scope = scope.where(type: type) if type
        scope = apply_search(scope, query) if query
        scope = exclude_orphans(scope) unless include_orphans
        scope
      end

      def exclude_orphans(scope)
        active_edge_exists = database[:edges].where(archived_at: nil)
                                             .where(
                                               Sequel.|(
                                                 { source: Sequel[:nodes][:id] },
                                                 { target: Sequel[:nodes][:id] }
                                               )
                                             ).exists
        scope.where(active_edge_exists)
      end

      def apply_search(dataset, query)
        pattern = "%#{query.downcase}%"
        name_expr = Sequel.lit("lower(substr(id, instr(id, '://') + 3)) LIKE ?", pattern)
        display_name_expr = Sequel.lit("lower(json_extract(data, '$.display_name')) LIKE ?", pattern)
        dataset.where(Sequel.|(name_expr, display_name_expr))
      end
    end
  end
end
