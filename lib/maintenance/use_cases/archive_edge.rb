# auto_register: false
# frozen_string_literal: true

module Maintenance
  module UseCases
    # Archives a single edge by key and clears associated analysis records.
    class ArchiveEdge
      def initialize(edge_archive_writer:, analysis_record_repository:)
        @edge_archive_writer = edge_archive_writer
        @analysis_record_repository = analysis_record_repository
      end

      def call(source:, target:, relationship:)
        result = @edge_archive_writer.archive_by_key(source: source, target: target, relationship: relationship)
        deleted = @analysis_record_repository.delete_by_entities(result.entity_pairs)
        { archived: 1, analysis_records_cleared: deleted }
      end
    end
  end
end
