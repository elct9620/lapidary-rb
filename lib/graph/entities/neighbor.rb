# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing a neighbor node and its connecting edges.
    Neighbor = Data.define(:node, :edges) do
      def initialize(node:, edges: [])
        super
      end
    end
  end
end
