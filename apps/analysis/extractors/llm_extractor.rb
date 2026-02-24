# frozen_string_literal: true

require 'ruby_llm/schema'

module Analysis
  module Extractors
    # Extracts knowledge graph triplets from issue/journal content using LLM structured output.
    # Duck typing contract: #call(job_arguments) -> [Triplet]
    class LlmExtractor
      include Lapidary::Dependency['llm']

      RELATIONSHIP_MAP = {
        'Maintenance' => Entities::RelationshipType::MAINTENANCE,
        'Contribute' => Entities::RelationshipType::CONTRIBUTE
      }.freeze

      NODE_TYPE_MAP = {
        'CoreModule' => Entities::NodeType::CORE_MODULE,
        'Stdlib' => Entities::NodeType::STDLIB
      }.freeze

      # Structured output schema for LLM triplet extraction.
      class TripletSchema < RubyLLM::Schema
        array :triplets do
          object do
            object :subject do
              string :name, description: 'Username on bugs.ruby-lang.org'
              boolean :is_committer, description: 'Whether this person is a known Ruby committer'
            end
            string :relationship, enum: %w[Maintenance Contribute]
            object :object do
              string :type, enum: %w[CoreModule Stdlib]
              string :name, description: 'Canonical module name'
            end
          end
        end
      end

      def call(job_arguments)
        response = llm.chat.with_schema(TripletSchema).ask(build_prompt(job_arguments))
        parse_response(response.content)
      end

      private

      def parse_response(content)
        return [] unless content.is_a?(Hash)

        raw_triplets = content['triplets']
        return [] unless raw_triplets.is_a?(Array)

        raw_triplets.filter_map { |raw| build_triplet(raw) }
      end

      def build_triplet(raw)
        return nil unless complete_triplet?(raw)

        Entities::Triplet.new(
          subject: build_subject(raw['subject']),
          relationship: RELATIONSHIP_MAP.fetch(raw['relationship']),
          object: build_object(raw['object'])
        )
      end

      def complete_triplet?(raw)
        return false unless raw.is_a?(Hash)

        raw['subject'].is_a?(Hash) &&
          raw['relationship'].is_a?(String) &&
          raw['object'].is_a?(Hash)
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
          type: NODE_TYPE_MAP.fetch(raw['type']),
          name: raw['name']
        )
      end

      def build_prompt(job_arguments)
        <<~PROMPT
          #{system_instructions}

          #{ontology_section}

          #{module_list_section}

          #{extraction_rules}

          ## Content

          #{job_arguments[:entity_type].capitalize} ##{job_arguments[:entity_id]}
        PROMPT
      end

      def system_instructions
        <<~TEXT.chomp
          You are a knowledge graph extraction assistant for the Ruby programming language community.
          Analyze the following content from bugs.ruby-lang.org and extract relationships between people and Ruby modules.
        TEXT
      end

      def ontology_section
        <<~TEXT.chomp
          ## Ontology

          ### Node Types
          - Rubyist: A person who contributes to or maintains Ruby modules
          - CoreModule: A core Ruby module (part of the Ruby language itself)
          - Stdlib: A Ruby standard library module

          ### Relationship Types
          - Maintenance: A Rubyist who actively maintains a module (must be a known Ruby committer)
          - Contribute: A Rubyist who contributes to a module (bug reports, patches, discussions)
        TEXT
      end

      def module_list_section
        <<~TEXT.chomp
          ## Valid Module Names

          ### Core Modules
          #{Ontology::ModuleRegistry::CORE_MODULES.to_a.sort.join(', ')}

          ### Standard Libraries
          #{Ontology::ModuleRegistry::STDLIBS.to_a.sort.join(', ')}
        TEXT
      end

      def extraction_rules
        <<~TEXT.chomp
          ## Extraction Rules
          - Only extract relationships where a person is clearly associated with a specific module
          - Use "Maintenance" only for known Ruby committers who maintain the module
          - Use "Contribute" for anyone who reports bugs, submits patches, or discusses a module
          - Module names must exactly match one of the valid names listed above
          - If no clear relationships can be identified, return an empty triplets array
        TEXT
      end
    end
  end
end
