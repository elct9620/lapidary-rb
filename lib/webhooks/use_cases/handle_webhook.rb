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

      def call(issue_id, force: false)
        issue = @issue_repository.find(issue_id)

        records = find_schedulable(issue, force: force)
        schedule(issue, records)
      end

      private

      def find_schedulable(issue, force:)
        candidates = build_issue_records(issue) + build_journal_records(issue)
        return candidates if force

        @analysis_record_repository.untracked(candidates)
      end

      def schedule(issue, records)
        builder = JobArgumentBuilder.new(issue)
        records.each do |record|
          arguments = builder.call(record)
          @analysis_scheduler.schedule(**arguments)
        end
        records.size
      end

      def build_issue_records(issue)
        [Entities::AnalysisRecord.new(entity_type: Entities::EntityType::ISSUE, entity_id: issue.id)]
      end

      def build_journal_records(issue)
        issue.journal_ids.map { |id| Entities::AnalysisRecord.new(entity_type: Entities::EntityType::JOURNAL, entity_id: id) }
      end
    end
  end
end
