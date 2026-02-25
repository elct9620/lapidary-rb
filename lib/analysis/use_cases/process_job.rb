# auto_register: false
# frozen_string_literal: true

module Analysis
  module UseCases
    # Claims and processes the next pending analysis job.
    class ProcessJob
      def initialize(job_repository:, analysis_record_repository:, extractor:, validator:, # rubocop:disable Metrics/ParameterLists
                     normalizer:, graph_repository:, logger:)
        @job_repository = job_repository
        @analysis_record_repository = analysis_record_repository
        @extractor = extractor
        @validator = validator
        @normalizer = normalizer
        @graph_repository = graph_repository
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
        pipeline(job)
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

      def pipeline(job)
        observation = build_observation(job)
        triplets = @extractor.call(job.arguments)
        triplets.each { |triplet| process_triplet(triplet, job.arguments, observation) }
      end

      def process_triplet(triplet, arguments, observation)
        result = @validator.call(triplet)
        log_downgrades(result.downgrades)

        if result.errors.any?
          @logger.warn(self) { "Invalid triplet rejected: #{result.errors.join(', ')}" }
          return
        end

        normalized = @normalizer.call(result.triplet, arguments)
        triplet_observation = observation.merge(evidence: normalized.evidence)
        write_result = @graph_repository.save_triplet(normalized, triplet_observation)
        @logger.info(self) { 'Duplicate observation skipped' } if write_result == :duplicate
      end

      def log_downgrades(downgrades)
        downgrades.each { |msg| @logger.info(self) { msg } }
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
