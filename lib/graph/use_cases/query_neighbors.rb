# auto_register: false
# frozen_string_literal: true

module Graph
  module UseCases
    # Queries the knowledge graph for neighbors of a given node,
    # with optional observation time-range filtering.
    class QueryNeighbors
      def initialize(neighbor_repository:)
        @neighbor_repository = neighbor_repository
      end

      def call(node_id:, direction: 'both', observed_after: nil, observed_before: nil)
        node = @neighbor_repository.find_node(node_id)
        return nil unless node

        edges = @neighbor_repository.find_edges(node_id, direction: direction)
        edges = filter_observations(edges, observed_after: observed_after, observed_before: observed_before)

        neighbor_ids = collect_neighbor_ids(edges, node_id)
        neighbor_nodes = @neighbor_repository.find_nodes_by_ids(neighbor_ids)

        neighbors = build_neighbors(edges, node_id, neighbor_nodes)

        { node: node, neighbors: neighbors }
      end

      private

      def filter_observations(edges, observed_after:, observed_before:)
        return edges unless observed_after || observed_before

        after_time, before_time = parse_time_bounds(observed_after, observed_before)

        edges.filter_map do |edge|
          filtered = edge.observations.select { |obs| observation_in_range?(obs, after_time, before_time) }
          edge.with(observations: filtered) unless filtered.empty?
        end
      end

      def parse_time_bounds(observed_after, observed_before)
        [
          observed_after  && Time.iso8601(observed_after),
          observed_before && Time.iso8601(observed_before)
        ]
      end

      def observation_in_range?(observation, after_time, before_time)
        observed_at = observation[:observed_at]
        return true unless observed_at

        time = Time.iso8601(observed_at)
        return false if after_time  && time < after_time
        return false if before_time && time > before_time

        true
      end

      def collect_neighbor_ids(edges, node_id)
        edges.flat_map { |e| [e.source, e.target] }.uniq - [node_id]
      end

      def build_neighbors(edges, node_id, neighbor_nodes)
        grouped = edges.group_by { |e| e.source == node_id ? e.target : e.source }

        grouped.filter_map do |neighbor_id, neighbor_edges|
          neighbor_node = neighbor_nodes[neighbor_id]
          next unless neighbor_node

          Entities::Neighbor.new(node: neighbor_node, edges: neighbor_edges)
        end
      end
    end
  end
end
