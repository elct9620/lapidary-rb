# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Searches for existing edges (relationships) in the knowledge graph.
      # Lets the LLM check if a relationship between a Rubyist and a module already exists.
      class SearchEdgeTool < BaseSearchTool
        def self.tool_name = 'search_edge'

        description 'Search for existing edges (relationships) in the knowledge graph. ' \
                    'Use this to check if a relationship between a Rubyist and a module already exists.'

        parameter :source_name, description: 'Source node name or partial name to search for'
        parameter :target_name, description: 'Target node name or partial name to search for'

        def execute(source_name:, target_name:)
          source_pattern = like_pattern(source_name)
          target_pattern = like_pattern(target_name)
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
