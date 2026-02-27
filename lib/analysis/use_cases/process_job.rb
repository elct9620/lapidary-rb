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
        log_processing(job)
        run_pipeline(job)
        complete(job)
      rescue Entities::ProcessingError => e
        handle_failure(job, e)
      end

      def run_pipeline(job)
        record = build_record(job)
        record.analyze
        observation = build_observation(job)
        @pipeline.call(job.arguments, observation)
        @analysis_record_repository.save(record)
      end

      def complete(job)
        job.complete
        @job_repository.save(job)
        @logger.info(self, "Job #{job.id} completed", job_id: job.id)
      end

      def log_processing(job)
        @logger.info(self, "Processing job #{job.id} (#{job.arguments.entity_type}##{job.arguments.entity_id})",
                     job_id: job.id, entity_type: job.arguments.entity_type, entity_id: job.arguments.entity_id)
      end

      def handle_failure(job, error)
        job.retryable? ? schedule_retry(job, error) : mark_failed(job, error)
        @job_repository.save(job)
      end

      def schedule_retry(job, error)
        job.retry(error.message)
        @logger.warn(self, "Job #{job.id} retry scheduled (attempt #{job.attempts}): #{error.message}",
                     job_id: job.id, attempt: job.attempts)
      end

      def mark_failed(job, error)
        job.fail(error.message)
        @logger.error(self, "Job #{job.id} permanently failed: #{error.message}",
                      job_id: job.id)
      end

      def build_observation(job)
        Entities::Observation.new(
          observed_at: job.arguments.created_on || Time.now.iso8601,
          source_entity_type: job.arguments.entity_type,
          source_entity_id: job.arguments.entity_id
        )
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
