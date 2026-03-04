# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Analysis
    # Abstract base class for background jobs.
    # Subclasses implement #call(job) with domain-specific assembly logic.
    class BaseJob
      def call(job)
        raise NotImplementedError
      end
    end
  end
end
