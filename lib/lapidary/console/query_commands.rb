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

    # IRB command to find edges connected to a node
    class NeighborsCommand < IRB::Command::Base
      include TableFormatter

      category 'Query'
      description 'Find edges connected to a node'
      help_message <<~HELP
        Usage: neighbors <node_id>

        Find all edges connected to the given node, including archived edges.

        Examples:
          neighbors rubyist://matz
          neighbors core_module://Array
      HELP

      def execute(arg)
        node_id = arg.strip
        if node_id.empty?
          warn 'Usage: neighbors <node_id>'
          return
        end

        results = neighbor_repository.find_edges(node_id, include_archived: true)
        print_edges(results)
      end

      private

      def neighbor_repository
        Lapidary::Container['graph.repositories.neighbor_repository']
      end

      def print_edges(edges)
        print_table(
          %w[Source Target Relationship Archived],
          edges.map { |e| [e.source, e.target, e.relationship, e.archived_at || ''] }
        )
      end
    end

    # IRB command to list edges in the knowledge graph
    class EdgesCommand < IRB::Command::Base
      include TableFormatter

      category 'Query'
      description 'List edges, optionally filtered by node'
      help_message <<~HELP
        Usage: edges [node_id] [--archived]

        List edges in the knowledge graph.
        Without arguments, lists all active edges.
        With a node_id, lists edges connected to that node.
        With --archived, includes archived edges.

        Examples:
          edges                              # all active edges
          edges --archived                   # all edges including archived
          edges rubyist://matz               # edges for a specific node
          edges rubyist://matz --archived    # including archived edges
      HELP

      def execute(arg)
        parts = arg.strip.split
        archived = parts.delete('--archived')
        node_id = parts.first

        if node_id
          print_entity_edges(node_id, archived)
        else
          print_raw_edges(archived)
        end
      end

      private

      def print_entity_edges(node_id, archived)
        results = neighbor_repository.find_edges(node_id, include_archived: !archived.nil?)
        print_table(
          %w[Source Target Relationship Archived],
          results.map { |e| [e.source, e.target, e.relationship, e.archived_at || ''] }
        )
      end

      def print_raw_edges(archived)
        dataset = database[:edges]
        dataset = dataset.where(archived_at: nil) unless archived
        rows = dataset.all
        print_table(
          %w[Source Target Relationship Archived],
          rows.map { |r| [r[:source], r[:target], r[:relationship], r[:archived_at] || ''] }
        )
      end

      def neighbor_repository
        Lapidary::Container['graph.repositories.neighbor_repository']
      end

      def database
        Lapidary::Container['database']
      end
    end
  end
end

IRB::Command.register(:nodes, Lapidary::Console::NodesCommand)
IRB::Command.register(:node, Lapidary::Console::NodeCommand)
IRB::Command.register(:neighbors, Lapidary::Console::NeighborsCommand)
IRB::Command.register(:edges, Lapidary::Console::EdgesCommand)
