# frozen_string_literal: true

module Webhooks
  # Repository for managing analysis tracking records.
  class AnalysisRecordRepository
    include Lapidary::Dependency['database']

    def save(record)
      dataset.insert_conflict(target: %i[entity_type entity_id]).insert(
        entity_type: record.entity_type,
        entity_id: record.entity_id,
        analyzed_at: record.analyzed_at
      )
    rescue Sequel::Error => e
      raise AnalysisTrackingError, e.message
    end

    def exists?(record)
      dataset.where(entity_type: record.entity_type, entity_id: record.entity_id).any?
    rescue Sequel::Error => e
      raise AnalysisTrackingError, e.message
    end

    def untracked_journal_ids(journal_ids)
      return [] if journal_ids.empty?

      tracked = dataset
                .where(entity_type: 'journal', entity_id: journal_ids)
                .select_map(:entity_id)

      journal_ids - tracked
    rescue Sequel::Error => e
      raise AnalysisTrackingError, e.message
    end

    private

    def dataset
      database[:analysis_records]
    end
  end
end
