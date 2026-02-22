# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Use case for handling webhook notifications.
  # Records the issue as analyzed and returns a success response.
  class HandleWebhook
    def initialize(analysis_record_repository:)
      @analysis_record_repository = analysis_record_repository
    end

    def call(issue_id)
      record = AnalysisRecord.new(entity_type: 'issue', entity_id: issue_id)

      begin
        unless @analysis_record_repository.exists?(record)
          record.analyze
          @analysis_record_repository.save(record)
        end
      rescue StandardError
        # Analysis tracking is supplementary; failures should not affect the response.
      end

      { status: 'ok' }
    end
  end
end
