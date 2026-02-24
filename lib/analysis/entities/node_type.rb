# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the type of a knowledge graph node.
    NodeType = Data.define(:value) do
      def to_s
        value
      end
    end

    class NodeType
      RUBYIST = new(value: 'Rubyist')
      CORE_MODULE = new(value: 'CoreModule')
      STDLIB = new(value: 'Stdlib')
    end
  end
end
