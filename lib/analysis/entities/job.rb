# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Domain entity representing an analysis job in the queue.
    class Job
      STATUSES = %w[pending claimed done failed].freeze

      attr_reader :id, :arguments, :status, :attempts, :max_attempts,
                  :error, :scheduled_at, :created_at, :updated_at

      def initialize(arguments: {}, id: nil, status: 'pending', # rubocop:disable Metrics/ParameterLists
                     attempts: 0, max_attempts: 3, error: nil,
                     scheduled_at: nil, created_at: nil, updated_at: nil)
        @id = id
        @arguments = arguments
        @status = status
        @attempts = attempts
        @max_attempts = max_attempts
        @error = error
        @scheduled_at = scheduled_at || Time.now
        @created_at = created_at
        @updated_at = updated_at
      end

      def claim
        raise JobError, "cannot claim job in #{@status} status" unless pending?

        @status = 'claimed'
        @updated_at = Time.now
      end

      def complete
        raise JobError, "cannot complete job in #{@status} status" unless claimed?

        @status = 'done'
        @updated_at = Time.now
      end

      def pending?
        @status == 'pending'
      end

      def claimed?
        @status == 'claimed'
      end

      def done?
        @status == 'done'
      end

      def failed?
        @status == 'failed'
      end

      def retryable?
        @attempts + 1 < @max_attempts
      end

      def retry(error)
        raise JobError, "cannot retry job in #{@status} status" unless claimed?

        @status = 'pending'
        @attempts += 1
        @error = error
        @scheduled_at = Time.now + (2**@attempts)
        @updated_at = Time.now
      end

      def fail(error)
        raise JobError, "cannot fail job in #{@status} status" unless claimed?

        @status = 'failed'
        @error = error
        @updated_at = Time.now
      end
    end
  end
end
