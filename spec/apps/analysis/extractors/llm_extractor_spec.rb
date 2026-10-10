# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::LlmExtractor do
  subject(:extractor) { described_class.new(llm: llm, logger: logger, tools: tools) }

  let(:llm) { RubyLLM.context { |config| config.openai_api_key = 'test-key' } }
  let(:logger) { Lapidary::Container['logger'] }
  let(:tools) { [] }
  let(:responses_url) { 'https://api.openai.com/v1/responses' }
  let(:extracted) do
    { 'triplets' => [{ 'reasoning' => '(1) Y (2) Y',
                       'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
                       'relationship' => 'Maintenance',
                       'object' => { 'type' => 'CoreModule', 'name' => 'String' },
                       'evidence' => 'matz committed to String' }] }
  end

  def message_response(content)
    response_body(
      [{ type: 'message', id: 'msg_1', role: 'assistant', status: 'completed',
         content: [{ type: 'output_text', text: JSON.generate(content), annotations: [] }] }]
    )
  end

  def function_call_response(name, arguments)
    response_body(
      [{ type: 'function_call', id: 'fc_1', call_id: 'call_1', name: name,
         arguments: JSON.generate(arguments), status: 'completed' }]
    )
  end

  def response_body(output)
    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: JSON.generate(id: 'resp_1', object: 'response', status: 'completed', model: 'gpt-6-luna',
                          output: output, usage: { input_tokens: 10, output_tokens: 5, total_tokens: 15 })
    }
  end

  describe '#call' do
    let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 12_345) }

    before { stub_request(:post, responses_url).to_return(message_response(extracted)) }

    it 'returns parsed triplets from the LLM structured output' do
      result = extractor.call(job_arguments)

      expect(result.map { |t| [t.subject.name, t.relationship, t.object.name] })
        .to eq([['matz', Analysis::Entities::RelationshipType::MAINTENANCE, 'String']])
    end

    it 'requests the triplet schema as structured output' do
      extractor.call(job_arguments)

      expect(a_request(:post, responses_url).with do |request|
        JSON.parse(request.body).dig('text', 'format', 'type') == 'json_schema'
      end).to have_been_made
    end

    context 'with a reasoning effort' do
      subject(:extractor) { described_class.new(llm: llm, logger: logger, reasoning_effort: 'high') }

      it 'requests that reasoning effort' do
        extractor.call(job_arguments)

        expect(a_request(:post, responses_url).with do |request|
          JSON.parse(request.body)['reasoning'] == { 'effort' => 'high' }
        end).to have_been_made
      end
    end

    context 'when the LLM calls a tool before answering' do
      let(:tools) { [Analysis::Extractors::Tools::ValidateModuleTool.new] }

      before do
        stub_request(:post, responses_url)
          .to_return(function_call_response('validate_module', { name: 'String' }))
          .then.to_return(message_response(extracted))
      end

      it 'returns the triplets from the answer that follows the tool result' do
        expect(extractor.call(job_arguments).map { |t| t.object.name }).to eq(['String'])
      end

      it 'sends the tool result back to the LLM' do
        extractor.call(job_arguments)

        expect(a_request(:post, responses_url).with do |request|
          JSON.parse(request.body)['input'].any? do |item|
            item['type'] == 'function_call_output' && JSON.parse(item['output'])['valid'] == true
          end
        end).to have_been_made
      end
    end

    context 'when the LLM output is not valid JSON' do
      before do
        stub_request(:post, responses_url).to_return(
          response_body([{ type: 'message', id: 'msg_1', role: 'assistant', status: 'completed',
                           content: [{ type: 'output_text', text: '{"triplets": [', annotations: [] }] }])
        )
      end

      it 'returns no triplets' do
        expect(extractor.call(job_arguments)).to eq([])
      end
    end

    context 'when LLM API fails' do
      before do
        stub_request(:post, responses_url).to_return(
          status: 400, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate(error: { message: 'API connection failed' })
        )
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
    let(:corrected) { extracted }

    before { stub_request(:post, responses_url).to_return(message_response(corrected)) }

    it 'returns the corrected triplet' do
      result = extractor.correct(triplet, errors, job_arguments)

      expect([result.subject.name, result.object.name]).to eq(%w[matz String])
    end

    context 'when the LLM returns no triplets' do
      let(:corrected) { { 'triplets' => [] } }

      it 'returns nil' do
        expect(extractor.correct(triplet, errors, job_arguments)).to be_nil
      end
    end

    context 'when LLM API fails' do
      before do
        stub_request(:post, responses_url).to_return(
          status: 400, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate(error: { message: 'API error' })
        )
      end

      it 'raises ExtractionError' do
        expect do
          extractor.correct(triplet, errors, job_arguments)
        end.to raise_error(Analysis::Entities::ExtractionError, 'API error')
      end
    end
  end
end
