# frozen_string_literal: true

module Analysis
  module Extractors
    # Extracts knowledge graph triplets from issue/journal content using LLM structured output.
    # Duck typing contract: #call(job_arguments) -> [Triplet]
    class LlmExtractor
      include Lapidary::Dependency['llm', 'logger']
      include SentryLlmSpan

      def initialize(prompt_builder: PromptBuilder.new, tools: [], **deps)
        super(**deps)
        @prompt_builder = prompt_builder
        @tools = tools
      end

      def call(job_arguments)
        prompt = @prompt_builder.call(job_arguments)
        parse_response(chat_with_schema(prompt).content)
      rescue RubyLLM::Error => e
        raise Entities::ExtractionError, e.message
      end

      def correct(triplet, errors, job_arguments)
        prompt = @prompt_builder.correction_prompt(triplet, errors, job_arguments)
        parse_response(chat_with_schema(prompt).content).first
      rescue RubyLLM::Error => e
        raise Entities::ExtractionError, e.message
      end

      private

      def chat_with_schema(prompt)
        ::Sentry.with_child_span(op: 'gen_ai.chat', description: "chat #{model_name}") do |span|
          chat = llm.chat.with_instructions(prompt.system).with_tools(*@tools).with_schema(TripletSchema)
          result = chat.ask(prompt.user)
          record_llm_span(span, prompt, result)
          result
        end
      end

      def model_name
        Lapidary.config.openai.model
      end

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
        Entities::Triplet.new(
          subject: build_subject(raw['subject']),
          relationship: TripletSchema::RELATIONSHIP_MAP.fetch(raw['relationship']) do
            raise Entities::ExtractionError, "unknown relationship: #{raw['relationship']}"
          end,
          object: build_object(raw['object']),
          evidence: raw['evidence']
        )
      rescue TypeError, NoMethodError => e
        warn_malformed_triplet(e)
      end

      def warn_malformed_triplet(error)
        logger.warn(self, "Skipping malformed triplet: #{error.class}: #{error.message}")
      end

      def build_subject(raw)
        Entities::Node.new(
          type: Entities::NodeType::RUBYIST,
          name: raw['name'].to_str,
          properties: { role: raw['role'] || 'contributor' }
        )
      end

      def build_object(raw)
        Entities::Node.new(
          type: TripletSchema::NODE_TYPE_MAP.fetch(raw['type']) do
            raise Entities::ExtractionError, "unknown node type: #{raw['type']}"
          end,
          name: raw['name'].to_str
        )
      end
    end
  end
end
