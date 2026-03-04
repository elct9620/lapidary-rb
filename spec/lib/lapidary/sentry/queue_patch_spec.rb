# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/sentry/queue_patch'

RSpec.describe Lapidary::Sentry::QueuePatch do
  let(:host_class) do
    Class.new(Lapidary::Analysis::BaseJob) do
      def self.name = 'TestJob'

      def call(job)
        job
      end
    end
  end

  let(:patched_class) do
    klass = host_class
    klass.prepend(described_class)
    klass
  end

  let(:instance) { patched_class.new }
  let(:job) { double('Job') }

  context 'when Sentry is not initialized' do
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
      allow(Sentry).to receive(:get_current_scope).and_return(scope)
      allow(transaction).to receive(:set_data)
    end

    it 'wraps the call in a queue.process transaction with job-type name' do
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
      allow(instance).to receive(:call).and_call_original
      host_class.define_method(:call) { |_job| raise 'boom' }

      expect { instance.call(job) }.to raise_error(RuntimeError, 'boom')
      expect(transaction).to have_received(:finish)
    end
  end
end
