# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Webhooks::API do
  include Rack::Test::Methods

  def app
    described_class
  end

  before(:all) do
    Lapidary::Container.finalize!
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
      before do
        post '/webhook',
             'not valid json',
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
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
    end
  end
end
