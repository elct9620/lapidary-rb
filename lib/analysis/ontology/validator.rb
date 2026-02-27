# auto_register: false
# frozen_string_literal: true

module Analysis
  module Ontology
    # Validates triplets against the ontology entailment rules.
    class Validator
      ValidationResult = Data.define(:triplet, :errors, :downgrades) do
        def initialize(triplet:, errors:, downgrades: [])
          super
        end
      end

      VALID_SUBJECT_TYPES = Entities::NodeType::SUBJECT_TYPES
      VALID_OBJECT_TYPES = Entities::NodeType::OBJECT_TYPES
      VALID_RELATIONSHIPS = Entities::RelationshipType::ALL

      ConstraintResult = Data.define(:triplet, :downgrade)

      def call(triplet)
        errors = [
          validate_subject_type(triplet),
          validate_object_type(triplet),
          validate_relationship(triplet)
        ].compact

        constraint = check_committer_constraint(triplet)
        triplet = constraint.triplet
        downgrades = [constraint.downgrade].compact

        errors << validate_module_name(triplet)
        ValidationResult.new(triplet: triplet, errors: errors.compact, downgrades: downgrades)
      end

      private

      def validate_subject_type(triplet)
        return if VALID_SUBJECT_TYPES.include?(triplet.subject.type)

        "subject type must be Rubyist, got #{triplet.subject.type}"
      end

      def validate_object_type(triplet)
        return if VALID_OBJECT_TYPES.include?(triplet.object.type)

        "object type must be CoreModule or Stdlib, got #{triplet.object.type}"
      end

      def validate_relationship(triplet)
        return if VALID_RELATIONSHIPS.include?(triplet.relationship)

        "relationship must be Maintenance or Contribute, got #{triplet.relationship}"
      end

      def check_committer_constraint(triplet)
        unless triplet.relationship == Entities::RelationshipType::MAINTENANCE
          return ConstraintResult.new(triplet: triplet, downgrade: nil)
        end
        return ConstraintResult.new(triplet: triplet, downgrade: nil) if triplet.subject.properties[:is_committer]

        ConstraintResult.new(
          triplet: triplet.with(relationship: Entities::RelationshipType::CONTRIBUTE),
          downgrade: 'Maintenance downgraded to Contribute: subject is not a committer'
        )
      end

      def validate_module_name(triplet)
        return unless VALID_OBJECT_TYPES.include?(triplet.object.type)
        return if ModuleRegistry.valid?(triplet.object.name)

        "unknown module name: #{triplet.object.name}"
      end
    end
  end
end
