# auto_register: false
# frozen_string_literal: true

module Analysis
  module Ontology
    # Validates triplets against the ontology entailment rules.
    class Validator
      ValidationResult = Data.define(:triplet, :errors)

      VALID_SUBJECT_TYPES = Entities::NodeType::SUBJECT_TYPES
      VALID_OBJECT_TYPES = Entities::NodeType::OBJECT_TYPES
      VALID_RELATIONSHIPS = Entities::RelationshipType::ALL
      ANONYMOUS_NAMES = %w[Anonymous].freeze
      NON_HUMAN_PATTERNS = [
        /\bclaude\s+(opus|sonnet|haiku)\b/i,
        /\bgpt[-\s]*\d/i,
        /\bcopilot\b/i
      ].freeze

      VALIDATIONS = %i[
        validate_subject_type
        validate_anonymous_subject
        validate_non_human_subject
        validate_subject_name_whitespace
        validate_subject_name
        validate_object_type
        validate_relationship
        validate_role_constraint
        validate_object_name_whitespace
        validate_module_name
      ].freeze

      def call(triplet)
        errors = VALIDATIONS.filter_map { |validation| send(validation, triplet) }

        ValidationResult.new(triplet: triplet, errors: errors)
      end

      private

      def validate_subject_type(triplet)
        return if VALID_SUBJECT_TYPES.include?(triplet.subject.type)

        "subject type must be Rubyist, got #{triplet.subject.type}"
      end

      def validate_anonymous_subject(triplet)
        return unless VALID_SUBJECT_TYPES.include?(triplet.subject.type)
        return unless ANONYMOUS_NAMES.include?(triplet.subject.name)

        "subject name is a reserved anonymous identifier: #{triplet.subject.name}"
      end

      def validate_subject_name(triplet)
        return unless VALID_SUBJECT_TYPES.include?(triplet.subject.type)
        return unless triplet.subject.name.match?(/\(.*\)/)

        "subject name contains parenthetical annotation: #{triplet.subject.name}"
      end

      def validate_object_type(triplet)
        return if VALID_OBJECT_TYPES.include?(triplet.object.type)

        "object type must be CoreModule or Stdlib, got #{triplet.object.type}"
      end

      def validate_relationship(triplet)
        return if VALID_RELATIONSHIPS.include?(triplet.relationship)

        "relationship must be Maintenance or Contribute, got #{triplet.relationship}"
      end

      def validate_role_constraint(triplet)
        return unless triplet.relationship == Entities::RelationshipType::MAINTENANCE
        return if triplet.subject.properties[:role] == 'maintainer'

        "Maintenance relationship requires role=maintainer, got role=#{triplet.subject.properties[:role]}"
      end

      def validate_non_human_subject(triplet)
        return unless VALID_SUBJECT_TYPES.include?(triplet.subject.type)
        return unless NON_HUMAN_PATTERNS.any? { |pattern| triplet.subject.name.match?(pattern) }

        "subject name matches a known non-human agent: #{triplet.subject.name}"
      end

      def validate_subject_name_whitespace(triplet)
        return unless VALID_SUBJECT_TYPES.include?(triplet.subject.type)
        return unless triplet.subject.name.match?(/\s/)

        "subject name contains whitespace: #{triplet.subject.name}"
      end

      def validate_object_name_whitespace(triplet)
        return unless VALID_OBJECT_TYPES.include?(triplet.object.type)
        return unless triplet.object.name.match?(/\s/)

        "object name contains whitespace: #{triplet.object.name}"
      end

      def validate_module_name(triplet)
        return unless VALID_OBJECT_TYPES.include?(triplet.object.type)
        return if ModuleRegistry.valid?(triplet.object.name)

        "unknown module name: #{triplet.object.name}"
      end
    end
  end
end
