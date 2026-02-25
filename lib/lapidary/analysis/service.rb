# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'

module Lapidary
  module Analysis
    # Background worker that polls and processes analysis jobs.
    class Service < Async::Service::Managed::Service
      POLL_INTERVAL = 1

      def run(_instance, _evaluator)
        Async do
          logger = container['logger']
          logger.info(self) { 'Analysis worker started' }
          poll_loop(logger)
        end
      end

      private

      def container
        Lapidary::Container
      end

      def poll_loop(logger)
        use_case = build_use_case
        loop do
          processed = use_case.call
          sleep POLL_INTERVAL unless processed
        rescue ::Analysis::Entities::JobError => e
          logger.error(self) { "Job processing error: #{e.class}: #{e.message}" }
          sleep POLL_INTERVAL
        end
      end

      def build_use_case
        ::Analysis::UseCases::ProcessJob.new(
          job_repository: container['analysis.repositories.job_repository'],
          analysis_record_repository: container['analysis.repositories.analysis_record_repository'],
          extractor: container['analysis.extractors.llm_extractor'],
          # Validator is an inner-layer domain object, not container-managed
          validator: ::Analysis::Ontology::Validator.new,
          logger: container['logger']
        )
      end
    end
  end
end
