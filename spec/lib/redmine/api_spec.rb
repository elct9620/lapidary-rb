# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/redmine/api'

RSpec.describe Redmine::API do
  subject(:api) { described_class.new }

  let(:issue_id) { 42 }
  let(:url) { "https://bugs.ruby-lang.org/issues/#{issue_id}.json?include=journals" }

  describe '#fetch_issue' do
    context 'when the API responds successfully' do
      let(:response_body) do
        {
          issue: {
            id: issue_id,
            subject: 'Test issue',
            journals: [
              { id: 1, notes: 'First comment' },
              { id: 2, notes: 'Second comment' }
            ]
          }
        }
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: JSON.generate(response_body), headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns parsed issue data' do
        result = api.fetch_issue(issue_id)
        expect(result['issue']['id']).to eq(issue_id)
      end

      it 'includes journals in the response' do
        result = api.fetch_issue(issue_id)
        expect(result['issue']['journals'].length).to eq(2)
      end
    end

    context 'when the API responds with a non-200 status' do
      before do
        stub_request(:get, url)
          .to_return(status: 404, body: 'Not Found')
      end

      it 'raises FetchError' do
        expect { api.fetch_issue(issue_id) }.to raise_error(Redmine::API::FetchError)
      end

      it 'includes URL and status code in error message' do
        expect { api.fetch_issue(issue_id) }.to raise_error(/404/)
      end
    end

    context 'when a network error occurs' do
      before do
        stub_request(:get, url).to_timeout
      end

      it 'raises FetchError' do
        expect { api.fetch_issue(issue_id) }.to raise_error(Redmine::API::FetchError)
      end
    end

    context 'when connection is refused' do
      before do
        stub_request(:get, url).to_raise(Errno::ECONNREFUSED)
      end

      it 'raises FetchError' do
        expect { api.fetch_issue(issue_id) }.to raise_error(Redmine::API::FetchError)
      end
    end
  end
end
