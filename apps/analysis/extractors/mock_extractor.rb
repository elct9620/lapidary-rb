# frozen_string_literal: true

module Analysis
  module Extractors
    # Returns hardcoded triplets for testing the extraction/validation pipeline.
    # Duck typing contract: #call(job_arguments) -> [Triplet]
    class MockExtractor
      def call(_job_arguments)
        [maintenance_triplet, contribute_triplet]
      end

      private

      def maintenance_triplet
        Entities::Triplet.new(
          subject: Entities::Node.new(
            type: Entities::NodeType::RUBYIST, name: 'matz', properties: { is_committer: true }
          ),
          relationship: Entities::RelationshipType::MAINTENANCE,
          object: Entities::Node.new(type: Entities::NodeType::CORE_MODULE, name: 'String')
        )
      end

      def contribute_triplet
        Entities::Triplet.new(
          subject: Entities::Node.new(type: Entities::NodeType::RUBYIST, name: 'contributor'),
          relationship: Entities::RelationshipType::CONTRIBUTE,
          object: Entities::Node.new(type: Entities::NodeType::STDLIB, name: 'json')
        )
      end
    end
  end
end
