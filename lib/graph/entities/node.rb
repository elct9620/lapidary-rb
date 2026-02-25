# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing a knowledge graph node for query results.
    Node = Data.define(:id, :type, :data) do
      def initialize(id:, type:, data: {})
        super
      end
    end
  end
end
