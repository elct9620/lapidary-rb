# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Searches for existing observations on an edge in the knowledge graph.
      # Lets the LLM check if a relationship was already observed from a parent issue.
      class SearchObservationTool < RubyLLM::Tool
        description 'Search for existing observations on an edge between a Rubyist and a module. ' \
                    'Use this to check if a relationship was already observed from the parent issue ' \
                    'before extracting it again from a journal.'

        param :source_name, desc: 'Source node name or partial name (Rubyist) to search for'
        param :target_name, desc: 'Target node name or partial name (Module) to search for'

        def initialize(database)
          super()
          @database = database
        end

        EDGE_JOIN_KEYS = [
          %i[source edge_source],
          %i[target edge_target],
          %i[relationship edge_relationship]
        ].freeze

        SELECTED_COLUMNS = [
          Sequel[:observations][:source_entity_type],
          Sequel[:observations][:source_entity_id],
          Sequel[:observations][:evidence],
          Sequel[:edges][:source],
          Sequel[:edges][:target],
          Sequel[:edges][:relationship]
        ].freeze

        def execute(source_name:, target_name:)
          query_observations(
            "%#{escape_like(source_name)}%",
            "%#{escape_like(target_name)}%"
          ).map { |row| format_row(row) }.to_json
        end

        private

        def query_observations(source_pattern, target_pattern)
          @database[:observations]
            .join(:edges, EDGE_JOIN_KEYS)
            .where(Sequel.ilike(:edge_source, source_pattern))
            .where(Sequel.ilike(:edge_target, target_pattern))
            .where(Sequel[:edges][:archived_at] => nil)
            .select(*SELECTED_COLUMNS)
            .limit(10)
            .all
        end

        def format_row(row)
          row.slice(:source, :target, :relationship, :source_entity_type, :source_entity_id, :evidence)
        end

        def escape_like(value)
          value.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
        end
      end
    end
  end
end
