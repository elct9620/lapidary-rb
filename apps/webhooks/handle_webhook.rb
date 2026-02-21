# frozen_string_literal: true

module Webhooks
  # Mock use case for handling webhook notifications.
  # Returns a success response without performing any actual processing.
  class HandleWebhook
    def call(_issue_id)
      { status: 'ok' }
    end
  end
end
