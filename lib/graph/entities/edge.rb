# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing a knowledge graph edge with observations.
    Edge = Data.define(:source, :target, :relationship, :observations) do
      def initialize(source:, target:, relationship:, observations: [])
        super
      end
    end
  end
end
