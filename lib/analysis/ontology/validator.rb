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

      def call(triplet)
        errors = [
          validate_subject_type(triplet),
          validate_subject_name(triplet),
          validate_object_type(triplet),
          validate_relationship(triplet),
          validate_role_constraint(triplet),
          validate_module_name(triplet)
        ].compact

        ValidationResult.new(triplet: triplet, errors: errors)
      end

      private

      def validate_subject_type(triplet)
        return if VALID_SUBJECT_TYPES.include?(triplet.subject.type)

        "subject type must be Rubyist, got #{triplet.subject.type}"
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

      def validate_module_name(triplet)
        return unless VALID_OBJECT_TYPES.include?(triplet.object.type)
        return if ModuleRegistry.valid?(triplet.object.name)

        "unknown module name: #{triplet.object.name}"
      end
    end
  end
end
