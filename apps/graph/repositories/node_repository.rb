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

      def search(type: nil, query: nil, limit: 20, offset: 0)
        with_error_wrapping do
          apply_filters(dataset, type, query)
            .limit(limit, offset)
            .map { |row| build_node(row) }
        end
      end

      def count(type: nil, query: nil)
        with_error_wrapping do
          apply_filters(dataset, type, query).count
        end
      end

      private

      def apply_filters(dataset, type, query)
        dataset = dataset.where(type: type) if type
        dataset = apply_search(dataset, query) if query
        dataset
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
