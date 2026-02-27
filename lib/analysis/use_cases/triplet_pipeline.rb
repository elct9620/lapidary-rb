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
        results = triplets.map { |triplet| process_triplet(triplet, arguments, observation) }
        counts = results.tally
        counts.default = 0
        @logger.info(self,
                     "Extracted #{triplets.size} triplets: #{counts[:written]} written, " \
                     "#{counts[:rejected]} rejected, #{counts[:duplicated]} duplicated",
                     total: triplets.size, written: counts[:written],
                     rejected: counts[:rejected], duplicated: counts[:duplicated])
      end

      private

      def process_triplet(triplet, arguments, observation)
        result = @validator.call(triplet)

        if result.errors.any?
          @logger.warn(self, "Invalid triplet rejected: #{result.errors.join(', ')}")
          return :rejected
        end

        write_triplet(result.triplet, arguments, observation)
      end

      def write_triplet(triplet, arguments, observation)
        normalized = @normalizer.call(triplet, arguments)
        triplet_observation = observation.with(evidence: normalized.evidence)
        write_result = @graph_repository.save_triplet(normalized, triplet_observation)
        write_result == :duplicate ? :duplicated : :written
      end
    end
  end
end
