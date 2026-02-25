# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing the direction of a graph traversal.
    Direction = Data.define(:value) do
      def to_s
        value
      end
    end

    class Direction
      OUTBOUND = new(value: 'outbound')
      INBOUND = new(value: 'inbound')
      BOTH = new(value: 'both')
    end
  end
end
