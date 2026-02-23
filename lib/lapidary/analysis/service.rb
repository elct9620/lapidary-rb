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
          logger = Console.logger
          logger.info(self) { 'Analysis worker started' }
          poll_loop(build_use_case, logger)
        end
      end

      private

      def poll_loop(use_case, logger)
        loop do
          processed = use_case.call
          sleep POLL_INTERVAL unless processed
        rescue StandardError => e
          logger.error(self) { "Job processing error: #{e.class}: #{e.message}" }
          sleep POLL_INTERVAL
        end
      end

      def build_use_case
        container = Lapidary::Container
        ::Analysis::UseCases::ProcessJob.new(
          job_repository: container['analysis.repositories.job_repository'],
          analysis_record_repository: container['analysis.repositories.analysis_record_repository']
        )
      end
    end
  end
end
