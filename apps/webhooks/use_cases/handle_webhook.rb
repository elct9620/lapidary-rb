# auto_register: false
# frozen_string_literal: true

module Webhooks
  module UseCases
    # Use case for handling webhook notifications.
    # Records the issue as analyzed and returns a success response.
    class HandleWebhook
      def initialize(analysis_record_repository:)
        @analysis_record_repository = analysis_record_repository
      end

      def call(issue)
        track_records(build_issue_records(issue))
        track_records(build_journal_records(issue))

        { status: 'ok' }
      end

      private

      def build_issue_records(issue)
        [Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: issue.id)]
      end

      def build_journal_records(issue)
        issue.journal_ids.map { |id| Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: id) }
      end

      def track_records(records)
        @analysis_record_repository.untracked(records).each do |record|
          record.analyze
          @analysis_record_repository.save(record)
        end
      end
    end
  end
end
