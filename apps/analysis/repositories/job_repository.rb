# frozen_string_literal: true

require 'json'

module Analysis
  module Repositories
    # Repository for managing analysis job persistence and claiming.
    class JobRepository
      include Lapidary::Dependency['database']
      include Lapidary::RepositorySupport

      table :jobs
      wraps_errors Entities::JobError

      def enqueue(job)
        with_error_wrapping do
          now = Time.now
          dataset.insert(job_attributes(job, now))
        end
      end

      def claim_next
        with_error_wrapping do
          now = Time.now
          claimed_row = claim_pending_job(now)
          return nil unless claimed_row

          row_to_entity(claimed_row)
        end
      end

      def save(job)
        with_error_wrapping do
          dataset.where(id: job.id).update(
            status: job.status.to_s, attempts: job.attempts,
            error: job.error, scheduled_at: job.scheduled_at,
            updated_at: job.updated_at
          )
        end
      end

      def delete_expired(cutoff:)
        with_error_wrapping do
          dataset.where(status: Entities::JobStatus::TERMINAL.map(&:to_s))
                 .where { updated_at < cutoff }
                 .delete
        end
      end

      private

      def job_attributes(job, now)
        {
          arguments: JSON.generate(job.arguments.to_h.compact),
          status: job.status.to_s, attempts: job.attempts,
          max_attempts: job.max_attempts, scheduled_at: job.scheduled_at,
          created_at: now, updated_at: now
        }
      end

      # Three-step claim (select → update → fetch) relies on SQLite's single-writer
      # guarantee to avoid race conditions without explicit locking.
      def claim_pending_job(now)
        job_id = pending_query(now).get(:id)
        return nil unless job_id

        updated = dataset.where(id: job_id, status: Entities::JobStatus::PENDING.to_s)
                         .update(status: Entities::JobStatus::CLAIMED.to_s, updated_at: now)
        return nil if updated.zero?

        dataset.where(id: job_id).first
      end

      def pending_query(now)
        dataset.where(status: Entities::JobStatus::PENDING.to_s)
               .where { scheduled_at <= now }
               .order(:scheduled_at).limit(1)
      end

      def row_to_entity(row)
        Entities::Job.new(
          **row.slice(:id, :attempts, :max_attempts, :error, :scheduled_at, :updated_at),
          arguments: Entities::JobArguments.new(**JSON.parse(row[:arguments], symbolize_names: true)),
          status: Entities::JobStatus.new(value: row[:status])
        )
      end
    end
  end
end
