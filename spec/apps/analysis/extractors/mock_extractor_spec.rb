# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::MockExtractor do
  subject(:extractor) { described_class.new }

  describe '#call' do
    it 'returns an array of triplets' do
      triplets = extractor.call({ entity_type: 'issue', entity_id: 1 })

      expect(triplets).to all(be_a(Analysis::Entities::Triplet))
    end

    it 'returns valid triplets that pass ontology validation' do
      validator = Analysis::Ontology::Validator.new
      triplets = extractor.call({ entity_type: 'issue', entity_id: 1 })

      results = triplets.map { |triplet| validator.call(triplet) }

      expect(results).to all(satisfy { |r| r.errors.empty? })
    end
  end
end
