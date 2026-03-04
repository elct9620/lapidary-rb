# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/sentry/queue_patch'

RSpec.describe Lapidary::Sentry::QueuePatch do
  let(:host_class) do
    Class.new do
      def process_job(use_case, job)
        use_case.call(job)
      end
    end
  end

  let(:patched_class) do
    klass = host_class
    klass.prepend(described_class)
    klass
  end

  let(:instance) { patched_class.new }
  let(:use_case) { double('UseCase', call: nil) }
  let(:job) { double('Job') }

  context 'when Sentry is not initialized' do
    before do
      allow(Sentry).to receive(:initialized?).and_return(false)
      allow(Sentry).to receive(:start_transaction)
    end

    it 'delegates to the original method without instrumentation' do
      instance.process_job(use_case, job)

      expect(use_case).to have_received(:call).with(job)
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

    it 'wraps the call in a queue.process transaction' do
      instance.process_job(use_case, job)

      expect(Sentry).to have_received(:start_transaction).with(
        op: 'queue.process', name: 'analysis.process_job'
      )
    end

    it 'sets the transaction on the current scope' do
      instance.process_job(use_case, job)

      expect(scope).to have_received(:set_span).with(transaction)
    end

    it 'sets the messaging destination' do
      instance.process_job(use_case, job)

      expect(transaction).to have_received(:set_data).with(
        Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME,
        'analysis.jobs'
      )
    end

    it 'finishes the transaction' do
      instance.process_job(use_case, job)

      expect(transaction).to have_received(:finish)
    end

    it 'finishes the transaction even on error' do
      allow(use_case).to receive(:call).and_raise(RuntimeError, 'boom')

      expect { instance.process_job(use_case, job) }.to raise_error(RuntimeError, 'boom')
      expect(transaction).to have_received(:finish)
    end
  end
end
