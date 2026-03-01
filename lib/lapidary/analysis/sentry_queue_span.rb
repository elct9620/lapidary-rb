# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Analysis
    # Sentry span recording for queue processing operations.
    # Host class must provide queue processing context.
    module SentryQueueSpan
      private

      def with_queue_transaction
        transaction = start_queue_transaction
        yield
      ensure
        transaction&.finish
      end

      def start_queue_transaction
        transaction = ::Sentry.start_transaction(op: 'queue.process', name: 'analysis.process_job')
        ::Sentry.get_current_scope&.set_span(transaction) if transaction
        transaction&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
        transaction
      end
    end
  end
end
