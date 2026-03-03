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
    Analysis::Entities::Observation.new(observed_at: '2024-01-15T10:30:00Z', source_entity_type: 'issue',
                                        source_entity_id: 1)
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
        instance_double(Analysis::Extractors::LlmExtractor, call: [maintainer_triplet])
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
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet], correct: nil)
      end

      it 'logs a warning and does not write to graph' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:warn).with(pipeline, a_kind_of(String))
        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
      end
    end

    context 'when an invalid triplet is corrected successfully' do
      let(:invalid_triplet) do
        maintainer_triplet(module_name: 'InvalidModule', evidence: 'matz committed to InvalidModule')
      end

      let(:corrected_triplet) do
        maintainer_triplet(evidence: 'matz committed to String')
      end

      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet], correct: corrected_triplet)
      end

      it 'writes the corrected triplet to the knowledge graph' do
        pipeline.call(arguments, observation)

        db = Lapidary::Container['database']
        expect(db[:nodes].where(id: 'core_module://String').count).to eq(1)
        expect(db[:edges].count).to eq(1)
      end

      it 'logs correction attempt' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:info).with(pipeline, /Attempting correction/, anything)
      end
    end

    context 'when correction also fails validation' do
      let(:invalid_triplet) do
        maintainer_triplet(module_name: 'InvalidModule', evidence: 'matz committed to InvalidModule')
      end

      let(:still_invalid_triplet) do
        maintainer_triplet(module_name: 'StillInvalid', evidence: 'matz committed to StillInvalid')
      end

      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet],
                                                            correct: still_invalid_triplet)
      end

      it 'rejects the triplet and does not write to graph' do
        pipeline.call(arguments, observation)

        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
      end

      it 'logs a warning for final rejection' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:warn).with(pipeline, /Correction failed/)
      end
    end

    context 'when correction returns nil' do
      let(:invalid_triplet) do
        maintainer_triplet(module_name: 'InvalidModule', evidence: 'matz committed to InvalidModule')
      end

      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet], correct: nil)
      end

      it 'rejects the triplet' do
        pipeline.call(arguments, observation)

        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
        expect(logger).to have_received(:warn).with(pipeline, /Correction failed/)
      end
    end

    context 'when correction raises ExtractionError' do
      let(:invalid_triplet) do
        maintainer_triplet(module_name: 'InvalidModule', evidence: 'matz committed to InvalidModule')
      end

      let(:extractor) do
        ext = instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet])
        allow(ext).to receive(:correct).and_raise(Analysis::Entities::ExtractionError, 'LLM API failed')
        ext
      end

      it 'rejects the triplet without raising' do
        expect { pipeline.call(arguments, observation) }.not_to raise_error

        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
        expect(logger).to have_received(:warn).with(pipeline, /Correction failed/)
      end
    end

    context 'when the same triplet is extracted twice' do
      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [maintainer_triplet])
      end

      before do
        pipeline.call(arguments, observation)
      end

      it 'logs duplicated count' do
        pipeline.call(arguments, observation)

        expect(logger).to have_received(:info).with(pipeline, a_string_including('duplicated'),
                                                    a_hash_including(duplicated: 1))
      end
    end

    context 'when a non-maintainer Maintenance triplet is extracted' do
      let(:corrected) do
        build_triplet(
          subject: build_node(type: Analysis::Entities::NodeType::RUBYIST, name: 'contributor',
                              properties: { role: 'contributor' }),
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: build_node(type: Analysis::Entities::NodeType::CORE_MODULE, name: 'String')
        )
      end

      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [contributor_triplet], correct: corrected)
      end

      it 'triggers correction and writes the corrected triplet' do
        pipeline.call(arguments, observation)

        edge = Lapidary::Container['database'][:edges].first
        expect(edge[:relationship]).to eq('Contribute')
        expect(logger).to have_received(:info).with(pipeline, /Attempting correction/, anything)
      end
    end

    context 'when correction returns Maintenance with non-maintainer role' do
      let(:still_maintenance) do
        build_triplet(
          subject: build_node(type: Analysis::Entities::NodeType::RUBYIST, name: 'contributor',
                              properties: { role: 'submaintainer' }),
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: build_node(type: Analysis::Entities::NodeType::CORE_MODULE, name: 'String')
        )
      end

      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [contributor_triplet],
                                                            correct: still_maintenance)
      end

      it 'applies role fallback to downgrade to Contribute' do
        pipeline.call(arguments, observation)

        edge = Lapidary::Container['database'][:edges].first
        expect(edge[:relationship]).to eq('Contribute')
        expect(logger).to have_received(:info).with(
          pipeline, 'Maintenance downgraded to Contribute (non-maintainer role)', anything
        )
      end
    end
  end
end
