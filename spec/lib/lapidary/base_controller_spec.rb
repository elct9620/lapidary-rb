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
