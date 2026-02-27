# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing an observation record for a knowledge graph edge.
    Observation = Data.define(:observed_at, :source_entity_type, :source_entity_id, :evidence) do
      def initialize(observed_at:, source_entity_type:, source_entity_id:, evidence: nil)
        super
      end
    end
  end
end
