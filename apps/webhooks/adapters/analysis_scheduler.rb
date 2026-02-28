# frozen_string_literal: true

module Webhooks
  module Adapters
    # Anti-Corruption Layer: publishes domain events when entities are discovered.
    # Analysis BC subscribes to these events independently.
    class AnalysisScheduler
      include Lapidary::Dependency['event_bus']

      def schedule(**arguments)
        if defined?(Async::Task) && Async::Task.current?
          Async(transient: true) do
            event_bus.publish(Lapidary::EventBus::ENTITY_DISCOVERED, **arguments)
          end
        else
          event_bus.publish(Lapidary::EventBus::ENTITY_DISCOVERED, **arguments)
        end
      end
    end
  end
end
