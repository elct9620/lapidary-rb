# frozen_string_literal: true

module Analysis
  module Extractors
    # Parses raw LLM structured output into domain Triplet entities.
    # Separated from LlmExtractor to isolate parsing logic from LLM communication.
    class ResponseParser
      def initialize(logger:)
        @logger = logger
      end

      def call(content)
        raw_triplets = extract_raw_triplets(content)
        return [] unless raw_triplets

        raw_triplets.filter_map { |raw| build_triplet(raw) if valid_triplet_shape?(raw) }
      end

      private

      def valid_triplet_shape?(raw)
        raw.is_a?(Hash) && raw['subject'].is_a?(Hash) && raw['object'].is_a?(Hash)
      end

      def extract_raw_triplets(content)
        return if content.nil?
        return warn_malformed_response unless content.is_a?(Hash)

        triplets = content['triplets']
        return warn_malformed_response unless triplets.is_a?(Array)

        triplets
      end

      def warn_malformed_response
        @logger.warn(self, 'LLM response malformed: expected Hash with triplets Array',
                     expected: 'Hash with triplets Array')
      end

      def build_triplet(raw)
        Entities::Triplet.new(
          subject: build_subject(raw['subject']),
          relationship: resolve_relationship(raw['relationship']),
          object: build_object(raw['object']),
          evidence: raw['evidence']
        )
      rescue TypeError, NoMethodError => e
        warn_malformed_triplet(e)
      end

      def resolve_relationship(value)
        TripletSchema::RELATIONSHIP_MAP.fetch(value) do
          raise Entities::ExtractionError, "unknown relationship: #{value}"
        end
      end

      def warn_malformed_triplet(error)
        @logger.warn(self, "Skipping malformed triplet: #{error.class}: #{error.message}")
      end

      def build_subject(raw)
        Entities::Node.new(
          type: Entities::NodeType::RUBYIST,
          name: raw['name'].to_str,
          properties: { role: raw['role'] || 'contributor' }
        )
      end

      def build_object(raw)
        Entities::Node.new(
          type: TripletSchema::NODE_TYPE_MAP.fetch(raw['type']) do
            raise Entities::ExtractionError, "unknown node type: #{raw['type']}"
          end,
          name: raw['name'].to_str
        )
      end
    end
  end
end
