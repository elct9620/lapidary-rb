# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Webhook endpoint for receiving external issue notifications
  class API < Lapidary::BaseController
    post '/webhook' do
      payload = parse_json_body!
      result = validate_payload!(payload)

      issue = container['webhooks.repositories.issue_repository'].find(result.to_h[:issue_id])

      use_case = UseCases::HandleWebhook.new(
        analysis_record_repository: container['webhooks.repositories.analysis_record_repository']
      )
      untracked_records = use_case.call(issue)

      scheduler = container['webhooks.adapters.analysis_scheduler']
      untracked_records.each do |record|
        scheduler.schedule(entity_type: record.entity_type, entity_id: record.entity_id)
      end

      status 202
      content_type :json
      JSON.generate(status: 'accepted')
    rescue Redmine::API::FetchError => e
      logger.warn(self, e.message)
      halt_json 502, error: 'upstream service error'
    end

    private

    def parse_json_body!
      unless request.content_type&.include?('application/json')
        logger.warn(self, 'Rejected webhook with unsupported Content-Type')
        halt_json 415, error: 'Content-Type must be application/json'
      end

      JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      logger.warn(self, 'Invalid JSON in webhook request', e)
      halt_json 422, error: 'invalid JSON'
    end

    def validate_payload!(payload)
      result = container['webhooks.contract'].call(payload)

      if result.failure?
        logger.warn(self, 'Webhook validation failed', result.errors.to_h)
        halt_json 422, errors: result.errors.to_h
      end

      result
    end
  end
end
