# frozen_string_literal: true

module Webhooks
  module Adapters
    # Anti-Corruption Layer: publishes domain events when entities are discovered.
    # Analysis BC subscribes to these events independently.
    class AnalysisScheduler
      include Lapidary::Dependency['event_bus']

      def schedule(entity_type:, entity_id:)
        event_bus.publish('webhooks.entity_discovered', entity_type: entity_type, entity_id: entity_id)
      end
    end
  end
end
