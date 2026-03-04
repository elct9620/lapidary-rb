# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Lapidary::BaseController do
  include Rack::Test::Methods

  let(:test_app) do
    Class.new(described_class) do
      get '/explode' do
        raise StandardError, 'something went wrong'
      end
    end
  end

  def app
    test_app
  end

  describe 'not found handler' do
    before do
      get '/nonexistent'
    end

    it 'returns 404 status' do
      expect(last_response.status).to eq(404)
    end

    it 'returns JSON content type' do
      expect(last_response.content_type).to include('application/json')
    end

    it 'returns error message in JSON body' do
      body = JSON.parse(last_response.body)
      expect(body).to eq('error' => 'not found')
    end
  end

  describe '#dispatch_background' do
    let(:controller) { described_class.allocate }

    context 'when not inside Async' do
      it 'yields directly' do
        executed = false

        controller.dispatch_background { executed = true }

        expect(executed).to be true
      end
    end

    context 'when inside Async' do
      let(:async_task_stub) do
        Class.new do
          def self.current? = true
        end
      end

      before do
        stub_const('Async::Task', async_task_stub)
      end

      it 'yields the block when Sentry is not initialized' do
        allow(Sentry).to receive(:initialized?).and_return(false)
        executed = false

        allow(controller).to receive(:Async) { |**_opts, &block| block.call }

        controller.dispatch_background { executed = true }

        expect(executed).to be true
      end

      it 'wraps in a continuation transaction when Sentry is initialized' do
        trace_headers = { 'sentry-trace' => 'abc-123', 'baggage' => 'env=test' }
        continued_transaction = double('ContinuedTransaction')
        transaction = double('Transaction', finish: nil)
        scope = double('Scope', set_span: nil)

        allow(Sentry).to receive(:initialized?).and_return(true)
        allow(Sentry).to receive(:get_trace_propagation_headers).and_return(trace_headers)
        allow(Sentry).to receive(:continue_trace).and_return(continued_transaction)
        allow(Sentry).to receive(:start_transaction).and_return(transaction)
        allow(Sentry).to receive(:get_current_scope).and_return(scope)
        allow(controller).to receive(:Async) { |**_opts, &block| block.call }

        controller.dispatch_background { nil }

        expect(Sentry).to have_received(:continue_trace).with(
          trace_headers, op: 'background.process', name: described_class.name
        )
        expect(Sentry).to have_received(:start_transaction).with(transaction: continued_transaction)
        expect(transaction).to have_received(:finish)
      end
    end
  end

  describe 'global error handler' do
    before do
      get '/explode'
    end

    it 'returns 500 status' do
      expect(last_response.status).to eq(500)
    end

    it 'returns JSON content type' do
      expect(last_response.content_type).to include('application/json')
    end

    it 'returns error message in JSON body' do
      body = JSON.parse(last_response.body)
      expect(body).to eq('error' => 'internal server error')
    end
  end
end
