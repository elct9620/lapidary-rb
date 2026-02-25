# frozen_string_literal: true

require 'json'

module Analysis
  module Repositories
    # Repository for persisting knowledge graph nodes and edges.
    class GraphRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      table :nodes
      wraps_errors Entities::GraphError

      def save_triplet(triplet, observation)
        with_error_wrapping do
          upsert_nodes(triplet)
          upsert_edge(source: build_node_id(triplet.subject), target: build_node_id(triplet.object),
                      relationship: triplet.relationship.to_s, observation: observation)
        end
      end

      private

      def edges
        database[:edges]
      end

      def upsert_nodes(triplet)
        upsert_node(node: triplet.subject)
        upsert_node(node: triplet.object)
      end

      def build_node_id(node)
        type_slug = node.type.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        "#{type_slug}://#{node.name}"
      end

      def upsert_node(node:)
        now = Time.now
        id = build_node_id(node)
        merged_data = merge_node_data(id, node.properties)
        data = JSON.generate(merged_data)
        dataset.insert_conflict(target: :id, update: { data: data, updated_at: now })
               .insert(id: id, type: node.type.to_s, data: data, created_at: now, updated_at: now)
      end

      def merge_node_data(id, new_properties)
        existing = dataset.where(id: id).first
        return new_properties unless existing

        existing_data = JSON.parse(existing[:data], symbolize_names: true)
        existing_data.merge(new_properties) { |_key, old_val, new_val| new_val.nil? ? old_val : new_val }
      end

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
        observations = JSON.parse(existing[:properties] || '[]', symbolize_names: true)
        return :duplicate if duplicate_observation?(observations, observation)

        observations << observation
        edges.where(source: existing[:source], target: existing[:target], relationship: existing[:relationship])
             .update(properties: JSON.generate(observations), updated_at: now)
        :appended
      end

      def duplicate_observation?(observations, observation)
        observations.any? do |obs|
          obs[:source_entity_type] == observation[:source_entity_type] &&
            obs[:source_entity_id] == observation[:source_entity_id]
        end
      end

      def insert_edge(source:, target:, relationship:, observation:, now:)
        edges.insert(
          source: source, target: target, relationship: relationship,
          properties: JSON.generate([observation]),
          created_at: now, updated_at: now
        )
        :inserted
      end
    end
  end
end
