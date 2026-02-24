# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing a knowledge graph node.
    Node = Data.define(:type, :name, :properties) do
      def initialize(type:, name:, properties: {})
        super
      end
    end
  end
end
