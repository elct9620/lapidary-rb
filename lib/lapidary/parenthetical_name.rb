# frozen_string_literal: true

module Lapidary
  # Parses names in the format "username (Display Name)" into components.
  # Shared infrastructure utility following the same convention as NodeId.
  module ParentheticalName
    PATTERN = /\A(.+?)\s*\((.+)\)\z/

    def self.parse(name)
      match = PATTERN.match(name)
      return nil unless match

      [match[1].strip, match[2].strip]
    end
  end
end
