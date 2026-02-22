# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Use case for handling webhook notifications.
  # Records the issue as analyzed and returns a success response.
  class HandleWebhook
    def initialize(analysis_record_repository:)
      @analysis_record_repository = analysis_record_repository
    end

    def call(issue)
      track_issue(issue)
      track_journals(issue)

      { status: 'ok' }
    end

    private

    def track_issue(issue)
      record = AnalysisRecord.new(entity_type: 'issue', entity_id: issue.id)

      return if @analysis_record_repository.exists?(record)

      record.analyze
      @analysis_record_repository.save(record)
    end

    def track_journals(issue)
      return if issue.journal_ids.empty?

      untracked = @analysis_record_repository.untracked_journal_ids(issue.journal_ids)
      untracked.each do |journal_id|
        record = AnalysisRecord.new(entity_type: 'journal', entity_id: journal_id)
        record.analyze
        @analysis_record_repository.save(record)
      end
    end
  end
end
