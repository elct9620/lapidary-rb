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
          return [] if rows.empty?

          obs_map = load_observations_batch(rows)
          rows.map { |row| build_edge(row, obs_map) }
        end
      end

      def find_nodes_by_ids(ids)
        with_error_wrapping do
          return {} if ids.empty?

          dataset.where(id: ids).to_h do |row|
            [row[:id], build_node(row)]
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

      def build_edge(row, obs_map)
        edge_key = Lapidary::EdgeKey.from_edge_row(row)
        Entities::Edge.new(
          source: edge_key.source,
          target: edge_key.target,
          relationship: edge_key.relationship,
          observations: obs_map[edge_key] || [],
          archived_at: row[:archived_at]
        )
      end

      def load_observations_batch(edge_rows)
        conditions = edge_rows.map { |r| Lapidary::EdgeKey.from_edge_row(r).to_observation_where }
        observations_table.where(Sequel.|(*conditions))
                          .each_with_object(Hash.new { |h, k| h[k] = [] }) do |obs, map|
          map[Lapidary::EdgeKey.from_observation_row(obs)] << build_observation(obs)
        end
      end

      def build_observation(obs)
        Entities::Observation.new(
          observed_at: parse_time(obs[:observed_at]),
          source_entity_type: obs[:source_entity_type],
          source_entity_id: obs[:source_entity_id],
          evidence: obs[:evidence],
          parent_entity_id: obs[:parent_entity_id]
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
