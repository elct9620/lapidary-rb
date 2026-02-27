# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the status of an analysis job.
    JobStatus = Data.define(:value) do
      def to_s
        value
      end
    end

    class JobStatus
      PENDING = new(value: 'pending')
      CLAIMED = new(value: 'claimed')
      DONE = new(value: 'done')
      FAILED = new(value: 'failed')

      TERMINAL = [DONE, FAILED, CLAIMED].freeze
    end
  end
end
