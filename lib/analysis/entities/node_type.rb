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
        RUBYIST => 'A person who participates in Ruby development. Identity: username (case-sensitive). ' \
                   'Properties: username (required), display_name (optional), ' \
                   'role (maintainer | submaintainer | contributor, default: contributor).',
        CORE_MODULE => 'A core Ruby module built into the interpreter (always available without require). ' \
                       'Identity: name (case-sensitive exact match against curated list). ' \
                       'Examples: String, Array, IO, Hash, Kernel.',
        STDLIB => 'A standard library shipped with Ruby (available via require). ' \
                  'Identity: name (case-sensitive exact match against curated list). ' \
                  'Examples: net/http, json, openssl, csv.'
      }.freeze
    end
  end
end
