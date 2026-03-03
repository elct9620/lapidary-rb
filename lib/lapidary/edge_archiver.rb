# frozen_string_literal: true

module Lapidary
  # Archives a single edge by key and clears associated analysis records.
  # Orchestrates GraphRepository and AnalysisRecordRepository.
  class EdgeArchiver
    include Dependency['analysis.repositories.edge_archive_writer']
    include Dependency['analysis.repositories.analysis_record_repository']

    def call(source:, target:, relationship:)
      result = edge_archive_writer.archive_by_key(source: source, target: target, relationship: relationship)
      deleted = analysis_record_repository.delete_by_entities(result.entity_pairs)
      { archived: 1, analysis_records_cleared: deleted }
    end
  end
end
