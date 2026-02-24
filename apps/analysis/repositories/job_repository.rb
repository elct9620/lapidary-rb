# frozen_string_literal: true

require 'json'

module Analysis
  module Repositories
    # Repository for managing analysis job persistence and claiming.
    class JobRepository
      include Lapidary::Dependency['database']

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
            status: job.status, attempts: job.attempts,
            error: job.error, scheduled_at: job.scheduled_at,
            updated_at: job.updated_at || Time.now
          )
        end
      end

      private

      def job_attributes(job, now)
        {
          arguments: JSON.generate(job.arguments),
          status: job.status, attempts: job.attempts,
          max_attempts: job.max_attempts, scheduled_at: job.scheduled_at,
          created_at: now, updated_at: now
        }
      end

      def claim_pending_job(now)
        job_id = pending_query(now).get(:id)
        return nil unless job_id

        updated = dataset.where(id: job_id, status: 'pending')
                         .update(status: 'claimed', updated_at: now)
        return nil if updated.zero?

        dataset.where(id: job_id).first
      end

      def pending_query(now)
        dataset.where(status: 'pending')
               .where { scheduled_at <= now }
               .order(:scheduled_at).limit(1)
      end

      def with_error_wrapping
        yield
      rescue Sequel::Error => e
        raise Entities::JobError, e.message
      end

      def row_to_entity(row)
        attrs = row.slice(
          :id, :status, :attempts, :max_attempts, :error,
          :scheduled_at, :created_at, :updated_at
        )
        attrs[:arguments] = JSON.parse(row[:arguments], symbolize_names: true)
        Entities::Job.new(**attrs)
      end

      def dataset
        database[:jobs]
      end
    end
  end
end
