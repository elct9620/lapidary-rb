# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/sentry/ruby_llm_patch'

RSpec.describe Lapidary::Sentry::RubyLlmPatch do
  let(:model) { double('Model', id: 'gpt-5-mini', provider: 'openai') }

  let(:response) do
    double('Response',
           role: :assistant,
           content: 'Hello!',
           model_id: 'gpt-5-mini',
           input_tokens: 100,
           output_tokens: 50,
           tool_calls: nil,
           tool_call_id: nil)
  end

  let(:system_message) do
    double('SystemMessage', role: :system, content: 'You are helpful.', tool_calls: nil, tool_call_id: nil)
  end

  let(:user_message) do
    double('UserMessage', role: :user, content: 'hello', tool_calls: nil, tool_call_id: nil)
  end

  let(:host_class) do
    Class.new do
      attr_reader :model
      attr_accessor :messages, :temperature

      def initialize(model:)
        @model = model
        @messages = []
        @temperature = nil
      end

      def ask(...)
        @messages << @pending_response
        @pending_response
      end

      def prepare_response(resp)
        @pending_response = resp
      end

      def execute_tool(_tool_call)
        'tool result'
      end
    end
  end

  let(:patched_class) do
    klass = host_class
    klass.prepend(described_class)
    klass
  end

  let(:instance) do
    obj = patched_class.new(model: model)
    obj.messages = [system_message, user_message]
    obj.prepare_response(response)
    obj
  end

  context 'when Sentry is not initialized' do
    before do
      allow(Sentry).to receive(:initialized?).and_return(false)
      allow(Sentry).to receive(:with_child_span)
    end

    it 'delegates to the original method without instrumentation' do
      expect(instance.ask('hello')).to eq(response)
      expect(Sentry).not_to have_received(:with_child_span)
    end
  end

  context 'when Sentry is initialized' do
    let(:span) { double('Span') }

    before do
      allow(Sentry).to receive(:initialized?).and_return(true)
      allow(Sentry).to receive(:with_child_span).and_yield(span)
      allow(span).to receive(:set_data)
    end

    it 'wraps the call in a gen_ai.chat span' do
      expect(instance.ask('hello')).to eq(response)

      expect(Sentry).to have_received(:with_child_span).with(
        op: 'gen_ai.chat',
        description: 'chat gpt-5-mini',
        origin: 'auto.ai.ruby_llm'
      )
    end

    it 'records base attributes' do
      instance.ask('hello')

      expect(span).to have_received(:set_data).with('gen_ai.operation.name', 'chat')
      expect(span).to have_received(:set_data).with('gen_ai.system', 'openai')
      expect(span).to have_received(:set_data).with('gen_ai.request.model', 'gpt-5-mini')
    end

    it 'records response attributes' do
      instance.ask('hello')

      expect(span).to have_received(:set_data).with('gen_ai.response.model', 'gpt-5-mini')
      expect(span).to have_received(:set_data).with('gen_ai.usage.input_tokens', 100)
      expect(span).to have_received(:set_data).with('gen_ai.usage.output_tokens', 50)
    end

    context 'with temperature' do
      before { instance.temperature = 0.7 }

      it 'records the temperature' do
        instance.ask('hello')

        expect(span).to have_received(:set_data).with('gen_ai.request.temperature', 0.7)
      end
    end

    context 'without temperature' do
      it 'does not record temperature' do
        instance.ask('hello')

        expect(span).not_to have_received(:set_data).with('gen_ai.request.temperature', anything)
      end
    end

    context 'when span is nil' do
      before do
        allow(Sentry).to receive(:with_child_span).and_yield(nil)
      end

      it 'still returns the result without recording' do
        expect(instance.ask('hello')).to eq(response)
      end
    end

    context 'when send_default_pii is enabled' do
      let(:sentry_config) { double('SentryConfig', send_default_pii: true) }

      before do
        allow(Sentry).to receive(:configuration).and_return(sentry_config)
      end

      it 'records system instructions' do
        instance.ask('hello')

        expect(span).to have_received(:set_data).with(
          'gen_ai.system_instructions',
          JSON.generate([{ type: 'text', content: 'You are helpful.' }])
        )
      end

      it 'records input messages' do
        instance.ask('hello')

        expect(span).to have_received(:set_data).with(
          'gen_ai.input.messages',
          JSON.generate([{ role: 'user', parts: [{ type: 'text', content: 'hello' }] }])
        )
      end

      it 'records output messages' do
        instance.ask('hello')

        expect(span).to have_received(:set_data).with(
          'gen_ai.output.messages',
          JSON.generate([{ role: 'assistant', parts: [{ type: 'text', content: 'Hello!' }] }])
        )
      end
    end

    context 'when send_default_pii is disabled' do
      let(:sentry_config) { double('SentryConfig', send_default_pii: false) }

      before do
        allow(Sentry).to receive(:configuration).and_return(sentry_config)
      end

      it 'does not record message content' do
        instance.ask('hello')

        expect(span).not_to have_received(:set_data).with('gen_ai.input.messages', anything)
        expect(span).not_to have_received(:set_data).with('gen_ai.output.messages', anything)
        expect(span).not_to have_received(:set_data).with('gen_ai.system_instructions', anything)
      end
    end
  end

  describe '#execute_tool' do
    let(:span) { double('Span') }

    let(:tool_call) do
      double('ToolCall', name: 'search', id: 'call_123', arguments: { query: 'ruby' })
    end

    before do
      allow(Sentry).to receive(:initialized?).and_return(true)
      allow(Sentry).to receive(:with_child_span).and_yield(span)
      allow(span).to receive(:set_data)
    end

    it 'wraps the call in a gen_ai.tool span' do
      instance.execute_tool(tool_call)

      expect(Sentry).to have_received(:with_child_span).with(
        op: 'gen_ai.tool',
        description: 'execute_tool search',
        origin: 'auto.ai.ruby_llm'
      )
    end

    it 'records tool attributes' do
      instance.execute_tool(tool_call)

      expect(span).to have_received(:set_data).with('gen_ai.tool.name', 'search')
      expect(span).to have_received(:set_data).with('gen_ai.tool.call.id', 'call_123')
      expect(span).to have_received(:set_data).with('gen_ai.tool.call.arguments', '{"query":"ruby"}')
      expect(span).to have_received(:set_data).with('gen_ai.tool.call.result', 'tool result')
    end

    context 'when Sentry is not initialized' do
      before do
        allow(Sentry).to receive(:initialized?).and_return(false)
      end

      it 'delegates without instrumentation' do
        expect(instance.execute_tool(tool_call)).to eq('tool result')
        expect(Sentry).not_to have_received(:with_child_span)
      end
    end
  end
end
