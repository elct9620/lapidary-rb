# frozen_string_literal: true

module Analysis
  module Extractors
    # Assembles the LLM prompt for triplet extraction from issue/journal content.
    class PromptBuilder
      def call(job_arguments)
        <<~PROMPT
          #{system_instructions}

          #{ontology_section}

          #{module_list_section}

          #{extraction_rules}

          ## Content

          #{job_arguments.entity_type.capitalize} ##{job_arguments.entity_id}
          Author: #{job_arguments.author_username} (#{job_arguments.author_display_name})

          #{job_arguments.content}
          #{journal_context(job_arguments)}
        PROMPT
      end

      private

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
          #{format_descriptions(Analysis::Entities::NodeType::DESCRIPTIONS)}

          ### Relationship Types
          #{format_descriptions(Analysis::Entities::RelationshipType::DESCRIPTIONS)}
        TEXT
      end

      def format_descriptions(descriptions)
        descriptions.map { |type, desc| "- #{type}: #{desc}" }.join("\n")
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

      def journal_context(job_arguments)
        return '' unless job_arguments.entity_type == Analysis::Entities::EntityType::JOURNAL.to_s

        <<~TEXT.chomp
          Issue ##{job_arguments.issue_id}: #{job_arguments.issue_content}
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
