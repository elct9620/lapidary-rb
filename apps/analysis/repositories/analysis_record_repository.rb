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

      def delete_by_entities(entity_pairs)
        with_error_wrapping do
          return 0 if entity_pairs.empty?

          pairs = entity_pairs.map { |ep| [ep[:entity_type], ep[:entity_id]] }
          dataset.where(%i[entity_type entity_id] => pairs).delete
        end
      end
    end
  end
end
