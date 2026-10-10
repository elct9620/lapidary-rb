# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Searches for existing nodes in the knowledge graph by name.
      # Lets the LLM verify Rubyist usernames or module names.
      class SearchNodeTool < BaseSearchTool
        def self.tool_name = 'search_node'

        description 'Search for existing nodes in the knowledge graph by name or display name. ' \
                    'Use this to verify if a Rubyist username, display name, or module name already exists.'

        parameter :query, description: 'Name or partial name to search for'
        parameter :type, description: 'Node type filter: Rubyist, CoreModule, or Stdlib', required: false

        def execute(query:, type: nil)
          dataset = @database[:nodes]
          dataset = dataset.where(type: type.to_s) if type
          pattern = like_pattern(query)
          results = dataset.where(
            Sequel.ilike(:id, pattern) | Sequel.ilike(:data, pattern)
          ).limit(10).select(:id, :type, :data).all
          results.map { |row| { id: row[:id], type: row[:type], data: row[:data] } }.to_json
        end
      end
    end
  end
end
