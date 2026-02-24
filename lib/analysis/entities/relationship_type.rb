# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the type of a knowledge graph relationship.
    RelationshipType = Data.define(:value) do
      def to_s
        value
      end
    end

    class RelationshipType
      MAINTENANCE = new(value: 'Maintenance')
      CONTRIBUTE = new(value: 'Contribute')
    end
  end
end
