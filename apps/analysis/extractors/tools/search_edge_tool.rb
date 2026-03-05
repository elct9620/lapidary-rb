# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Searches for existing edges (relationships) in the knowledge graph.
      # Lets the LLM check if a relationship between a Rubyist and a module already exists.
      class SearchEdgeTool < RubyLLM::Tool
        description 'Search for existing edges (relationships) in the knowledge graph. ' \
                    'Use this to check if a relationship between a Rubyist and a module already exists.'

        param :source_name, desc: 'Source node name or partial name to search for'
        param :target_name, desc: 'Target node name or partial name to search for'

        include LikeEscape

        def initialize(database)
          super()
          @database = database
        end

        def execute(source_name:, target_name:)
          source_pattern = "%#{escape_like(source_name)}%"
          target_pattern = "%#{escape_like(target_name)}%"
          results = @database[:edges]
                    .where(Sequel.ilike(:source, source_pattern))
                    .where(Sequel.ilike(:target, target_pattern))
                    .where(archived_at: nil)
                    .limit(10)
                    .select(:source, :target, :relationship)
                    .all
          results.map { |row| { source: row[:source], target: row[:target], relationship: row[:relationship] } }.to_json
        end
      end
    end
  end
end
