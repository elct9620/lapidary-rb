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
        normalized = @normalizer.call(triplet, arguments)
        validated = validate_or_correct(normalized, arguments)
        return :rejected unless validated

        final_triplet = apply_role_fallback(validated.triplet)
        log_role_downgrade(normalized, final_triplet)
        write_triplet(final_triplet, observation)
      end

      def validate_or_correct(triplet, arguments)
        result = @validator.call(triplet)
        return result unless result.errors.any?

        attempt_correction(triplet, result.errors, arguments)
      end

      def attempt_correction(triplet, errors, arguments)
        @logger.info(self, "Attempting correction for: #{errors.join(', ')}",
                     subject: triplet.subject.name, object: triplet.object.name)

        corrected = @extractor.correct(triplet, errors, arguments)
        return log_correction_failure(errors, ['no correction returned']) unless corrected

        corrected = apply_role_fallback(corrected)
        re_result = @validator.call(corrected)
        return log_correction_failure(errors, re_result.errors) if re_result.errors.any?

        re_result
      rescue Entities::ExtractionError => e
        log_correction_failure(errors, [e.message])
      end

      def log_correction_failure(original_errors, correction_errors)
        @logger.warn(self, "Correction failed: original=#{original_errors.join(', ')}, " \
                           "after=#{correction_errors.join(', ')}")
        nil
      end

      def apply_role_fallback(triplet)
        return triplet unless triplet.relationship == Entities::RelationshipType::MAINTENANCE
        return triplet if triplet.subject.properties[:role] == 'maintainer'

        triplet.with(relationship: Entities::RelationshipType::CONTRIBUTE)
      end

      def log_role_downgrade(original, validated)
        return if validated.relationship == original.relationship

        @logger.info(self, 'Maintenance downgraded to Contribute (non-maintainer role)',
                     subject: original.subject.name, role: original.subject.properties[:role])
      end

      def write_triplet(triplet, observation)
        triplet_observation = observation.with(evidence: triplet.evidence)
        write_result = @graph_repository.save_triplet(triplet, triplet_observation)
        write_result == :duplicate ? :duplicated : :written
      end
    end
  end
end
