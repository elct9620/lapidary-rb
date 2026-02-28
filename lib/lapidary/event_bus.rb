# auto_register: false
# frozen_string_literal: true

module Lapidary
  # Central event bus for cross-context domain event publishing and subscription.
  class EventBus
    include Dry::Events::Publisher[:lapidary]

    ENTITY_DISCOVERED = 'webhooks.entity_discovered'

    register_event(ENTITY_DISCOVERED)
  end
end
