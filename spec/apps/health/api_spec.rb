# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Health::API do
  include Rack::Test::Methods

  def app
    described_class
  end

  before(:all) do
    Lapidary::Container.finalize!
  end

  describe 'GET /' do
    before { get '/' }

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
end
