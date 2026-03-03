# frozen_string_literal: true

module Lapidary
  # Value object representing the composite identity of a graph edge.
  # Replaces the recurring (source, target, relationship) triple.
  EdgeKey = Data.define(:source, :target, :relationship) do
    def to_where
      { source:, target:, relationship: }
    end

    def to_observation_where
      { edge_source: source, edge_target: target, edge_relationship: relationship }
    end

    def to_a
      [source, target, relationship]
    end

    def self.from_edge_row(row)
      new(source: row[:source], target: row[:target], relationship: row[:relationship])
    end

    def self.from_observation_row(row)
      new(source: row[:edge_source], target: row[:edge_target], relationship: row[:edge_relationship])
    end
  end
end
