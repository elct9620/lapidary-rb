# auto_register: false
# frozen_string_literal: true

module Analysis
  module UseCases
    # Claims and processes the next pending analysis job.
    class ProcessJob
      def initialize(job_repository:, analysis_record_repository:, pipeline:, logger:)
        @job_repository = job_repository
        @analysis_record_repository = analysis_record_repository
        @pipeline = pipeline
        @logger = logger
      end

      def call
        job = @job_repository.claim_next
        return false unless job

        process(job)
        true
      end

      private

      def process(job)
        record = build_record(job)
        record.analyze
        observation = build_observation(job)
        @pipeline.call(job.arguments, observation)
        @analysis_record_repository.save(record)

        job.complete
        @job_repository.save(job)
      rescue Entities::AnalysisTrackingError, Entities::JobError, Entities::ExtractionError, Entities::GraphError => e
        handle_failure(job, e)
      end

      def handle_failure(job, error)
        if job.retryable?
          job.retry(error.message)
        else
          job.fail(error.message)
          @logger.error(self) { "Job #{job.id} permanently failed: #{error.message}" }
        end
        @job_repository.save(job)
      end

      def build_observation(job)
        {
          observed_at: job.arguments.created_on || Time.now.iso8601,
          source_entity_type: job.arguments.entity_type,
          source_entity_id: job.arguments.entity_id
        }
      end

      def build_record(job)
        Entities::AnalysisRecord.new(
          entity_type: Entities::EntityType.new(value: job.arguments.entity_type),
          entity_id: job.arguments.entity_id
        )
      end
    end
  end
end
