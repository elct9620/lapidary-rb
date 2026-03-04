# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Sentry
    # Prepend-based instrumentation for BaseJob#call.
    # Activated conditionally in the Sentry provider.
    module QueuePatch
      def call(job)
        return super unless ::Sentry.initialized?

        transaction = start_queue_transaction(job)
        ::Sentry.get_current_scope&.set_span(transaction) if transaction
        transaction&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
        super
      ensure
        transaction&.finish
      end

      private

      def start_queue_transaction(job)
        trace_headers = job.metadata
        if trace_headers.key?('sentry-trace')
          ::Sentry.continue_trace(trace_headers, op: 'queue.process', name: self.class.name)
        else
          ::Sentry.start_transaction(op: 'queue.process', name: self.class.name)
        end
      end
    end
  end
end
