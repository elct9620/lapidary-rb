# frozen_string_literal: true

module Webhooks
  module Adapters
    # Anti-Corruption Layer: translates Webhooks domain concepts
    # into Analysis domain operations without leaking Analysis internals.
    class AnalysisScheduler
      include Lapidary::Dependency['analysis.repositories.job_repository']

      def schedule(entity_type:, entity_id:)
        job = Analysis::Entities::Job.new(arguments: { entity_type: entity_type.to_s, entity_id: entity_id })
        job_repository.enqueue(job)
      end
    end
  end
end
