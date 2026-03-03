# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'
require_relative 'sentry_queue_span'

module Lapidary
  module Analysis
    # Background worker that polls and processes analysis jobs.
    class Service < Async::Service::Managed::Service
      include SentryQueueSpan

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
        periodic_tasks = build_periodic_tasks(job_repository)

        loop do
          periodic_tasks.each { |t| t[:last_at] = maybe_run(t[:action], t[:last_at]) }
          poll_once(use_case, job_repository)
        end
      end

      def build_periodic_tasks(job_repository)
        initial = Time.now - cleanup_interval
        [
          { action: build_cleanup(job_repository), last_at: initial },
          { action: build_archiver, last_at: initial }
        ]
      end

      def maybe_run(action, last_run_at)
        return last_run_at if Time.now - last_run_at < cleanup_interval

        action.call
        Time.now
      rescue ::Analysis::Entities::JobError, ::Analysis::Entities::GraphError => e
        ::Sentry.capture_exception(e)
        logger.error(self, "Periodic task error: #{e.class}: #{e.message}")
        Time.now
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

      def parse_retention_period
        parse_retention(Lapidary.config.analysis.job_retention,
                        ::Analysis::Entities::RetentionPeriod.default, 'JOB_RETENTION')
      end

      def parse_graph_retention
        parse_retention(Lapidary.config.graph.retention,
                        ::Analysis::Entities::RetentionPeriod.graph_default, 'GRAPH_RETENTION')
      end

      def parse_retention(raw, default, env_var_name)
        return default unless raw

        parsed = ::Analysis::Entities::RetentionPeriod.parse(raw)
        return parsed if parsed

        logger.warn(self, "Invalid #{env_var_name} '#{raw}', using default #{default}", value: raw)
        default
      end

      def build_archiver
        ::Analysis::UseCases::ArchiveEdges.new(
          edge_archive_repository: container['analysis.repositories.edge_archive_repository'],
          analysis_record_repository: container['analysis.repositories.analysis_record_repository'],
          retention_period: parse_graph_retention,
          logger: logger
        )
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
          extractor: build_extractor,
          # Validator and Normalizer are inner-layer domain objects, not container-managed
          validator: ::Analysis::Ontology::Validator.new,
          normalizer: ::Analysis::Ontology::Normalizer.new,
          graph_repository: container['analysis.repositories.graph_repository'],
          logger: logger
        )
      end

      def build_extractor
        ::Analysis::Extractors::LlmExtractor.new(
          llm: container['llm'],
          logger: logger,
          tools: build_tools
        )
      end

      def build_tools
        database = container['database']
        [
          ::Analysis::Extractors::Tools::SearchNodeTool.new(database),
          ::Analysis::Extractors::Tools::ValidateModuleTool.new,
          ::Analysis::Extractors::Tools::SearchEdgeTool.new(database)
        ]
      end
    end
  end
end
