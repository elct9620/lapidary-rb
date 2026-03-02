# frozen_string_literal: true

module Graph
  module Repositories
    # Read-only repository for querying knowledge graph neighbors.
    class NeighborRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport
      include NodeBuilder

      table :nodes
      wraps_errors Entities::GraphQueryError

      def find_node(node_id)
        with_error_wrapping do
          row = dataset.where(id: node_id).first
          return nil unless row

          build_node(row)
        end
      end

      def find_edges(node_id, direction: Entities::Direction::BOTH, include_archived: false)
        with_error_wrapping do
          rows = query_edges(node_id, direction, include_archived)
          rows.map { |row| build_edge(row) }
        end
      end

      def find_nodes_by_ids(ids)
        with_error_wrapping do
          return {} if ids.empty?

          dataset.where(id: ids).each_with_object({}) do |row, hash|
            hash[row[:id]] = build_node(row)
          end
        end
      end

      private

      def edges
        database[:edges]
      end

      def observations_table
        database[:observations]
      end

      def query_edges(node_id, direction, include_archived)
        ds = apply_direction(node_id, direction)
        ds = ds.where(archived_at: nil) unless include_archived
        ds.all
      end

      def apply_direction(node_id, direction)
        case direction
        when Entities::Direction::OUTBOUND
          edges.where(source: node_id)
        when Entities::Direction::INBOUND
          edges.where(target: node_id)
        else
          edges.where(Sequel.|({ source: node_id }, { target: node_id }))
        end
      end

      def build_edge(row)
        Entities::Edge.new(
          source: row[:source],
          target: row[:target],
          relationship: row[:relationship],
          observations: load_observations(row),
          archived_at: row[:archived_at]
        )
      end

      def load_observations(edge_row)
        observations_table.where(
          edge_source: edge_row[:source], edge_target: edge_row[:target],
          edge_relationship: edge_row[:relationship]
        ).map { |obs| build_observation(obs) }
      end

      def build_observation(obs)
        Entities::Observation.new(
          observed_at: parse_time(obs[:observed_at]),
          source_entity_type: obs[:source_entity_type],
          source_entity_id: obs[:source_entity_id],
          evidence: obs[:evidence]
        )
      end

      def parse_time(value)
        return nil unless value
        return value if value.is_a?(Time)

        Time.iso8601(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
