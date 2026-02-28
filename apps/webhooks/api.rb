# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Webhook endpoint for receiving external issue notifications
  class API < Lapidary::BaseController
    error Entities::IssueFetchError do
      logger.warn(self, "Issue fetch failed: #{env['sinatra.error'].message}")
      halt_json 502, error: 'upstream service error'
    end

    post '/webhook' do
      authenticate!
      payload = parse_json_body!
      result = validate_payload!(payload)

      issue_id = result[:issue_id]

      if defined?(Async::Task) && Async::Task.current?
        Async(transient: true) do
          build_handle_webhook.call(issue_id)
        rescue StandardError => e
          ::Sentry.capture_exception(e)
          logger.error(self, "Background processing failed: #{e.class}: #{e.message}")
        end
      else
        build_handle_webhook.call(issue_id)
      end

      status 202
      respond_json(status: 'accepted')
    end

    private

    def build_handle_webhook
      UseCases::HandleWebhook.new(
        issue_repository: container['webhooks.repositories.issue_repository'],
        analysis_record_repository: container['webhooks.repositories.analysis_record_repository'],
        analysis_scheduler: container['webhooks.adapters.analysis_scheduler']
      )
    end

    def authenticate!
      secret = Lapidary.config.webhook.secret
      return unless secret

      token = params['token'].to_s
      return if Rack::Utils.secure_compare(token, secret)

      logger.warn(self, 'Authentication failure')
      halt_json 401, error: 'unauthorized'
    end

    def parse_json_body!
      reject_unsupported_content_type!

      JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      logger.warn(self, "Invalid JSON in webhook request: #{e.message}")
      halt_json 422, error: 'invalid JSON'
    end

    def reject_unsupported_content_type!
      return if request.content_type&.include?('application/json')

      logger.warn(self, 'Rejected webhook with unsupported Content-Type', content_type: request.content_type)
      halt_json 415, error: 'Content-Type must be application/json'
    end

    def validate_payload!(payload)
      validate_with_contract!('webhooks.contract', payload)
    end
  end
end
