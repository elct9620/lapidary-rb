# auto_register: false
# frozen_string_literal: true

require 'irb/command'

module Lapidary
  module Console
    # IRB command to rename a node ID
    class RenameNodeCommand < IRB::Command::Base
      category 'Maintenance'
      description 'Rename a node ID'
      help_message <<~HELP
        Usage: rename_node <old_id> <new_id>

        Rename a node by changing its ID. Updates all connected edges
        to reference the new ID (FK-safe).

        Examples:
          rename_node rubyist://matz rubyist://yukihiro_matsumoto
      HELP

      def execute(arg)
        parts = arg.strip.split
        if parts.size != 2
          warn 'Usage: rename_node <old_id> <new_id>'
          return
        end

        old_id, new_id = parts
        Lapidary::Container['maintenance.node_renamer'].call(old_id, new_id)
        puts "Renamed node: #{old_id} -> #{new_id}"
      end
    end

    # IRB command to delete an orphan node
    class DeleteNodeCommand < IRB::Command::Base
      category 'Maintenance'
      description 'Delete an orphan node'
      help_message <<~HELP
        Usage: delete_node <node_id>

        Delete a node from the knowledge graph. Purges any archived
        edges before deletion.

        Examples:
          delete_node rubyist://unknown_user
      HELP

      def execute(arg)
        node_id = arg.strip
        if node_id.empty?
          warn 'Usage: delete_node <node_id>'
          return
        end

        Lapidary::Container['maintenance.node_deleter'].call(node_id)
        puts "Deleted node: #{node_id}"
      end
    end

    # IRB command to archive an edge between two nodes
    class ArchiveEdgeCommand < IRB::Command::Base
      category 'Maintenance'
      description 'Archive an edge between two nodes'
      help_message <<~HELP
        Usage: archive_edge <source> <target> <relationship>

        Archive an edge and clear its associated analysis records.

        Examples:
          archive_edge rubyist://matz core_module://Array Maintain
      HELP

      def execute(arg)
        source, target, relationship = parse_arguments(arg)
        return unless source

        result = Lapidary::Container['maintenance.edge_archiver'].call(
          source: source, target: target, relationship: relationship
        )
        puts "Archived edge: #{source} -> #{target} [#{relationship}]"
        puts "Cleared #{result[:analysis_records_cleared]} analysis record(s)"
      end

      private

      def parse_arguments(arg)
        parts = arg.strip.split
        return warn('Usage: archive_edge <source> <target> <relationship>') if parts.size != 3

        parts
      end
    end
  end
end

IRB::Command.register(:rename_node, Lapidary::Console::RenameNodeCommand)
IRB::Command.register(:delete_node, Lapidary::Console::DeleteNodeCommand)
IRB::Command.register(:archive_edge, Lapidary::Console::ArchiveEdgeCommand)
