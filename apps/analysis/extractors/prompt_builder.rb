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

      def correction_prompt(triplet, errors, job_arguments)
        Prompt.new(
          system: "#{CORRECTION_INSTRUCTIONS}\n\n#{ontology_section}\n\n#{module_list_section}\n",
          user: correction_user_prompt(triplet, errors, job_arguments)
        )
      end

      private

      def system_prompt
        <<~PROMPT
          #{SYSTEM_INSTRUCTIONS}

          #{ontology_section}

          #{module_list_section}

          #{EXTRACTION_RULES}

          #{EVALUATION_STEPS}

          #{RUBRIC_TABLE}
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

      SYSTEM_INSTRUCTIONS = <<~TEXT.chomp
        You are a knowledge graph extraction assistant for the Ruby programming language community.
        Analyze the following content from bugs.ruby-lang.org and extract relationships between people and Ruby modules.
      TEXT
      private_constant :SYSTEM_INSTRUCTIONS

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

      CORRECTION_INSTRUCTIONS = <<~TEXT.chomp
        You are a knowledge graph extraction assistant for the Ruby programming language community.
        A previously extracted triplet failed validation. Analyze the errors and correct the triplet so it conforms to the ontology rules.
        Return a single corrected triplet. If the triplet cannot be corrected, return an empty triplets array.
      TEXT
      private_constant :CORRECTION_INSTRUCTIONS

      def correction_user_prompt(triplet, errors, job_arguments)
        <<~PROMPT
          ## Original Context
          #{user_prompt(job_arguments)}

          ## Failed Triplet
          - Subject: #{triplet.subject.name} (#{triplet.subject.type}, role: #{triplet.subject.properties[:role]})
          - Relationship: #{triplet.relationship}
          - Object: #{triplet.object.name} (#{triplet.object.type})
          - Evidence: #{triplet.evidence}

          ## Validation Errors
          #{errors.map { |e| "- #{e}" }.join("\n")}
        PROMPT
      end
    end
  end
end
