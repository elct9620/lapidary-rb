# frozen_string_literal: true

require 'json'

module Graph
  module Repositories
    # Shared logic for building Node entities from database rows.
    module NodeBuilder
      private

      def build_node(row)
        data = row[:data] ? JSON.parse(row[:data], symbolize_names: true) : {}
        Entities::Node.new(id: row[:id], type: row[:type], data: data)
      end
    end
  end
end
