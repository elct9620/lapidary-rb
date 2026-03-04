# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Analysis
    # Abstract base class for background jobs.
    # Subclasses implement #perform(job) with domain-specific assembly logic.
    # #call delegates to #perform so prepend-based patches (e.g. QueuePatch) are never bypassed.
    class BaseJob
      def call(job)
        perform(job)
      end

      def perform(job)
        raise NotImplementedError
      end
    end
  end
end
