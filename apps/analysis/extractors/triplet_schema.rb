# frozen_string_literal: true

require 'ruby_llm/schema'

module Analysis
  module Extractors
    # Structured output schema for LLM triplet extraction.
    class TripletSchema < RubyLLM::Schema
      RELATIONSHIP_MAP = Entities::RelationshipType::ALL
                         .to_h { |r| [r.to_s, r] }.freeze

      NODE_TYPE_MAP = Entities::NodeType::OBJECT_TYPES
                      .to_h { |t| [t.to_s, t] }.freeze

      array :triplets do
        object do
          string :reasoning, description: 'Step-by-step Y/N evaluation: ' \
                                          '(1) Does this person act on a specific module? ' \
                                          '(2) Is it maintenance (commit/merge/backport/assign)? ' \
                                          '(3) Is it implementation contribution (patch/PR/code fix)? ' \
                                          '(4) Is this person identified as a maintainer or submaintainer?'
          object :subject do
            string :name, description: 'Username on bugs.ruby-lang.org'
            string :role, enum: %w[maintainer submaintainer contributor],
                          description: 'Role in the Ruby community: maintainer, submaintainer, or contributor'
          end
          string :relationship, enum: RELATIONSHIP_MAP.keys
          object :object do
            string :type, enum: NODE_TYPE_MAP.keys
            string :name, description: 'Canonical module name'
          end
          string :evidence, description: 'Plain-text quote from the source that supports this triplet. ' \
                                         'Do NOT use XML tags, Markdown formatting, or any markup — plain text only.'
        end
      end
    end
  end
end
