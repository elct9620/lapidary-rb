# frozen_string_literal: true

module Analysis
  module Extractors
    # Extracts knowledge graph triplets from issue/journal content using LLM structured output.
    # Duck typing contract: #call(job_arguments) -> [Triplet]
    class LlmExtractor
      include Lapidary::Dependency['llm', 'logger']

      def initialize(prompt_builder: PromptBuilder.new, **deps)
        super(**deps)
        @prompt_builder = prompt_builder
      end

      def call(job_arguments)
        model_name = Lapidary.config.openai.model
        prompt = @prompt_builder.call(job_arguments)

        response = Sentry.with_child_span(op: 'gen_ai.chat', description: "chat #{model_name}") do |span|
          result = llm.chat.with_schema(TripletSchema).ask(prompt)

          if span
            span.set_data('gen_ai.operation.name', 'chat')
            span.set_data('gen_ai.system', 'openai')
            span.set_data('gen_ai.request.model', model_name)
            span.set_data('gen_ai.response.model', result.model_id)
            span.set_data('gen_ai.usage.input_tokens', result.input_tokens)
            span.set_data('gen_ai.usage.output_tokens', result.output_tokens)
            span.set_data('gen_ai.input.messages', JSON.generate([{ role: 'user', content: prompt }]))
            span.set_data('gen_ai.output.messages', JSON.generate([{ role: 'assistant', content: result.content }]))
          end

          result
        end

        parse_response(response.content)
      rescue RubyLLM::Error => e
        raise Entities::ExtractionError, e.message
      end

      private

      def parse_response(content)
        raw_triplets = extract_raw_triplets(content)
        return [] unless raw_triplets

        raw_triplets.filter_map { |raw| build_triplet(raw) }
      end

      def extract_raw_triplets(content)
        return if content.nil?
        return warn_malformed_response unless content.is_a?(Hash)

        triplets = content['triplets']
        return warn_malformed_response unless triplets.is_a?(Array)

        triplets
      end

      def warn_malformed_response
        logger.warn(self, 'LLM response malformed: expected Hash with triplets Array',
                    expected: 'Hash with triplets Array')
      end

      def build_triplet(raw)
        return nil unless complete_triplet?(raw)

        Entities::Triplet.new(
          subject: build_subject(raw['subject']),
          relationship: TripletSchema::RELATIONSHIP_MAP.fetch(raw['relationship']) do
            raise Entities::ExtractionError, "unknown relationship: #{raw['relationship']}"
          end,
          object: build_object(raw['object']),
          evidence: raw['evidence']
        )
      end

      def complete_triplet?(raw)
        return false unless raw.is_a?(Hash)

        raw['subject'].is_a?(Hash) && raw['subject']['name'].is_a?(String) &&
          raw['relationship'].is_a?(String) &&
          raw['object'].is_a?(Hash) && raw['object']['name'].is_a?(String)
      end

      def build_subject(raw)
        Entities::Node.new(
          type: Entities::NodeType::RUBYIST,
          name: raw['name'],
          properties: { is_committer: raw['is_committer'] == true }
        )
      end

      def build_object(raw)
        Entities::Node.new(
          type: TripletSchema::NODE_TYPE_MAP.fetch(raw['type']) do
            raise Entities::ExtractionError, "unknown node type: #{raw['type']}"
          end,
          name: raw['name']
        )
      end
    end
  end
end
