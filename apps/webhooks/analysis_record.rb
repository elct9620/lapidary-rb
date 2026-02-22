# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Domain entity representing a tracked analysis record.
  AnalysisRecord = Data.define(:entity_type, :entity_id, :analyzed_at)
end
