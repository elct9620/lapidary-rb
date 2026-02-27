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

      def find_edges(node_id, direction: Entities::Direction::BOTH)
        with_error_wrapping do
          rows = query_edges(node_id, direction)
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

      def query_edges(node_id, direction)
        case direction
        when Entities::Direction::OUTBOUND
          edges.where(source: node_id).all
        when Entities::Direction::INBOUND
          edges.where(target: node_id).all
        else
          edges.where(Sequel.|({ source: node_id }, { target: node_id })).all
        end
      end

      def build_edge(row)
        raw_observations = parse_json(row[:properties], default: [])
        observations = raw_observations.map { |obs| build_observation(obs) }
        Entities::Edge.new(
          source: row[:source],
          target: row[:target],
          relationship: row[:relationship],
          observations: observations
        )
      end

      def build_observation(obs)
        Entities::Observation.new(
          **obs,
          observed_at: parse_time(obs[:observed_at])
        )
      end

      def parse_time(value)
        return nil unless value

        Time.iso8601(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
