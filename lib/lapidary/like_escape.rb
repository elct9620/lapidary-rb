# frozen_string_literal: true

module Lapidary
  # Escapes SQL LIKE wildcard characters for safe pattern matching.
  module LikeEscape
    private

    def escape_like(value)
      value.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
    end
  end
end
