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

          #{evaluation_steps}

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

      EXTRACTION_RULES = <<~TEXT.chomp
        ## Extraction Rules
        - Only extract relationships where a person is clearly associated with a specific module
        - Use "Maintenance" for people with maintenance activities (commits, merges, backports, assigns)
        - Use "Contribute" for people who contribute implementation (patches, pull requests, concrete code fixes)
        - Do not extract relationships for people who only report bugs, discuss, or confirm/reproduce issues
        - Module names must exactly match one of the valid names listed above
        - Set role to "maintainer" when the person is identified as a module maintainer (assigned responsibility, explicitly listed as maintainer, regularly commits/merges for the module). Set role to "submaintainer" when the person contributes bug fixes or patches without full maintenance authority. Default to "contributor" otherwise.
        - If no clear relationships can be identified, return an empty triplets array
        - The "reasoning" field: record your Y/N evaluation for each step before filling other fields
        - The "evidence" field: cite the specific text passage that supports the triplet
      TEXT
      private_constant :EXTRACTION_RULES

      def extraction_rules
        EXTRACTION_RULES
      end

      EVALUATION_STEPS = <<~TEXT.chomp
        ## Evaluation Steps

        For each person mentioned in the text, evaluate step by step:

        1. Does this person perform a specific action on a named Ruby module? (Y/N)
           → If N: skip this person entirely
        2. Is the action a maintenance activity — commit, merge, backport, or assign? (Y/N)
           → If Y: relationship = Maintenance
        3. Is the action an implementation contribution — patch, PR, or concrete code fix? (Y/N)
           → If Y: relationship = Contribute
        4. If neither Step 2 nor Step 3: Do not extract a triplet for this person
        5. Is this person identified as a maintainer of this module
           (assigned responsibility, regularly commits/merges, listed as maintainer)? (Y/N)
           → If Y: role = maintainer. If N but contributes patches: role = submaintainer. Otherwise: role = contributor.

        Record your step-by-step reasoning in the "reasoning" field before filling in the other fields.
      TEXT
      private_constant :EVALUATION_STEPS

      def evaluation_steps
        EVALUATION_STEPS
      end

      RUBRIC_TABLE = <<~TEXT.chomp
        ## Extraction Rubric

        For each candidate triplet, verify:

        | Question | Y → Action | N → Action |
        |---|---|---|
        | Does this person act on a specific named module? | Continue | Do not extract |
        | Is the action: commit, merge, backport, or assign? | Maintenance | Check next |
        | Is the action: submit patch, PR, or code fix? | Contribute | Do not extract |
        | Is this person identified as a module maintainer? | role = maintainer | role = submaintainer or contributor |

        ### Do NOT extract when:
        - Person only reports a bug or describes unexpected behavior
        - Person only discusses, proposes, or asks questions without implementation
        - Person only confirms or reproduces a bug
      TEXT
      private_constant :RUBRIC_TABLE

      def rubric_section
        RUBRIC_TABLE
      end
    end
  end
end
