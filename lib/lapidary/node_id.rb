# frozen_string_literal: true

module Lapidary
  # Shared infrastructure for building and validating knowledge graph node IDs.
  # Format: `type_slug://name` where type_slug is snake_case.
  module NodeId
    FORMAT = %r{\A[a-z_]+://\S+\z}

    def self.build(type, name)
      type_slug = type.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      "#{type_slug}://#{name}"
    end
  end
end
