# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing a knowledge graph edge with observations.
    Edge = Data.define(:source, :target, :relationship, :observations, :archived_at) do
      def initialize(source:, target:, relationship:, observations: [], archived_at: nil)
        super
      end
    end
  end
end
