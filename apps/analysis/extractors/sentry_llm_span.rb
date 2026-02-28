# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    # Sentry span recording for LLM chat operations.
    # Host class must provide a `model_name` method.
    module SentryLlmSpan
      private

      def record_llm_span(span, prompt, result)
        return unless span

        record_llm_request(span, prompt)
        record_llm_response(span, result)
      end

      def record_llm_request(span, prompt)
        span.set_data('gen_ai.operation.name', 'chat')
        span.set_data('gen_ai.system', 'openai')
        span.set_data('gen_ai.request.model', model_name)
        span.set_data('gen_ai.input.messages',
                      JSON.generate([{ role: 'system', content: prompt.system },
                                     { role: 'user', content: prompt.user }]))
      end

      def record_llm_response(span, result)
        span.set_data('gen_ai.response.model', result.model_id)
        span.set_data('gen_ai.usage.input_tokens', result.input_tokens)
        span.set_data('gen_ai.usage.output_tokens', result.output_tokens)
        span.set_data('gen_ai.output.messages', JSON.generate([{ role: 'assistant', content: result.content }]))
      end
    end
  end
end
