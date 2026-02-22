# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Webhooks::API do
  include Rack::Test::Methods

  def app
    described_class
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
      before do
        repository = Lapidary::Container['webhooks.analysis_record_repository']
        allow(repository).to receive(:exists?).and_raise(Webhooks::AnalysisTrackingError, 'database error')

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'still returns 200 OK' do
        expect(last_response).to be_ok
      end

      it 'still returns status ok' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('status' => 'ok')
      end
    end

    context 'when migration has not been run' do
      before do
        database = Lapidary::Container['database']
        database.drop_table(:analysis_records)

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'still returns 200 OK' do
        expect(last_response).to be_ok
      end

      it 'still returns status ok' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('status' => 'ok')
      end
    end

    context 'with non-JSON Content-Type' do
      before do
        post '/webhook',
             'issue_id=1',
             'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
      end

      it 'returns 415 Unsupported Media Type' do
        expect(last_response.status).to eq(415)
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

      it 'logs a warning' do
        expect(mock_logger).to have_received(:warn).with(
          anything,
          'Invalid JSON in webhook request',
          instance_of(JSON::ParserError)
        )
      end
    end

    context 'with missing issue_id' do
      before do
        post '/webhook',
             JSON.generate(other: 'data'),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('issue_id')
      end
    end

    context 'with issue_id as zero' do
      before do
        post '/webhook',
             JSON.generate(issue_id: 0),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('issue_id')
      end
    end

    context 'with negative issue_id' do
      before do
        post '/webhook',
             JSON.generate(issue_id: -1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('issue_id')
      end
    end

    context 'with issue_id as string' do
      before do
        post '/webhook',
             JSON.generate(issue_id: 'abc'),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('issue_id')
      end
    end
  end
end
