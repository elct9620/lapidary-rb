# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::LlmExtractor do
  subject(:extractor) { described_class.new(llm: llm, logger: logger, response_parser: response_parser) }

  let(:llm) { double('RubyLLM', chat: chat) }
  let(:chat) { double('RubyLLM::Chat', with_instructions: nil, with_tools: nil, with_schema: nil, ask: response) }
  let(:response) { double('RubyLLM::Message') }
  let(:logger) { instance_double(Console::Logger, warn: nil, info: nil) }
  let(:response_parser) { instance_double(Analysis::Extractors::ResponseParser) }
  let(:parsed_triplets) { [instance_double(Analysis::Entities::Triplet)] }

  before do
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_tools).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(response)
    allow(response).to receive(:content).and_return({ 'triplets' => [] })
    allow(response_parser).to receive(:call).and_return(parsed_triplets)
  end

  describe '#call' do
    let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 12_345) }

    it 'delegates parsing to ResponseParser with LLM response content' do
      extractor.call(job_arguments)

      expect(response_parser).to have_received(:call).with(response.content)
    end

    it 'returns the result from ResponseParser' do
      result = extractor.call(job_arguments)

      expect(result).to eq(parsed_triplets)
    end

    context 'with prompt building' do
      let(:prompt_builder) { instance_double(Analysis::Extractors::PromptBuilder) }
      let(:test_prompt) { Analysis::Extractors::Prompt.new(system: 'test system', user: 'test user') }

      subject(:extractor) do
        described_class.new(llm: llm, logger: logger, response_parser: response_parser, prompt_builder: prompt_builder)
      end

      before do
        allow(prompt_builder).to receive(:call).and_return(test_prompt)
      end

      it 'delegates prompt building to PromptBuilder' do
        extractor.call(job_arguments)

        expect(prompt_builder).to have_received(:call).with(job_arguments)
      end

      it 'sends the system prompt via with_instructions' do
        extractor.call(job_arguments)

        expect(chat).to have_received(:with_instructions).with('test system')
      end

      it 'sends the user prompt to ask' do
        extractor.call(job_arguments)

        expect(chat).to have_received(:ask).with('test user')
      end
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
    let(:corrected_triplet) { instance_double(Analysis::Entities::Triplet) }

    before do
      allow(response_parser).to receive(:call).and_return([corrected_triplet])
    end

    it 'delegates parsing to ResponseParser and returns the first result' do
      result = extractor.correct(triplet, errors, job_arguments)

      expect(response_parser).to have_received(:call).with(response.content)
      expect(result).to eq(corrected_triplet)
    end

    it 'delegates to PromptBuilder#correction_prompt' do
      prompt_builder = instance_double(Analysis::Extractors::PromptBuilder)
      test_prompt = Analysis::Extractors::Prompt.new(system: 'correction system', user: 'correction user')
      allow(prompt_builder).to receive(:correction_prompt).and_return(test_prompt)
      custom_extractor = described_class.new(
        llm: llm, logger: logger, response_parser: response_parser, prompt_builder: prompt_builder
      )

      custom_extractor.correct(triplet, errors, job_arguments)

      expect(prompt_builder).to have_received(:correction_prompt).with(triplet, errors, job_arguments)
    end

    context 'when ResponseParser returns empty array' do
      before do
        allow(response_parser).to receive(:call).and_return([])
      end

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
