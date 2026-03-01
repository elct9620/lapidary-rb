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
        observations = parse_json(existing[:properties], default: [])
        return :duplicate if duplicate_observation?(observations, observation)

        observations << observation.to_h
        edges.where(source: existing[:source], target: existing[:target], relationship: existing[:relationship])
             .update(properties: generate_json(observations), updated_at: now)
        :appended
      end

      def duplicate_observation?(observations, observation)
        observations.any? do |obs|
          obs[:source_entity_type] == observation.source_entity_type &&
            obs[:source_entity_id] == observation.source_entity_id
        end
      end

      def insert_edge(source:, target:, relationship:, observation:, now:)
        edges.insert(
          source: source, target: target, relationship: relationship,
          properties: generate_json([observation.to_h]),
          created_at: now, updated_at: now
        )
        :inserted
      end
    end
  end
end
