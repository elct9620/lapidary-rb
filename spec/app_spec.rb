# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../config/web'

RSpec.describe Lapidary::Web do
  include Rack::Test::Methods

  def app
    described_class
  end

  before(:all) do
    Lapidary::Container.finalize!
  end

  describe 'GET /' do
    it 'returns Hello World' do
      get '/'

      expect(last_response).to be_ok
      expect(last_response.body).to eq('Hello World')
    end
  end
end
