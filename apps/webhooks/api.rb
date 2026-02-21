# frozen_string_literal: true

module Webhooks
  # Webhook endpoint for receiving external issue notifications
  class API < Lapidary::BaseController
    post '/webhook' do
      halt 415 unless request.content_type&.include?('application/json')

      begin
        payload = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422
      end

      issue_id = payload['issue_id']
      halt 422 unless issue_id.is_a?(Integer) && issue_id.positive?

      result = HandleWebhook.new.call(issue_id)

      content_type :json
      JSON.generate(result)
    end
  end
end
