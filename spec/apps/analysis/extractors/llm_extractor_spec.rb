# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::LlmExtractor do
  subject(:extractor) { described_class.new(llm: llm, logger: logger, response_parser: response_parser) }

  let(:llm) { double('RubyLLM', chat: chat) }
  let(:chat) { double('RubyLLM::Chat', with_instructions: nil, with_tools: nil, with_schema: nil, ask: response) }
  let(:response) { double('RubyLLM::Message') }
  let(:logger) { Lapidary::Container['logger'] }
  let(:response_parser) { Analysis::Extractors::ResponseParser.new(logger: logger) }
  let(:response_content) do
    { 'triplets' => [{ 'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
                       'relationship' => 'Maintenance',
                       'object' => { 'type' => 'CoreModule', 'name' => 'String' },
                       'evidence' => 'matz committed to String' }] }
  end

  before do
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_tools).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(response)
    allow(response).to receive(:content).and_return(response_content)
  end

  describe '#call' do
    let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 12_345) }

    it 'returns parsed triplets from the LLM response' do
      result = extractor.call(job_arguments)

      expect(result.size).to eq(1)
      triplet = result.first
      expect(triplet.subject.name).to eq('matz')
      expect(triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      expect(triplet.object.name).to eq('String')
    end

    context 'when LLM API fails' do
      before do
        allow(chat).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'API connection failed'))
      end

      it 'wraps the error as ExtractionError' do
        expect do
          extractor.call(job_arguments)
        end.to raise_error(Analysis::Entities::ExtractionError, 'API connection failed')
      end
    end
  end

  describe '#correct' do
    let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }
    let(:triplet) do
      Analysis::Entities::Triplet.new(
        subject: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::RUBYIST, name: 'matz',
                                              properties: { role: 'maintainer' }),
        relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
        object: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::CORE_MODULE, name: 'InvalidModule'),
        evidence: 'matz committed to InvalidModule'
      )
    end
    let(:errors) { ['unknown module name: InvalidModule'] }
    let(:corrected_content) do
      { 'triplets' => [{ 'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
                         'relationship' => 'Maintenance',
                         'object' => { 'type' => 'CoreModule', 'name' => 'String' },
                         'evidence' => 'matz committed to String' }] }
    end

    before do
      allow(response).to receive(:content).and_return(corrected_content)
    end

    it 'returns the corrected triplet' do
      result = extractor.correct(triplet, errors, job_arguments)

      expect(result.subject.name).to eq('matz')
      expect(result.object.name).to eq('String')
    end

    context 'when ResponseParser returns empty array' do
      let(:corrected_content) { { 'triplets' => [] } }

      it 'returns nil' do
        expect(extractor.correct(triplet, errors, job_arguments)).to be_nil
      end
    end

    context 'when LLM API fails' do
      before do
        allow(chat).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'API error'))
      end

      it 'raises ExtractionError' do
        expect do
          extractor.correct(triplet, errors, job_arguments)
        end.to raise_error(Analysis::Entities::ExtractionError, 'API error')
      end
    end
  end
end
