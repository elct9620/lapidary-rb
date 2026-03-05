# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'

module Lapidary
  module Analysis
    # Background worker that polls and processes analysis jobs.
    class Worker < Async::Service::Managed::Service
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
        job_handler = container['analysis.jobs.analysis_job']
        periodic_tasks = build_periodic_tasks(job_repository)

        loop do
          periodic_tasks.each { |t| t[:last_at] = maybe_run(t[:action], t[:last_at]) }
          poll_once(job_handler, job_repository)
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
        report_error(e, 'Periodic task error')
        Time.now
      end

      def poll_once(job_handler, job_repository)
        job = job_repository.claim_next
        unless job
          sleep poll_interval
          return
        end

        job_handler.call(job)
      rescue ::Analysis::Entities::JobError => e
        report_error(e, 'Job processing error')
        sleep poll_interval
      end

      def report_error(error, context_message)
        ::Sentry.capture_exception(error)
        logger.error(self, "#{context_message}: #{error.class}: #{error.message}")
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
          edge_archive_writer: container['analysis.repositories.edge_archive_writer'],
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
    end
  end
end
