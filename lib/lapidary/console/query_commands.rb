# auto_register: false
# frozen_string_literal: true

require 'irb/command'
require_relative 'table_formatter'

module Lapidary
  module Console
    # IRB command to list nodes in the knowledge graph
    class NodesCommand < IRB::Command::Base
      include TableFormatter

      category 'Query'
      description 'List nodes in the knowledge graph'
      help_message <<~HELP
        Usage: nodes [type]

        List nodes in the knowledge graph, optionally filtered by type.

        Examples:
          nodes                  # list all nodes (up to 10,000)
          nodes rubyist          # list nodes of type "rubyist"
          nodes core_module      # list nodes of type "core_module"
      HELP

      def execute(arg)
        type = arg.strip.empty? ? nil : arg.strip
        results = node_repository.search(type: type, include_orphans: true, limit: 10_000)
        print_table(%w[ID Type], results.map { |n| [n.id, n.type] })
      end

      private

      def node_repository
        Lapidary::Container['graph.repositories.node_repository']
      end
    end

    # IRB command to find a single node by ID
    class NodeCommand < IRB::Command::Base
      include TableFormatter

      category 'Query'
      description 'Find a single node by ID'
      help_message <<~HELP
        Usage: node <id>

        Find a single node by its ID (URI format: type://name).

        Examples:
          node rubyist://matz
          node core_module://Array
      HELP

      def execute(arg)
        id = arg.strip
        if id.empty?
          warn 'Usage: node <id>'
          return
        end

        result = neighbor_repository.find_node(id)
        return puts "Node not found: #{id}" unless result

        print_detail([['ID:', result.id], ['Type:', result.type], ['Data:', result.data]])
      end

      private

      def neighbor_repository
        Lapidary::Container['graph.repositories.neighbor_repository']
      end
    end

    # IRB command to query neighbors of a node (Node → Edge → Node triplets)
    class NeighborsCommand < IRB::Command::Base
      include TableFormatter

      category 'Query'
      description 'Query neighbors of a node'
      help_message <<~HELP
        Usage: neighbors <node_id> [--archived]

        Show neighbors of the given node as Source → Relationship → Target triplets.
        By default, only active edges are shown.
        With --archived, includes archived edges.

        Examples:
          neighbors rubyist://matz
          neighbors rubyist://matz --archived
          neighbors core_module://Array
      HELP

      def execute(arg)
        parts = arg.strip.split
        include_archived = !parts.delete('--archived').nil?
        node_id = parts.first

        if node_id.nil? || node_id.empty?
          warn 'Usage: neighbors <node_id> [--archived]'
          return
        end

        result = query_neighbors(node_id, include_archived: include_archived)
        return puts "Node not found: #{node_id}" unless result

        print_neighbor_result(result)
      end

      private

      def query_neighbors(node_id, include_archived:)
        use_case = Graph::UseCases::QueryNeighbors.new(
          neighbor_repository: Lapidary::Container['graph.repositories.neighbor_repository']
        )
        use_case.call(node_id: node_id, include_archived: include_archived)
      end

      def print_neighbor_result(result)
        node = result[:node]
        puts "Node: #{node.id} (#{node.type})"
        puts

        rows = result[:neighbors].flat_map { |neighbor| neighbor_rows(neighbor) }
        print_table(%w[Source Relationship Target], rows)
      end

      def neighbor_rows(neighbor)
        neighbor.edges.map do |edge|
          [edge.source, edge.relationship, edge.target]
        end
      end
    end
  end
end

IRB::Command.register(:nodes, Lapidary::Console::NodesCommand)
IRB::Command.register(:node, Lapidary::Console::NodeCommand)
IRB::Command.register(:neighbors, Lapidary::Console::NeighborsCommand)
