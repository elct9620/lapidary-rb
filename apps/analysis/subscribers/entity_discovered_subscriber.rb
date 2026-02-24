# frozen_string_literal: true

module Analysis
  module Subscribers
    # Subscribes to webhooks.entity_discovered events and enqueues analysis jobs.
    class EntityDiscoveredSubscriber
      include Lapidary::Dependency['analysis.repositories.job_repository']

      def on_webhooks_entity_discovered(event)
        job = Entities::Job.new(arguments: event.to_h)
        job_repository.enqueue(job)
      end
    end
  end
end
