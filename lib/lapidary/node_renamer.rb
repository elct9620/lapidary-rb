# frozen_string_literal: true

module Lapidary
  # Renames a node ID across nodes, edges, and observations tables.
  # Uses FK-safe ordering: create target node first, migrate edges via
  # insert-transfer-delete, then remove old node.
  class NodeRenamer
    include Dependency['database']
    include RepositorySupport

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
      database[:nodes].insert(id: new_id, type: old_node[:type], data: generate_json(data),
                              created_at: old_node[:created_at], updated_at: Time.now)
    end

    def migrate_edges(old_id, new_id)
      database[:edges].where(Sequel.or(source: old_id, target: old_id)).all.each do |edge|
        old_key = EdgeKey.from_edge_row(edge)
        new_key = remap_key(old_key, old_id, new_id)
        migrate_single_edge(old_key, new_key)
      end
    end

    def migrate_single_edge(old_key, new_key)
      if database[:edges].where(new_key.to_where).any?
        merge_edge_observations(old_key, new_key)
        database[:edges].where(old_key.to_where).delete
      else
        transfer_edge(old_key, new_key)
      end
    end

    def transfer_edge(old_key, new_key)
      copy_edge(old_key, new_key)
      repoint_observations(old_key, new_key)
      database[:edges].where(old_key.to_where).delete
    end

    def copy_edge(old_key, new_key)
      old_edge = database[:edges].where(old_key.to_where).first
      database[:edges].insert(
        new_key.to_where.merge(created_at: old_edge[:created_at], updated_at: Time.now,
                               archived_at: old_edge[:archived_at])
      )
    end

    def repoint_observations(old_key, new_key)
      obs_by_edge(old_key).update(new_key.to_observation_where)
    end

    def remap_key(key, old_id, new_id)
      EdgeKey.new(
        source: key.source == old_id ? new_id : key.source,
        target: key.target == old_id ? new_id : key.target,
        relationship: key.relationship
      )
    end

    def obs_by_edge(key)
      database[:observations].where(key.to_observation_where)
    end

    def merge_edge_observations(old_key, new_key)
      existing = obs_by_edge(new_key).select_map(%i[source_entity_type source_entity_id])
      return repoint_observations(old_key, new_key) if existing.empty?

      obs_by_edge(old_key)
        .where(%i[source_entity_type source_entity_id] => existing)
        .delete

      repoint_observations(old_key, new_key)
    end

    def build_node_data(old_id)
      old_node = database[:nodes].where(id: old_id).first
      data = parse_json(old_node[:data])
      inferred = infer_display_name(old_id)
      inferred ? data.merge(inferred) { |_key, existing, _new| existing } : data
    end

    def merge_node_data(target_id, source_data)
      target_node = database[:nodes].where(id: target_id).first
      target_data = parse_json(target_node[:data])
      merged = source_data.merge(target_data) { |_key, old_val, new_val| new_val.nil? ? old_val : new_val }
      database[:nodes].where(id: target_id).update(data: generate_json(merged), updated_at: Time.now)
    end

    def infer_display_name(old_id)
      result = ParentheticalName.parse(old_id.split('://', 2).last)
      result ? { display_name: result[1] } : nil
    end
  end
end
