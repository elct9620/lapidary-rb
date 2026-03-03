# frozen_string_literal: true

require 'erb'

module Analysis
  module Extractors
    # Assembles the LLM prompt for triplet extraction from issue/journal content.
    class PromptBuilder
      TEMPLATES_DIR = File.expand_path('templates', __dir__).freeze
      private_constant :TEMPLATES_DIR

      def self.load_template(name)
        ERB.new(File.read(File.join(TEMPLATES_DIR, "#{name}.erb")), trim_mode: '-')
      end
      private_class_method :load_template

      EXTRACTION_SYSTEM_TEMPLATE = load_template('extraction_system')
      EXTRACTION_USER_TEMPLATE = load_template('extraction_user')
      CORRECTION_SYSTEM_TEMPLATE = load_template('correction_system')
      CORRECTION_USER_TEMPLATE = load_template('correction_user')
      EXTRACTION_RULES = File.read(File.join(TEMPLATES_DIR, '_extraction_rules.erb')).freeze
      private_constant :EXTRACTION_SYSTEM_TEMPLATE, :EXTRACTION_USER_TEMPLATE,
                       :CORRECTION_SYSTEM_TEMPLATE, :CORRECTION_USER_TEMPLATE,
                       :EXTRACTION_RULES

      def call(job_arguments)
        Prompt.new(
          system: extraction_system_prompt,
          user: extraction_user_prompt(job_arguments)
        )
      end

      def correction_prompt(triplet, errors, job_arguments)
        Prompt.new(
          system: correction_system_prompt,
          user: correction_user_prompt(triplet, errors, job_arguments)
        )
      end

      private

      def extraction_system_prompt
        EXTRACTION_SYSTEM_TEMPLATE.result_with_hash(ontology_vars)
      end

      def extraction_user_prompt(job_arguments)
        EXTRACTION_USER_TEMPLATE.result_with_hash(
          entity_type_label: job_arguments.entity_type.capitalize,
          entity_id: job_arguments.entity_id,
          author_username: job_arguments.author_username,
          author_display_name: job_arguments.author_display_name,
          content: job_arguments.content,
          journal_context: journal_context(job_arguments)
        )
      end

      def correction_system_prompt
        CORRECTION_SYSTEM_TEMPLATE.result_with_hash(ontology_vars)
      end

      def correction_user_prompt(triplet, errors, job_arguments)
        CORRECTION_USER_TEMPLATE.result_with_hash(
          original_context: extraction_user_prompt(job_arguments),
          validation_errors: errors.map { |e| "- #{e}" }.join("\n"),
          **triplet_vars(triplet)
        )
      end

      def triplet_vars(triplet)
        {
          subject_name: triplet.subject.name,
          subject_type: triplet.subject.type,
          subject_role: triplet.subject.properties[:role],
          relationship: triplet.relationship,
          object_name: triplet.object.name,
          object_type: triplet.object.type,
          evidence: triplet.evidence
        }
      end

      def ontology_vars
        {
          node_type_descriptions: format_descriptions(Entities::NodeType::DESCRIPTIONS),
          relationship_type_descriptions: format_descriptions(Entities::RelationshipType::DESCRIPTIONS),
          core_module_names: Ontology::ModuleRegistry.core_module_names.join("\n"),
          stdlib_names: Ontology::ModuleRegistry.stdlib_names.join("\n"),
          extraction_rules: EXTRACTION_RULES
        }
      end

      def format_descriptions(descriptions)
        descriptions.map { |type, desc| "- #{type}: #{desc}" }.join("\n")
      end

      def journal_context(job_arguments)
        return '' unless job_arguments.entity_type == Entities::EntityType::JOURNAL.to_s

        "\n\n## Parent Issue\nIssue ##{job_arguments.issue_id}\n#{job_arguments.issue_content}"
      end
    end
  end
end
