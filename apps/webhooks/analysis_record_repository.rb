# frozen_string_literal: true

module Webhooks
  # Repository for managing analysis tracking records.
  # Uses INSERT OR IGNORE semantics to avoid duplicate entries.
  class AnalysisRecordRepository
    include Lapidary::Dependency['database']

    def create_if_absent(entity_type:, entity_id:)
      dataset.insert_conflict(target: %i[entity_type entity_id]).insert(
        entity_type: entity_type,
        entity_id: entity_id,
        analyzed_at: Time.now
      )
    end

    def tracked?(entity_type:, entity_id:)
      dataset.where(entity_type: entity_type, entity_id: entity_id).any?
    end

    def untracked_journal_ids(journal_ids)
      return [] if journal_ids.empty?

      tracked = dataset
                .where(entity_type: 'journal', entity_id: journal_ids)
                .select_map(:entity_id)

      journal_ids - tracked
    end

    private

    def dataset
      database[:analysis_records]
    end
  end
end
