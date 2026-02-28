# frozen_string_literal: true

Lapidary::Container.register_provider(:event_bus) do
  start do
    bus = Class.new do
      include Dry::Events::Publisher[:lapidary]

      register_event('webhooks.entity_discovered')
    end.new

    register('event_bus', bus)
  end
end
