# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/sentry/queue_publish_patch'

RSpec.describe Lapidary::Sentry::QueuePublishPatch do
  let(:base_class) do
    Class.new do
      include Lapidary::RepositorySupport

      attr_reader :enqueued_arguments

      def enqueue(job)
        @enqueued_arguments = job_attributes(job, Time.now)[:arguments]
      end

      private

      def job_attributes(job, now)
        payload = job.arguments.to_h.compact
        job.metadata.each { |k, v| payload[:"_#{k}"] = v }
        { arguments: generate_json(payload), created_at: now }
      end
    end
  end

  let(:patched_class) { base_class.prepend(described_class) }
  let(:instance) { patched_class.new }

  let(:arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }
  let(:job) { Analysis::Entities::Job.new(arguments: arguments) }

  context 'when Sentry is not initialized' do
    before do
      allow(Sentry).to receive(:initialized?).and_return(false)
      allow(Sentry).to receive(:with_child_span)
    end

    it 'delegates without a span' do
      instance.enqueue(job)

      expect(Sentry).not_to have_received(:with_child_span)
    end

    it 'does not inject trace headers' do
      instance.enqueue(job)

      payload = JSON.parse(instance.enqueued_arguments, symbolize_names: true)
      meta_keys = payload.keys.select { |k| k.start_with?('_') }
      expect(meta_keys).to be_empty
    end
  end

  context 'when Sentry is initialized' do
    let(:span) { double('Span') }
    let(:trace_headers) { { 'sentry-trace' => 'abc-123', 'baggage' => 'sentry-environment=test' } }

    before do
      allow(Sentry).to receive(:initialized?).and_return(true)
      allow(Sentry).to receive(:with_child_span).and_yield(span)
      allow(Sentry).to receive(:get_trace_propagation_headers).and_return(trace_headers)
      allow(span).to receive(:set_data)
    end

    it 'wraps enqueue in a queue.publish span' do
      instance.enqueue(job)

      expect(Sentry).to have_received(:with_child_span).with(
        op: 'queue.publish', description: 'analysis.jobs'
      )
    end

    it 'sets the messaging destination on the span' do
      instance.enqueue(job)

      expect(span).to have_received(:set_data).with(
        Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME,
        'analysis.jobs'
      )
    end

    it 'injects trace headers as _-prefixed keys in payload' do
      instance.enqueue(job)

      payload = JSON.parse(instance.enqueued_arguments, symbolize_names: true)
      expect(payload[:'_sentry-trace']).to eq('abc-123')
      expect(payload[:_baggage]).to eq('sentry-environment=test')
    end

    it 'preserves domain arguments in payload' do
      instance.enqueue(job)

      payload = JSON.parse(instance.enqueued_arguments, symbolize_names: true)
      domain_args = payload.reject { |k, _| k.start_with?('_') }
      expect(domain_args).to eq(entity_type: 'issue', entity_id: 1)
    end
  end
end
