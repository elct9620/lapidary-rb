# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'

module Lapidary
  module Analysis
    # Background worker that polls and processes analysis jobs.
    class Service < Async::Service::Managed::Service
      POLL_INTERVAL = 1
      CLEANUP_INTERVAL = 600

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
        use_case = build_use_case(logger)
        cleanup = build_cleanup(logger)
        last_cleanup_at = Time.now - CLEANUP_INTERVAL

        loop do
          last_cleanup_at = maybe_cleanup(cleanup, last_cleanup_at, logger)
          poll_once(use_case, logger)
        end
      end

      def poll_once(use_case, logger)
        processed = use_case.call
        sleep POLL_INTERVAL unless processed
      rescue ::Analysis::Entities::JobError => e
        logger.error(self) { "Job processing error: #{e.class}: #{e.message}" }
        sleep POLL_INTERVAL
      end

      def maybe_cleanup(cleanup, last_cleanup_at, logger)
        return last_cleanup_at if Time.now - last_cleanup_at < CLEANUP_INTERVAL

        cleanup.call
        Time.now
      rescue ::Analysis::Entities::JobError => e
        logger.error(self) { "Job cleanup error: #{e.class}: #{e.message}" }
        Time.now
      end

      def parse_retention_period(logger)
        raw = ENV.fetch('JOB_RETENTION', nil)
        return ::Analysis::Entities::RetentionPeriod.default unless raw

        period = ::Analysis::Entities::RetentionPeriod.parse(raw)
        unless period
          logger.warn(self) { "Invalid JOB_RETENTION '#{raw}', using default 7d" }
          return ::Analysis::Entities::RetentionPeriod.default
        end

        period
      end

      def build_cleanup(logger)
        ::Analysis::UseCases::CleanupJobs.new(
          job_repository: container['analysis.repositories.job_repository'],
          retention_period: parse_retention_period(logger),
          logger: logger
        )
      end

      def build_use_case(logger)
        ::Analysis::UseCases::ProcessJob.new(
          job_repository: container['analysis.repositories.job_repository'],
          analysis_record_repository: container['analysis.repositories.analysis_record_repository'],
          pipeline: build_pipeline(logger),
          logger: logger
        )
      end

      def build_pipeline(logger)
        ::Analysis::UseCases::TripletPipeline.new(
          extractor: container['analysis.extractors.llm_extractor'],
          # Validator and Normalizer are inner-layer domain objects, not container-managed
          validator: ::Analysis::Ontology::Validator.new,
          normalizer: ::Analysis::Ontology::Normalizer.new,
          graph_repository: container['analysis.repositories.graph_repository'],
          logger: logger
        )
      end
    end
  end
end
