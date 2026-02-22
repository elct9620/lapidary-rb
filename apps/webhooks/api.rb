# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Webhook endpoint for receiving external issue notifications
  class API < Lapidary::BaseController
    post '/webhook' do
      unless request.content_type&.include?('application/json')
        logger.warn(self, 'Rejected webhook with unsupported Content-Type')
        halt_json 415, error: 'Content-Type must be application/json'
      end

      begin
        payload = JSON.parse(request.body.read)
      rescue JSON::ParserError => e
        logger.warn(self, 'Invalid JSON in webhook request', e)
        halt_json 422, error: 'invalid JSON'
      end

      result = container['webhooks.contract'].call(payload)

      if result.failure?
        logger.warn(self, 'Webhook validation failed', result.errors.to_h)
        halt_json 422, errors: result.errors.to_h
      end

      use_case = HandleWebhook.new(analysis_record_repository: container['webhooks.analysis_record_repository'])
      output = use_case.call(result.to_h[:issue_id])

      content_type :json
      JSON.generate(output)
    end
  end
end
