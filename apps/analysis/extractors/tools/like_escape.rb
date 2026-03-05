# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Escapes SQL LIKE wildcard characters for safe pattern matching.
      module LikeEscape
        private

        def escape_like(value)
          value.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
        end
      end
    end
  end
end
