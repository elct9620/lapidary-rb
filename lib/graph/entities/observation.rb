# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing an observation on a knowledge graph edge.
    Observation = Data.define(:observed_at, :source_entity_type, :source_entity_id, :evidence, :parent_entity_id) do
      def initialize(observed_at:, source_entity_type:, source_entity_id:, evidence: nil, parent_entity_id: nil)
        super
      end
    end
  end
end
