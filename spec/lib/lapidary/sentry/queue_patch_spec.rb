# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/sentry/queue_patch'

RSpec.describe Lapidary::Sentry::QueuePatch do
  let(:base_class) do
    Class.new do
      def self.name = 'TestBaseJob'

      def call(job)
        perform(job)
      end

      def perform(job)
        raise NotImplementedError
      end
    end
  end

  let(:host_class) do
    Class.new(base_class) do
      def self.name = 'TestJob'

      def perform(job)
        job
      end
    end
  end

  let(:patched_class) do
    base_class.prepend(described_class)
    host_class
  end

  let(:instance) { patched_class.new }

  context 'when Sentry is not initialized' do
    let(:job) { double('Job') }

    before do
      allow(Sentry).to receive(:initialized?).and_return(false)
      allow(Sentry).to receive(:start_transaction)
    end

    it 'delegates to the original method without instrumentation' do
      result = instance.call(job)

      expect(result).to eq(job)
      expect(Sentry).not_to have_received(:start_transaction)
    end
  end

  context 'when Sentry is initialized' do
    let(:transaction) { double('Transaction', finish: nil) }
    let(:scope) { double('Scope', set_span: nil) }

    before do
      allow(Sentry).to receive(:initialized?).and_return(true)
      allow(Sentry).to receive(:start_transaction).and_return(transaction)
      allow(Sentry).to receive(:continue_trace).and_return(transaction)
      allow(Sentry).to receive(:get_current_scope).and_return(scope)
      allow(transaction).to receive(:set_data)
    end

    context 'when job has no trace metadata' do
      let(:job) { double('Job', metadata: {}) }

      it 'starts a standalone transaction' do
        instance.call(job)

        expect(Sentry).to have_received(:start_transaction).with(
          op: 'queue.process', name: 'TestJob'
        )
      end

      it 'sets the transaction on the current scope' do
        instance.call(job)

        expect(scope).to have_received(:set_span).with(transaction)
      end

      it 'sets the messaging destination' do
        instance.call(job)

        expect(transaction).to have_received(:set_data).with(
          Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME,
          'analysis.jobs'
        )
      end

      it 'finishes the transaction' do
        instance.call(job)

        expect(transaction).to have_received(:finish)
      end

      it 'finishes the transaction even on error' do
        host_class.define_method(:perform) { |_job| raise 'boom' }

        expect { instance.call(job) }.to raise_error(RuntimeError, 'boom')
        expect(transaction).to have_received(:finish)
      end
    end

    context 'when job has trace metadata' do
      let(:trace_headers) { { 'sentry-trace' => 'abc-123-def', 'baggage' => 'sentry-environment=test' } }
      let(:job) { double('Job', metadata: trace_headers) }

      it 'continues the trace from metadata' do
        instance.call(job)

        expect(Sentry).to have_received(:continue_trace).with(
          trace_headers, op: 'queue.process', name: 'TestJob'
        )
        expect(Sentry).not_to have_received(:start_transaction)
      end

      it 'finishes the transaction' do
        instance.call(job)

        expect(transaction).to have_received(:finish)
      end
    end
  end
end
