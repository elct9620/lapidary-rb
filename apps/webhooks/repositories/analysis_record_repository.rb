# frozen_string_literal: true

module Webhooks
  module Repositories
    # Repository for managing analysis tracking records.
    class AnalysisRecordRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      table :analysis_records
      wraps_errors Entities::AnalysisTrackingError

      def save(record)
        with_error_wrapping do
          dataset.insert_conflict(target: %i[entity_type entity_id]).insert(
            entity_type: record.entity_type,
            entity_id: record.entity_id,
            analyzed_at: record.analyzed_at
          )
        end
      end

      def exists?(record)
        with_error_wrapping do
          dataset.where(entity_type: record.entity_type, entity_id: record.entity_id).any?
        end
      end

      def untracked(records)
        return [] if records.empty?
        raise ArgumentError, 'records must have the same entity_type' unless homogeneous_entity_type?(records)

        with_error_wrapping do
          entity_type = records.first.entity_type
          entity_ids = records.map(&:entity_id)
          tracked_ids = dataset
                        .where(entity_type: entity_type, entity_id: entity_ids)
                        .select_map(:entity_id)

          records.reject { |r| tracked_ids.include?(r.entity_id) }
        end
      end

      private

      def homogeneous_entity_type?(records)
        records.map(&:entity_type).uniq.size == 1
      end
    end
  end
end
