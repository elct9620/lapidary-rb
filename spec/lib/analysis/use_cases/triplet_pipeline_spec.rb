# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::TripletPipeline do
  subject(:pipeline) do
    described_class.new(
      extractor: extractor,
      validator: validator,
      normalizer: normalizer,
      graph_repository: graph_repository,
      logger: logger
    )
  end

  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }
  let(:extractor) { instance_double(Analysis::Extractors::LlmExtractor, call: []) }
  let(:validator) { Analysis::Ontology::Validator.new }
  let(:normalizer) { Analysis::Ontology::Normalizer.new }
  let(:logger) { instance_double(Console::Logger, error: nil, warn: nil, info: nil) }

  let(:arguments) do
    Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1, author_username: 'matz')
  end
  let(:observation) do
    { observed_at: '2024-01-15T10:30:00Z', source_entity_type: 'issue', source_entity_id: 1 }
  end

  describe '#call' do
    context 'when extractor returns no triplets' do
      it 'writes nothing to the graph' do
        pipeline.call(arguments, observation)

        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
      end

      it 'logs a pipeline summary' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:info).with(pipeline, a_kind_of(String), anything)
      end
    end

    context 'when extractor returns a valid triplet' do
      let(:extractor) do
        triplet = Analysis::Entities::Triplet.new(
          subject: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::RUBYIST,
            name: 'matz',
            properties: { is_committer: true }
          ),
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::CORE_MODULE,
            name: 'String'
          )
        )
        instance_double(Analysis::Extractors::LlmExtractor, call: [triplet])
      end

      it 'writes the triplet to the knowledge graph' do
        pipeline.call(arguments, observation)

        db = Lapidary::Container['database']
        expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
        expect(db[:nodes].where(id: 'core_module://String').count).to eq(1)
        expect(db[:edges].count).to eq(1)
      end
    end

    context 'when extractor returns an invalid triplet' do
      let(:extractor) do
        invalid_triplet = Analysis::Entities::Triplet.new(
          subject: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::CORE_MODULE,
            name: 'String'
          ),
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::RUBYIST,
            name: 'someone'
          )
        )
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet])
      end

      it 'logs a warning and does not write to graph' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:warn).with(pipeline, a_kind_of(String))
        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
      end
    end

    context 'when a triplet is downgraded' do
      let(:extractor) do
        triplet = Analysis::Entities::Triplet.new(
          subject: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::RUBYIST,
            name: 'contributor'
          ),
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: Analysis::Entities::Node.new(
            type: Analysis::Entities::NodeType::CORE_MODULE,
            name: 'String'
          )
        )
        instance_double(Analysis::Extractors::LlmExtractor, call: [triplet])
      end

      it 'still writes the triplet and logs summary with written count' do
        pipeline.call(arguments, observation)

        expect(Lapidary::Container['database'][:edges].count).to eq(1)
        expect(logger).to have_received(:info).with(pipeline, a_kind_of(String), anything)
      end
    end
  end
end
