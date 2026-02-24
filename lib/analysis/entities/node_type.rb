# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the type of a knowledge graph node.
    NodeType = Data.define(:value) do
      def to_s
        value
      end
    end

    class NodeType
      RUBYIST = new(value: 'Rubyist')
      CORE_MODULE = new(value: 'CoreModule')
      STDLIB = new(value: 'Stdlib')

      SUBJECT_TYPES = [RUBYIST].freeze
      OBJECT_TYPES = [CORE_MODULE, STDLIB].freeze
      ALL = [RUBYIST, CORE_MODULE, STDLIB].freeze

      DESCRIPTIONS = {
        RUBYIST => 'A person who contributes to or maintains Ruby modules',
        CORE_MODULE => 'A core Ruby module (part of the Ruby language itself)',
        STDLIB => 'A Ruby standard library module'
      }.freeze
    end
  end
end
