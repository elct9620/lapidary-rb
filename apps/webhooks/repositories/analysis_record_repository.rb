# frozen_string_literal: true

module Webhooks
  module Repositories
    # Repository for managing analysis tracking records.
    class AnalysisRecordRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      table :analysis_records
      wraps_errors Entities::AnalysisTrackingError

      def exists?(record)
        with_error_wrapping do
          dataset.where(entity_type: record.entity_type.to_s, entity_id: record.entity_id).any?
        end
      end

      def untracked(records)
        return [] if records.empty?

        with_error_wrapping do
          records.group_by { |r| r.entity_type.to_s }.flat_map do |entity_type, group|
            reject_tracked(entity_type, group)
          end
        end
      end

      private

      def reject_tracked(entity_type, group)
        tracked_ids = dataset
                      .where(entity_type: entity_type, entity_id: group.map(&:entity_id))
                      .select_map(:entity_id)
                      .to_set

        group.reject { |r| tracked_ids.include?(r.entity_id) }
      end
    end
  end
end
