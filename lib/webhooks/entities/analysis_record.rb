# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing a tracked analysis record.
    class AnalysisRecord
      attr_reader :entity_type, :entity_id, :analyzed_at

      def initialize(entity_type:, entity_id:, analyzed_at: nil)
        @entity_type = entity_type
        @entity_id = entity_id
        @analyzed_at = analyzed_at
      end
    end
  end
end
