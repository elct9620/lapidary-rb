# auto_register: false
# frozen_string_literal: true

module Analysis
  module UseCases
    # Archives expired graph edges and resets corresponding analysis records.
    class ArchiveEdges
      def initialize(edge_archive_repository:, analysis_record_repository:, retention_period:, logger:)
        @edge_archive_repository = edge_archive_repository
        @analysis_record_repository = analysis_record_repository
        @retention_period = retention_period
        @logger = logger
      end

      def call(now: Time.now)
        cutoff = @retention_period.cutoff(now: now)
        result = @edge_archive_repository.archive_expired(cutoff: cutoff)

        reset_analysis_records(result.entity_pairs)

        @logger.info(self,
                     "Graph archiving: archived #{result.archived_count} edges " \
                     "(retention: #{@retention_period})",
                     archived: result.archived_count, retention: @retention_period.to_s)

        result.archived_count
      end

      private

      def reset_analysis_records(entity_pairs)
        return if entity_pairs.empty?

        @analysis_record_repository.delete_by_entities(entity_pairs)
      end
    end
  end
end
