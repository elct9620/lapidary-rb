# frozen_string_literal: true

module Analysis
  module Repositories
    # Writer for archiving graph edges based on observation staleness.
    class EdgeArchiveWriter
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      wraps_errors Entities::GraphError

      def archive_expired(cutoff:)
        with_error_wrapping do
          expired = find_expired_edges(cutoff)
          return Entities::ArchiveResult.new(archived_count: 0, entity_pairs: []) if expired.empty?

          perform_archive(expired)
        end
      end

      def archive_by_key(source:, target:, relationship:)
        with_error_wrapping do
          edge = edges.where(source: source, target: target, relationship: relationship).first
          raise Entities::GraphError, 'Edge not found' unless edge

          perform_archive([edge])
        end
      end

      private

      def edges
        database[:edges]
      end

      def observations
        database[:observations]
      end

      def perform_archive(target_edges)
        now = Time.now
        entity_pairs = collect_entity_pairs(target_edges)
        archive_edges(target_edges, now)
        Entities::ArchiveResult.new(archived_count: target_edges.size, entity_pairs: entity_pairs)
      end

      def find_expired_edges(cutoff)
        max_observed = observations.group(:edge_source, :edge_target, :edge_relationship)
                                   .select { max(observed_at).as(latest) }
                                   .select_append(:edge_source, :edge_target, :edge_relationship)
                                   .having { max(observed_at) < cutoff }

        edges.where(archived_at: nil)
             .where(
               %i[source target relationship] => max_observed.select(:edge_source, :edge_target,
                                                                     :edge_relationship)
             ).all
      end

      def collect_entity_pairs(expired_edges)
        observations.where(%i[edge_source edge_target edge_relationship] => edge_keys(expired_edges))
                    .distinct
                    .select(:source_entity_type, :source_entity_id)
                    .map { |row| { entity_type: row[:source_entity_type], entity_id: row[:source_entity_id] } }
      end

      def archive_edges(expired_edges, now)
        edges.where(%i[source target relationship] => edge_keys(expired_edges))
             .update(archived_at: now, updated_at: now)
      end

      def edge_keys(expired_edges)
        expired_edges.map { |e| Lapidary::EdgeKey.from_edge_row(e).to_a }
      end
    end
  end
end
