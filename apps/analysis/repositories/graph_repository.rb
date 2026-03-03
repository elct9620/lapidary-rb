# frozen_string_literal: true

module Analysis
  module Repositories
    # Repository for persisting knowledge graph nodes and edges.
    # Manages both `nodes` and `edges` tables as a multi-table aggregate.
    class GraphRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      wraps_errors Entities::GraphError

      def save_triplet(triplet, observation)
        with_error_wrapping do
          database.transaction do
            upsert_nodes(triplet)
            upsert_edge(source: build_node_id(triplet.subject), target: build_node_id(triplet.object),
                        relationship: triplet.relationship.to_s, observation: observation)
          end
        end
      end

      private

      # Unlike other repositories, GraphRepository manages a multi-table aggregate (nodes + edges),
      # so the `table` DSL is not used. `dataset` defaults to nodes; `edges` accesses the edges table.
      # Both tables are written only by this repository (single-writer assumption).
      def dataset
        database[:nodes]
      end

      def edges
        database[:edges]
      end

      def observations
        database[:observations]
      end

      def upsert_nodes(triplet)
        upsert_node(node: triplet.subject)
        upsert_node(node: triplet.object)
      end

      def build_node_id(node)
        Lapidary::NodeId.build(node.type, node.name)
      end

      def upsert_node(node:)
        now = Time.now
        id = build_node_id(node)
        merged_data = merge_preserving_existing(id, node.properties)
        data = generate_json(merged_data)
        dataset.insert_conflict(target: :id, update: { data: data, updated_at: now })
               .insert(id: id, type: node.type.to_s, data: data, created_at: now, updated_at: now)
      end

      def merge_preserving_existing(id, new_properties)
        existing = dataset.where(id: id).first
        return new_properties unless existing

        existing_data = parse_json(existing[:data])
        existing_data.merge(new_properties) { |_key, old_val, new_val| new_val.nil? ? old_val : new_val }
      end

      # Read-modify-write relies on SQLite's single-writer
      # guarantee to avoid race conditions without explicit locking.
      def upsert_edge(source:, target:, relationship:, observation:)
        now = Time.now
        existing = edges.where(source: source, target: target, relationship: relationship).first

        if existing
          append_observation(existing, observation, now)
        else
          insert_edge(source: source, target: target, relationship: relationship,
                      observation: observation, now: now)
        end
      end

      def append_observation(existing, observation, now)
        return :duplicate if duplicate_observation?(existing, observation)

        insert_observation(existing, observation, now)
        unarchive_edge(existing, now)
        :appended
      end

      def duplicate_observation?(existing, observation)
        observations.where(
          edge_source: existing[:source],
          edge_target: existing[:target],
          edge_relationship: existing[:relationship],
          source_entity_type: observation.source_entity_type,
          source_entity_id: observation.source_entity_id
        ).any?
      end

      def insert_observation(edge_row, observation, now)
        observations.insert(
          **observation_edge_key(edge_row),
          observed_at: observation.observed_at,
          source_entity_type: observation.source_entity_type,
          source_entity_id: observation.source_entity_id,
          parent_entity_id: observation.parent_entity_id,
          evidence: observation.evidence,
          created_at: now
        )
      end

      def observation_edge_key(edge_row)
        Lapidary::EdgeKey.from_edge_row(edge_row).to_observation_where
      end

      def unarchive_edge(existing, now)
        return unless existing[:archived_at]

        edges.where(source: existing[:source], target: existing[:target], relationship: existing[:relationship])
             .update(archived_at: nil, updated_at: now)
      end

      def insert_edge(source:, target:, relationship:, observation:, now:)
        edges.insert(
          source: source, target: target, relationship: relationship,
          created_at: now, updated_at: now
        )
        insert_observation({ source: source, target: target, relationship: relationship }, observation, now)
        :inserted
      end
    end
  end
end
