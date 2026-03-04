# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Sentry
    # Prepend-based instrumentation for Analysis::Service#process_job.
    # Activated conditionally in the Sentry provider.
    module QueuePatch
      def process_job(use_case, job)
        return super unless ::Sentry.initialized?

        transaction = ::Sentry.start_transaction(op: 'queue.process', name: 'analysis.process_job')
        ::Sentry.get_current_scope&.set_span(transaction) if transaction
        transaction&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
        super
      ensure
        transaction&.finish
      end
    end
  end
end
