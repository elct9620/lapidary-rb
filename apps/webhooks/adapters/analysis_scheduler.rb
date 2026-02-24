# frozen_string_literal: true

module Webhooks
  module Adapters
    # Anti-Corruption Layer: publishes domain events when entities are discovered.
    # Analysis BC subscribes to these events independently.
    class AnalysisScheduler
      include Lapidary::Dependency['event_bus']

      def schedule(**arguments)
        event_bus.publish('webhooks.entity_discovered', **arguments)
      end
    end
  end
end
