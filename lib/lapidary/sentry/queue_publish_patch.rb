# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Sentry
    # Prepend-based instrumentation for JobRepository#enqueue.
    # Wraps enqueue in a queue.publish span and injects trace propagation
    # headers into the job payload as _-prefixed metadata keys.
    # Activated conditionally in the Sentry provider.
    module QueuePublishPatch
      def enqueue(job)
        return super unless ::Sentry.initialized?

        ::Sentry.with_child_span(op: 'queue.publish', description: 'analysis.jobs') do |span|
          span&.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
          super
        end
      end

      private

      def job_attributes(job, now)
        attrs = super
        return attrs unless ::Sentry.initialized?

        payload = parse_json(attrs[:arguments])
        ::Sentry.get_trace_propagation_headers.each { |k, v| payload[:"_#{k}"] = v }
        attrs.merge(arguments: generate_json(payload))
      end
    end
  end
end
