# frozen_string_literal: true

module Lapidary
  # Renames a node ID across nodes, edges, and observations tables.
  # Uses FK-safe ordering: create target node first, migrate edges via
  # insert-transfer-delete, then remove old node.
  class NodeRenamer
    include Dependency['database']

    PARENTHETICAL_PATTERN = /\A(.+?)\s*\((.+)\)\z/

    class NodeNotFoundError < StandardError; end

    def call(old_id, new_id)
      raise NodeNotFoundError, "node not found: #{old_id}" unless database[:nodes].where(id: old_id).any?

      database.transaction do
        ensure_target_node(old_id, new_id)
        migrate_edges(old_id, new_id)
        database[:nodes].where(id: old_id).delete
      end
    end

    private

    def ensure_target_node(old_id, new_id)
      old_data = build_node_data(old_id)
      if database[:nodes].where(id: new_id).any?
        merge_node_data(new_id, old_data)
      else
        insert_cloned_node(old_id, new_id, old_data)
      end
    end

    def insert_cloned_node(old_id, new_id, data)
      old_node = database[:nodes].where(id: old_id).first
      database[:nodes].insert(id: new_id, type: old_node[:type], data: JSON.generate(data),
                              created_at: old_node[:created_at], updated_at: Time.now)
    end

    def migrate_edges(old_id, new_id)
      database[:edges].where(Sequel.or(source: old_id, target: old_id)).all.each do |edge|
        old_key = edge.slice(:source, :target, :relationship)
        new_key = remap_key(old_key, old_id, new_id)
        migrate_single_edge(old_key, new_key)
      end
    end

    def migrate_single_edge(old_key, new_key)
      if database[:edges].where(new_key).any?
        merge_edge_observations(old_key, new_key)
        database[:edges].where(old_key).delete
      else
        transfer_edge(old_key, new_key)
      end
    end

    def transfer_edge(old_key, new_key)
      copy_edge(old_key, new_key)
      repoint_observations(old_key, new_key)
      database[:edges].where(old_key).delete
    end

    def copy_edge(old_key, new_key)
      old_edge = database[:edges].where(old_key).first
      database[:edges].insert(
        new_key.merge(created_at: old_edge[:created_at], updated_at: Time.now, archived_at: old_edge[:archived_at])
      )
    end

    def repoint_observations(old_key, new_key)
      obs_by_edge(old_key).update(
        edge_source: new_key[:source], edge_target: new_key[:target], edge_relationship: new_key[:relationship]
      )
    end

    def remap_key(key, old_id, new_id)
      { source: key[:source] == old_id ? new_id : key[:source],
        target: key[:target] == old_id ? new_id : key[:target],
        relationship: key[:relationship] }
    end

    def obs_by_edge(key)
      database[:observations].where(
        edge_source: key[:source], edge_target: key[:target], edge_relationship: key[:relationship]
      )
    end

    def merge_edge_observations(old_key, new_key)
      identities = obs_by_edge(old_key).select_map(%i[source_entity_type source_entity_id])

      identities.each do |entity_type, entity_id|
        identity = { source_entity_type: entity_type, source_entity_id: entity_id }
        obs_by_edge(old_key).where(identity).delete if obs_by_edge(new_key).where(identity).any?
      end

      repoint_observations(old_key, new_key)
    end

    def build_node_data(old_id)
      old_node = database[:nodes].where(id: old_id).first
      data = old_node[:data] ? JSON.parse(old_node[:data], symbolize_names: true) : {}
      inferred = infer_display_name(old_id)
      inferred ? data.merge(inferred) { |_key, existing, _new| existing } : data
    end

    def merge_node_data(target_id, source_data)
      target_node = database[:nodes].where(id: target_id).first
      target_data = target_node[:data] ? JSON.parse(target_node[:data], symbolize_names: true) : {}
      merged = source_data.merge(target_data) { |_key, old_val, new_val| new_val.nil? ? old_val : new_val }
      database[:nodes].where(id: target_id).update(data: JSON.generate(merged), updated_at: Time.now)
    end

    def infer_display_name(old_id)
      match = PARENTHETICAL_PATTERN.match(old_id.split('://', 2).last)
      match ? { display_name: match[2].strip } : nil
    end
  end
end
