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
        errors = []
        validate_subject_type(triplet, errors)
        validate_object_type(triplet, errors)
        validate_relationship(triplet, errors)
        validate_committer_constraint(triplet, errors)
        validate_module_name(triplet, errors)
        ValidationResult.new(triplet: triplet, errors: errors)
      end

      private

      def validate_subject_type(triplet, errors)
        return if VALID_SUBJECT_TYPES.include?(triplet.subject.type)

        errors << "subject type must be Rubyist, got #{triplet.subject.type}"
      end

      def validate_object_type(triplet, errors)
        return if VALID_OBJECT_TYPES.include?(triplet.object.type)

        errors << "object type must be CoreModule or Stdlib, got #{triplet.object.type}"
      end

      def validate_relationship(triplet, errors)
        return if VALID_RELATIONSHIPS.include?(triplet.relationship)

        errors << "relationship must be Maintenance or Contribute, got #{triplet.relationship}"
      end

      def validate_committer_constraint(triplet, errors)
        return unless triplet.relationship == Entities::RelationshipType::MAINTENANCE
        return if triplet.subject.properties[:is_committer]

        errors << 'Maintenance relationship requires subject to be a committer'
      end

      def validate_module_name(triplet, errors)
        return unless VALID_OBJECT_TYPES.include?(triplet.object.type)
        return if ModuleRegistry.valid?(triplet.object.name)

        errors << "unknown module name: #{triplet.object.name}"
      end
    end
  end
end
