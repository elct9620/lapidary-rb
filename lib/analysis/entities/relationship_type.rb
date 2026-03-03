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

      ALL = [MAINTENANCE, CONTRIBUTE].freeze

      DESCRIPTIONS = {
        MAINTENANCE => 'A Rubyist who actively maintains a module (commits, merges, backports, or assigns issues). ' \
                       'Domain: Rubyist (role = maintainer). Range: CoreModule or Stdlib.',
        CONTRIBUTE => 'A Rubyist who contributes implementation to a module ' \
                      '(submits patches, pull requests, or concrete code fixes). ' \
                      'Domain: Rubyist (any role). Range: CoreModule or Stdlib.'
      }.freeze
    end
  end
end
