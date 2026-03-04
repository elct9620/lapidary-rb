# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Sentry
    # Prepend-based instrumentation for BaseJob#call.
    # Activated conditionally in the Sentry provider.
    module QueuePatch
      def call(job)
        return super unless ::Sentry.initialized?

        transaction = ::Sentry.start_transaction(op: 'queue.process', name: self.class.name)
        ::Sentry.get_current_scope&.set_span(transaction) if transaction
        transaction&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
        super
      ensure
        transaction&.finish
      end
    end
  end
end
