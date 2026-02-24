# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::LlmExtractor do
  subject(:extractor) { described_class.new(llm: llm) }

  let(:llm) { double('RubyLLM', chat: chat) }
  let(:chat) { double('RubyLLM::Chat', with_schema: nil, ask: response) }
  let(:response) { double('RubyLLM::Message') }

  before do
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(response)
  end

  describe '#call' do
    context 'with a valid LLM response' do
      let(:job_arguments) { { entity_type: 'issue', entity_id: 12_345 } }

      before do
        allow(response).to receive(:content).and_return(
          {
            'triplets' => [
              {
                'subject' => { 'name' => 'matz', 'is_committer' => true },
                'relationship' => 'Maintenance',
                'object' => { 'type' => 'CoreModule', 'name' => 'String' }
              },
              {
                'subject' => { 'name' => 'contributor', 'is_committer' => false },
                'relationship' => 'Contribute',
                'object' => { 'type' => 'Stdlib', 'name' => 'json' }
              }
            ]
          }
        )
      end

      it 'returns an array of Triplet entities' do
        triplets = extractor.call(job_arguments)

        expect(triplets).to all(be_a(Analysis::Entities::Triplet))
        expect(triplets.size).to eq(2)
      end

      it 'maps subject correctly' do
        triplets = extractor.call(job_arguments)

        expect(triplets.first.subject.type).to eq(Analysis::Entities::NodeType::RUBYIST)
        expect(triplets.first.subject.name).to eq('matz')
        expect(triplets.first.subject.properties).to eq({ is_committer: true })
      end

      it 'maps relationship correctly' do
        triplets = extractor.call(job_arguments)

        expect(triplets.first.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
        expect(triplets.last.relationship).to eq(Analysis::Entities::RelationshipType::CONTRIBUTE)
      end

      it 'maps object correctly' do
        triplets = extractor.call(job_arguments)

        expect(triplets.first.object.type).to eq(Analysis::Entities::NodeType::CORE_MODULE)
        expect(triplets.first.object.name).to eq('String')
        expect(triplets.last.object.type).to eq(Analysis::Entities::NodeType::STDLIB)
        expect(triplets.last.object.name).to eq('json')
      end

      it 'returns triplets that pass ontology validation' do
        validator = Analysis::Ontology::Validator.new
        triplets = extractor.call(job_arguments)

        results = triplets.map { |triplet| validator.call(triplet) }

        expect(results).to all(satisfy { |r| r.errors.empty? })
      end
    end

    context 'when LLM returns empty triplets' do
      before do
        allow(response).to receive(:content).and_return({ 'triplets' => [] })
      end

      it 'returns an empty array' do
        expect(extractor.call({ entity_type: 'issue', entity_id: 1 })).to eq([])
      end
    end

    context 'when LLM returns non-Hash content' do
      before do
        allow(response).to receive(:content).and_return('unexpected string')
      end

      it 'returns an empty array' do
        expect(extractor.call({ entity_type: 'issue', entity_id: 1 })).to eq([])
      end
    end

    context 'when LLM returns nil content' do
      before do
        allow(response).to receive(:content).and_return(nil)
      end

      it 'returns an empty array' do
        expect(extractor.call({ entity_type: 'issue', entity_id: 1 })).to eq([])
      end
    end

    context 'when a triplet has incomplete data' do
      before do
        allow(response).to receive(:content).and_return(
          {
            'triplets' => [
              {
                'subject' => { 'name' => 'matz', 'is_committer' => true },
                'relationship' => 'Maintenance',
                'object' => { 'type' => 'CoreModule', 'name' => 'String' }
              },
              {
                'subject' => { 'name' => 'someone' },
                'relationship' => 'Contribute'
                # missing 'object'
              },
              {
                'subject' => nil,
                'relationship' => 'Maintenance',
                'object' => { 'type' => 'CoreModule', 'name' => 'Array' }
              }
            ]
          }
        )
      end

      it 'skips incomplete triplets and returns only valid ones' do
        triplets = extractor.call({ entity_type: 'issue', entity_id: 1 })

        expect(triplets.size).to eq(1)
        expect(triplets.first.subject.name).to eq('matz')
      end
    end

    context 'when LLM returns an invalid relationship value' do
      before do
        allow(response).to receive(:content).and_return(
          {
            'triplets' => [
              {
                'subject' => { 'name' => 'matz', 'is_committer' => true },
                'relationship' => 'Unknown',
                'object' => { 'type' => 'CoreModule', 'name' => 'String' }
              }
            ]
          }
        )
      end

      it 'raises ExtractionError wrapping the KeyError' do
        expect do
          extractor.call({ entity_type: 'issue', entity_id: 1 })
        end.to raise_error(Analysis::Entities::ExtractionError)
      end
    end

    context 'when LLM returns an invalid object type' do
      before do
        allow(response).to receive(:content).and_return(
          {
            'triplets' => [
              {
                'subject' => { 'name' => 'matz', 'is_committer' => true },
                'relationship' => 'Maintenance',
                'object' => { 'type' => 'InvalidType', 'name' => 'String' }
              }
            ]
          }
        )
      end

      it 'raises ExtractionError wrapping the KeyError' do
        expect do
          extractor.call({ entity_type: 'issue', entity_id: 1 })
        end.to raise_error(Analysis::Entities::ExtractionError)
      end
    end

    context 'with prompt building' do
      let(:prompt_builder) { instance_double(Analysis::Extractors::PromptBuilder) }

      subject(:extractor) { described_class.new(llm: llm, prompt_builder: prompt_builder) }

      before do
        allow(prompt_builder).to receive(:call).and_return('test prompt')
        allow(response).to receive(:content).and_return({ 'triplets' => [] })
      end

      it 'delegates prompt building to PromptBuilder' do
        extractor.call({ entity_type: 'issue', entity_id: 1 })

        expect(prompt_builder).to have_received(:call).with({ entity_type: 'issue', entity_id: 1 })
      end

      it 'sends the built prompt to the LLM' do
        extractor.call({ entity_type: 'issue', entity_id: 1 })

        expect(chat).to have_received(:ask).with('test prompt')
      end
    end

    context 'when LLM API fails' do
      before do
        allow(chat).to receive(:ask).and_raise(StandardError, 'API connection failed')
      end

      it 'wraps the error as ExtractionError' do
        expect do
          extractor.call({ entity_type: 'issue', entity_id: 1 })
        end.to raise_error(Analysis::Entities::ExtractionError, 'API connection failed')
      end
    end
  end
end
