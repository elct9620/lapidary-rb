# auto_register: false
# frozen_string_literal: true

require 'json'

module Lapidary
  module Sentry
    # Prepend-based instrumentation for RubyLLM::Chat#ask and #execute_tool.
    # Activated conditionally in the Sentry provider.
    module RubyLlmPatch
      def ask(...)
        return super unless ::Sentry.initialized?

        ::Sentry.with_child_span(op: 'gen_ai.chat', description: "chat #{@model&.id}",
                                 origin: 'auto.ai.ruby_llm') do |span|
          result = super
          record_chat_span(span) if span
          result
        end
      end

      def execute_tool(tool_call)
        return super unless ::Sentry.initialized?

        ::Sentry.with_child_span(op: 'gen_ai.tool', description: "execute_tool #{tool_call.name}",
                                 origin: 'auto.ai.ruby_llm') do |span|
          result = super
          record_tool_span(span, tool_call, result) if span
          result
        end
      end

      private

      def record_chat_span(span)
        response = @messages&.last
        return unless response

        record_base_attributes(span)
        record_response_attributes(span, response)
        record_content(span, response) if capture_ai_content?
      end

      def record_base_attributes(span)
        span.set_data('gen_ai.operation.name', 'chat')
        span.set_data('gen_ai.system', @model&.provider.to_s)
        span.set_data('gen_ai.request.model', @model&.id)
        span.set_data('gen_ai.request.temperature', @temperature) if @temperature
      end

      def record_response_attributes(span, response)
        span.set_data('gen_ai.response.model', response.model_id)
        span.set_data('gen_ai.usage.input_tokens', response.input_tokens)
        span.set_data('gen_ai.usage.output_tokens', response.output_tokens)
      end

      def record_content(span, response)
        system_messages = @messages.select { |m| m.role == :system }
        input_messages = @messages[0..-2].reject { |m| m.role == :system }

        unless system_messages.empty?
          span.set_data('gen_ai.system_instructions',
                        JSON.generate(system_messages.map { |m| { type: 'text', content: m.content.to_s } }))
        end

        span.set_data('gen_ai.input.messages', format_messages(input_messages))
        span.set_data('gen_ai.output.messages', format_messages([response]))
      end

      def record_tool_span(span, tool_call, result)
        span.set_data('gen_ai.tool.name', tool_call.name)
        span.set_data('gen_ai.tool.call.id', tool_call.id)
        span.set_data('gen_ai.tool.call.arguments', JSON.generate(tool_call.arguments))
        result_str = result.is_a?(::RubyLLM::Tool::Halt) ? result.content.to_s : result.to_s
        span.set_data('gen_ai.tool.call.result', result_str[0..500])
      end

      def format_messages(messages)
        JSON.generate(messages.map { |m| format_message(m) })
      end

      def format_message(message)
        msg = { role: message.role.to_s, parts: message_parts(message) }
        msg[:tool_call_id] = message.tool_call_id if message.tool_call_id
        msg
      end

      def message_parts(message)
        parts = []
        parts << { type: 'text', content: message.content.to_s } if message.content
        message.tool_calls&.each_value do |tc|
          parts << { type: 'tool_call', id: tc.id, name: tc.name, arguments: tc.arguments }
        end
        parts
      end

      def capture_ai_content?
        ::Sentry.configuration.send_default_pii
      end
    end
  end
end
