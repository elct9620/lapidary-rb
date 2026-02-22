# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Webhooks::API do
  include Rack::Test::Methods

  def app
    described_class
  end

  shared_examples 'a validation error' do
    it 'returns 422 Unprocessable Entity' do
      expect(last_response.status).to eq(422)
    end

    it 'returns JSON error body' do
      body = JSON.parse(last_response.body)
      expect(body['errors']).to have_key('issue_id')
    end
  end

  describe 'POST /webhook' do
    context 'with a valid request' do
      before do
        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 200 OK' do
        expect(last_response).to be_ok
      end

      it 'returns JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'returns status ok' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('status' => 'ok')
      end

      it 'tracks the issue as analyzed' do
        repository = Lapidary::Container['webhooks.analysis_record_repository']
        record = Webhooks::AnalysisRecord.new(entity_type: 'issue', entity_id: 1)
        expect(repository.exists?(record)).to be true
      end
    end

    context 'when analysis tracking fails' do
      let(:mock_logger) { Lapidary::Container['logger'] }
      let(:stubbed_repository) do
        repo = instance_double(Webhooks::AnalysisRecordRepository)
        allow(repo).to receive(:exists?).and_raise(Webhooks::AnalysisTrackingError, 'database error')
        repo
      end

      before do
        allow(mock_logger).to receive(:error)
        Lapidary::Container.stub('webhooks.analysis_record_repository', stubbed_repository)

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      after do
        Lapidary::Container.unstub('webhooks.analysis_record_repository')
      end

      it 'returns 500 Internal Server Error' do
        expect(last_response.status).to eq(500)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'internal server error')
      end
    end

    context 'when migration has not been run' do
      let(:mock_logger) { Lapidary::Container['logger'] }

      before do
        allow(mock_logger).to receive(:error)

        database = Lapidary::Container['database']
        database.drop_table(:analysis_records)

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 500 Internal Server Error' do
        expect(last_response.status).to eq(500)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'internal server error')
      end
    end

    context 'with non-JSON Content-Type' do
      let(:mock_logger) { Lapidary::Container['logger'] }

      before do
        allow(mock_logger).to receive(:warn)

        post '/webhook',
             'issue_id=1',
             'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
      end

      it 'returns 415 Unsupported Media Type' do
        expect(last_response.status).to eq(415)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'Content-Type must be application/json')
      end

      it 'logs a warning' do
        expect(mock_logger).to have_received(:warn).with(
          anything,
          'Rejected webhook with unsupported Content-Type'
        )
      end
    end

    context 'with invalid JSON body' do
      let(:mock_logger) { Lapidary::Container['logger'] }

      before do
        allow(mock_logger).to receive(:warn)

        post '/webhook',
             'not valid json',
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'invalid JSON')
      end

      it 'logs a warning' do
        expect(mock_logger).to have_received(:warn).with(
          anything,
          'Invalid JSON in webhook request',
          instance_of(JSON::ParserError)
        )
      end
    end

    context 'with missing issue_id' do
      before { post '/webhook', JSON.generate(other: 'data'), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with issue_id as zero' do
      before { post '/webhook', JSON.generate(issue_id: 0), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with negative issue_id' do
      before { post '/webhook', JSON.generate(issue_id: -1), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with issue_id as string' do
      before { post '/webhook', JSON.generate(issue_id: 'abc'), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end
  end
end
