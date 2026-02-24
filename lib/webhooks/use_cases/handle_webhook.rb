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
        schedule(issue, untracked)
      end

      private

      def find_untracked(issue)
        candidates = build_issue_records(issue) + build_journal_records(issue)
        @analysis_record_repository.untracked(candidates)
      end

      def schedule(issue, records)
        records.each do |record|
          arguments = build_job_arguments(issue, record)
          @analysis_scheduler.schedule(**arguments)
        end
        nil
      end

      def build_job_arguments(issue, record)
        if record.entity_type == EntityType::ISSUE
          build_issue_arguments(issue)
        else
          build_journal_arguments(issue, record)
        end
      end

      def build_issue_arguments(issue)
        {
          entity_type: EntityType::ISSUE.to_s,
          entity_id: issue.id,
          content: issue.subject,
          author_username: issue.author_username,
          author_display_name: issue.author_display_name
        }
      end

      def build_journal_arguments(issue, record)
        journal = issue.journals.find { |j| j.id == record.entity_id }
        {
          entity_type: EntityType::JOURNAL.to_s,
          entity_id: journal.id,
          content: journal.notes,
          author_username: journal.author_username,
          author_display_name: journal.author_display_name,
          issue_id: issue.id,
          issue_content: issue.subject
        }
      end

      def build_issue_records(issue)
        [Entities::AnalysisRecord.new(entity_type: EntityType::ISSUE, entity_id: issue.id)]
      end

      def build_journal_records(issue)
        issue.journal_ids.map { |id| Entities::AnalysisRecord.new(entity_type: EntityType::JOURNAL, entity_id: id) }
      end
    end
  end
end
