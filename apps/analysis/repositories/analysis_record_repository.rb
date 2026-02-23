# frozen_string_literal: true

module Analysis
  module Repositories
    # Repository for managing analysis tracking records.
    class AnalysisRecordRepository
      include Lapidary::Dependency['database']

      def save(record)
        with_error_wrapping do
          dataset.insert_conflict(target: %i[entity_type entity_id]).insert(
            entity_type: record.entity_type,
            entity_id: record.entity_id,
            analyzed_at: record.analyzed_at
          )
        end
      end

      private

      def with_error_wrapping
        yield
      rescue Sequel::Error => e
        raise Entities::AnalysisTrackingError, e.message
      end

      def dataset
        database[:analysis_records]
      end
    end
  end
end
