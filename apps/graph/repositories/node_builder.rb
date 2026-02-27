# frozen_string_literal: true

module Graph
  module Repositories
    # Shared logic for building Node entities from database rows.
    module NodeBuilder
      private

      def build_node(row)
        data = parse_json(row[:data])
        Entities::Node.new(id: row[:id], type: row[:type], data: data)
      end
    end
  end
end
