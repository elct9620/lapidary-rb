# auto_register: false
# frozen_string_literal: true

module Analysis
  module UseCases
    # Extracts, validates, normalizes, and writes triplets to the knowledge graph.
    class TripletPipeline
      def initialize(extractor:, validator:, normalizer:, graph_repository:, logger:)
        @extractor = extractor
        @validator = validator
        @normalizer = normalizer
        @graph_repository = graph_repository
        @logger = logger
      end

      def call(arguments, observation)
        triplets = @extractor.call(arguments)
        triplets.each { |triplet| process_triplet(triplet, arguments, observation) }
      end

      private

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
    end
  end
end
