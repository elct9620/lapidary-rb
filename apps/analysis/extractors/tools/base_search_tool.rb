# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Shared base for search tools that query the knowledge graph.
      class BaseSearchTool < RubyLLM::Tool
        include Lapidary::LikeEscape

        def initialize(database)
          super()
          @database = database
        end

        private

        def like_pattern(value)
          "%#{escape_like(value)}%"
        end
      end
    end
  end
end
