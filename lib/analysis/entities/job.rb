# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Domain entity representing an analysis job in the queue.
    class Job
      RETRY_BACKOFF_BASE = 2

      attr_reader :id, :arguments, :metadata, :status, :attempts, :max_attempts,
                  :error, :scheduled_at, :updated_at

      def initialize(arguments:, metadata: {}, max_attempts: 3, scheduled_at: nil, **attrs)
        @arguments = arguments
        @metadata = metadata
        @max_attempts = max_attempts
        @scheduled_at = scheduled_at || Time.now
        @id = attrs[:id]
        @status = attrs.fetch(:status, JobStatus::PENDING)
        @attempts = attrs.fetch(:attempts, 0)
        @error = attrs[:error]
        @updated_at = attrs[:updated_at]
      end

      def claim(now: Time.now)
        raise JobError, "cannot claim job in #{@status} status" unless pending?

        @status = JobStatus::CLAIMED
        @updated_at = now
      end

      def complete(now: Time.now)
        raise JobError, "cannot complete job in #{@status} status" unless claimed?

        @status = JobStatus::DONE
        @updated_at = now
      end

      def pending?
        @status == JobStatus::PENDING
      end

      def claimed?
        @status == JobStatus::CLAIMED
      end

      def retryable?
        @attempts + 1 < @max_attempts
      end

      def retry(error, now: Time.now)
        raise JobError, "cannot retry job in #{@status} status" unless claimed?

        @status = JobStatus::PENDING
        @attempts += 1
        @error = error
        @scheduled_at = now + (RETRY_BACKOFF_BASE**@attempts)
        @updated_at = now
      end

      def fail(error, now: Time.now)
        raise JobError, "cannot fail job in #{@status} status" unless claimed?

        @status = JobStatus::FAILED
        @error = error
        @updated_at = now
      end

      def release(now: Time.now)
        raise JobError, "cannot release job in #{@status} status" unless claimed?

        @status = JobStatus::PENDING
        @scheduled_at = now
        @updated_at = now
      end
    end
  end
end
