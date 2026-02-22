# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Webhook endpoint for receiving external issue notifications
  class API < Lapidary::BaseController
    include Lapidary::Dependency[
      'logger',
      'webhooks.contract',
      'webhooks.analysis_record_repository'
    ]

    post '/webhook' do
      halt 415 unless request.content_type&.include?('application/json')

      begin
        payload = JSON.parse(request.body.read)
      rescue JSON::ParserError => e
        logger.warn(self, 'Invalid JSON in webhook request', e)
        halt 422
      end

      result = contract.call(payload)

      halt 422, { 'Content-Type' => 'application/json' }, JSON.generate(errors: result.errors.to_h) if result.failure?

      use_case = HandleWebhook.new(analysis_record_repository: analysis_record_repository, logger: logger)
      output = use_case.call(result.to_h[:issue_id])

      content_type :json
      JSON.generate(output)
    end
  end
end
