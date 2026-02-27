# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the type of an entity being tracked.
    EntityType = Data.define(:value) do
      def to_s
        value
      end
    end

    class EntityType # :nodoc:
      ISSUE = new(value: 'issue')
      JOURNAL = new(value: 'journal')

      ALL = [ISSUE, JOURNAL].freeze

      def self.parse(value)
        ALL.find { |t| t.value == value } || raise(ArgumentError, "unknown entity type: #{value}")
      end
    end
  end
end
