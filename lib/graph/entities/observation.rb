# auto_register: false
# frozen_string_literal: true

module Graph
  module Entities
    # Immutable value object representing an observation on a knowledge graph edge.
    Observation = Data.define(:observed_at, :source_entity_type, :source_entity_id, :evidence) do
      def initialize(observed_at:, source_entity_type:, source_entity_id:, evidence: nil)
        super(
          observed_at: observed_at.is_a?(Time) ? observed_at : (observed_at && Time.iso8601(observed_at)),
          source_entity_type: source_entity_type,
          source_entity_id: source_entity_id,
          evidence: evidence
        )
      end
    end
  end
end
