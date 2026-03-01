# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'

module Lapidary
  module Analysis
    # Background worker that polls and processes analysis jobs.
    class Service < Async::Service::Managed::Service
      def run(_instance, _evaluator)
        Async do
          logger.info(self, 'Analysis worker started')
          poll_loop
        end
      end

      private

      def poll_interval
        Lapidary.config.analysis.poll_interval
      end

      def cleanup_interval
        Lapidary.config.analysis.cleanup_interval
      end

      def container
        Lapidary::Container
      end

      def logger
        @logger ||= container['logger']
      end

      def poll_loop
        job_repository = container['analysis.repositories.job_repository']
        use_case = build_use_case(job_repository)
        cleanup = build_cleanup(job_repository)
        last_cleanup_at = Time.now - cleanup_interval

        loop do
          last_cleanup_at = maybe_cleanup(cleanup, last_cleanup_at)
          poll_once(use_case, job_repository)
        end
      end

      def poll_once(use_case, job_repository)
        job = job_repository.claim_next
        unless job
          sleep poll_interval
          return
        end

        with_queue_transaction { use_case.call(job) }
      rescue ::Analysis::Entities::JobError => e
        ::Sentry.capture_exception(e)
        logger.error(self, "Job processing error: #{e.class}: #{e.message}")
        sleep poll_interval
      end

      def with_queue_transaction
        transaction = start_queue_transaction
        yield
      ensure
        transaction&.finish
      end

      def start_queue_transaction
        transaction = ::Sentry.start_transaction(op: 'queue.process', name: 'analysis.process_job')
        ::Sentry.get_current_scope&.set_span(transaction) if transaction
        transaction&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
        transaction
      end

      def maybe_cleanup(cleanup, last_cleanup_at)
        return last_cleanup_at if Time.now - last_cleanup_at < cleanup_interval

        cleanup.call
        Time.now
      rescue ::Analysis::Entities::JobError => e
        ::Sentry.capture_exception(e)
        logger.error(self, "Job cleanup error: #{e.class}: #{e.message}")
        Time.now
      end

      def parse_retention_period
        raw = Lapidary.config.analysis.job_retention
        return ::Analysis::Entities::RetentionPeriod.default unless raw

        parsed = ::Analysis::Entities::RetentionPeriod.parse(raw)
        return parsed if parsed

        logger.warn(self, "Invalid JOB_RETENTION '#{raw}', using default #{::Analysis::Entities::RetentionPeriod.default}",
                    value: raw)
        ::Analysis::Entities::RetentionPeriod.default
      end

      def build_cleanup(job_repository)
        ::Analysis::UseCases::CleanupJobs.new(
          job_repository: job_repository,
          retention_period: parse_retention_period,
          logger: logger
        )
      end

      def build_use_case(job_repository)
        ::Analysis::UseCases::ProcessJob.new(
          job_repository: job_repository,
          analysis_record_repository: container['analysis.repositories.analysis_record_repository'],
          pipeline: build_pipeline,
          logger: logger
        )
      end

      def build_pipeline
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
