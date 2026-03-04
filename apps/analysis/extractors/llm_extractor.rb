# frozen_string_literal: true

module Analysis
  module Extractors
    # Extracts knowledge graph triplets from issue/journal content using LLM structured output.
    # Duck typing contract: #call(job_arguments) -> [Triplet]
    class LlmExtractor
      include Lapidary::Dependency['llm', 'logger']

      def initialize(prompt_builder: PromptBuilder.new, response_parser: nil, tools: [], **deps)
        super(**deps)
        @prompt_builder = prompt_builder
        @parser = response_parser
        @tools = tools
      end

      def call(job_arguments)
        prompt = @prompt_builder.call(job_arguments)
        parser.call(chat_with_schema(prompt).content)
      rescue RubyLLM::Error => e
        raise Entities::ExtractionError, e.message
      end

      def correct(triplet, errors, job_arguments)
        prompt = @prompt_builder.correction_prompt(triplet, errors, job_arguments)
        parser.call(chat_with_schema(prompt).content).first
      rescue RubyLLM::Error => e
        raise Entities::ExtractionError, e.message
      end

      private

      def parser
        @parser ||= ResponseParser.new(logger: logger)
      end

      def chat_with_schema(prompt)
        chat = llm.chat.with_instructions(prompt.system).with_tools(*@tools).with_schema(TripletSchema)
        chat.ask(prompt.user)
      end
    end
  end
end
