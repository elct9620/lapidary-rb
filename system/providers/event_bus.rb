# frozen_string_literal: true

Lapidary::Container.register_provider(:event_bus) do
  start do
    register('event_bus', Lapidary::EventBus.new)
  end
end
