# frozen_string_literal: true

module Analysis
  module Repositories
    # Repository for managing analysis tracking records.
    class AnalysisRecordRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      table :analysis_records
      wraps_errors Entities::AnalysisTrackingError

      def save(record)
        raise Entities::AnalysisTrackingError, 'cannot save unanalyzed record' unless record.analyzed_at

        with_error_wrapping do
          dataset.insert_conflict(target: %i[entity_type entity_id]).insert(
            entity_type: record.entity_type.to_s,
            entity_id: record.entity_id,
            analyzed_at: record.analyzed_at
          )
        end
      end
    end
  end
end
