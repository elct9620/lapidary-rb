# frozen_string_literal: true

require 'ruby_llm/schema'

module Analysis
  module Extractors
    # Structured output schema for LLM triplet extraction.
    class TripletSchema < RubyLLM::Schema
      RELATIONSHIP_MAP = Entities::RelationshipType::ALL
                         .each_with_object({}) { |r, h| h[r.to_s] = r }.freeze

      NODE_TYPE_MAP = Entities::NodeType::OBJECT_TYPES
                      .each_with_object({}) { |t, h| h[t.to_s] = t }.freeze

      array :triplets do
        object do
          object :subject do
            string :name, description: 'Username on bugs.ruby-lang.org'
            boolean :is_committer, description: 'Whether this person is a known Ruby committer'
          end
          string :relationship, enum: RELATIONSHIP_MAP.keys
          object :object do
            string :type, enum: NODE_TYPE_MAP.keys
            string :name, description: 'Canonical module name'
          end
          string :evidence, description: 'Brief rationale for this triplet extracted from the source text'
        end
      end
    end
  end
end
