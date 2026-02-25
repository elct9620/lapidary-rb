# auto_register: false
# frozen_string_literal: true

module Analysis
  module UseCases
    # Deletes expired jobs that have exceeded the configured retention period.
    class CleanupJobs
      def initialize(job_repository:, retention_period:, logger:)
        @job_repository = job_repository
        @retention_period = retention_period
        @logger = logger
      end

      def call(now: Time.now)
        cutoff = @retention_period.cutoff(now: now)
        deleted = @job_repository.delete_expired(cutoff: cutoff)
        @logger.info(self) { "Job cleanup: deleted #{deleted} expired jobs (retention: #{@retention_period})" }
        deleted
      end
    end
  end
end
