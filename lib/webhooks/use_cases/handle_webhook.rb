# auto_register: false
# frozen_string_literal: true

module Webhooks
  module UseCases
    # Use case for handling webhook notifications.
    # Filters entities to find untracked ones and returns them for further processing.
    class HandleWebhook
      def initialize(issue_repository:, analysis_record_repository:, analysis_scheduler:)
        @issue_repository = issue_repository
        @analysis_record_repository = analysis_record_repository
        @analysis_scheduler = analysis_scheduler
      end

      def call(issue_id)
        issue = @issue_repository.find(issue_id)

        untracked = find_untracked(issue)
        schedule(untracked)
      end

      private

      def find_untracked(issue)
        untracked = []
        untracked.concat(@analysis_record_repository.untracked(build_issue_records(issue)))
        untracked.concat(@analysis_record_repository.untracked(build_journal_records(issue)))
        untracked
      end

      def schedule(records)
        records.each do |record|
          @analysis_scheduler.schedule(entity_type: record.entity_type, entity_id: record.entity_id)
        end
      end

      def build_issue_records(issue)
        [Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: issue.id)]
      end

      def build_journal_records(issue)
        issue.journal_ids.map { |id| Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: id) }
      end
    end
  end
end
