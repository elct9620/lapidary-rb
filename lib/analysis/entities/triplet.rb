# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing a knowledge graph triplet (subject, relationship, object).
    Triplet = Data.define(:subject, :relationship, :object, :evidence) do
      def initialize(subject:, relationship:, object:, evidence: nil)
        super
      end
    end
  end
end
