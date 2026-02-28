# frozen_string_literal: true

module Analysis
  module Extractors
    # Assembles the LLM prompt for triplet extraction from issue/journal content.
    class PromptBuilder
      def call(job_arguments)
        Prompt.new(
          system: system_prompt,
          user: user_prompt(job_arguments)
        )
      end

      private

      def system_prompt
        <<~PROMPT
          #{system_instructions}

          #{ontology_section}

          #{module_list_section}

          #{extraction_rules}

          #{rubric_section}
        PROMPT
      end

      def user_prompt(job_arguments)
        <<~PROMPT
          #{job_arguments.entity_type.capitalize} ##{job_arguments.entity_id}
          Author: #{job_arguments.author_username} (#{job_arguments.author_display_name})

          #{job_arguments.content}
          #{journal_context(job_arguments)}
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
          #{Ontology::ModuleRegistry.core_module_names.join(', ')}

          ### Standard Libraries
          #{Ontology::ModuleRegistry.stdlib_names.join(', ')}
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
          - Use "Maintenance" for people with maintenance activities (commits, merges, backports, assigns)
          - Use "Contribute" for people who contribute implementation (patches, pull requests, concrete code fixes)
          - Do not extract relationships for people who only report bugs, discuss, or confirm/reproduce issues
          - Module names must exactly match one of the valid names listed above
          - Set is_committer to true only when the text explicitly mentions committer identity (e.g., "committed rNNNN", listed as committer, has explicit trunk commit records)
          - If no clear relationships can be identified, return an empty triplets array
        TEXT
      end

      RUBRIC_TABLE = <<~TEXT.chomp
        ## Extraction Rubric

        | Signal in Text | Relationship | is_committer |
        |---|---|---|
        | Committed rNNNN, backported to branch | Maintenance | depends on text |
        | Assigned as maintainer, merged into trunk | Maintenance | depends on text |
        | Submitted patch with implementation | Contribute | false |
        | Proposed PR or code fix for review | Contribute | false |
        | Code review with concrete fix suggestion | Contribute | false |
        | Only reports bug or describes unexpected behavior | Do not extract | - |
        | Only discusses or proposes without implementation | Do not extract | - |
        | Confirms or reproduces a bug | Do not extract | - |
      TEXT
      private_constant :RUBRIC_TABLE

      def rubric_section
        RUBRIC_TABLE
      end
    end
  end
end
