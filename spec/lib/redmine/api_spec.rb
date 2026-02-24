# frozen_string_literal: true

require 'spec_helper'

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

    context 'with default timeout configuration' do
      let(:response) { Net::HTTPSuccess.new('1.1', '200', 'OK') }
      let(:http_double) { instance_double(Net::HTTP) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:request).and_return(response)
        allow(response).to receive(:body).and_return('{}')
      end

      it 'sets open_timeout to 10 seconds' do
        api.fetch_issue(issue_id)
        expect(http_double).to have_received(:open_timeout=).with(10)
      end

      it 'sets read_timeout to 10 seconds' do
        api.fetch_issue(issue_id)
        expect(http_double).to have_received(:read_timeout=).with(10)
      end
    end

    context 'with custom timeout configuration' do
      subject(:api) { described_class.new(open_timeout: 5, read_timeout: 15) }

      let(:response) { Net::HTTPSuccess.new('1.1', '200', 'OK') }
      let(:http_double) { instance_double(Net::HTTP) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:request).and_return(response)
        allow(response).to receive(:body).and_return('{}')
      end

      it 'sets open_timeout to custom value' do
        api.fetch_issue(issue_id)
        expect(http_double).to have_received(:open_timeout=).with(5)
      end

      it 'sets read_timeout to custom value' do
        api.fetch_issue(issue_id)
        expect(http_double).to have_received(:read_timeout=).with(15)
      end
    end

    context 'with a custom base_url' do
      subject(:api) { described_class.new(base_url: 'https://custom.redmine.org') }

      let(:custom_url) { "https://custom.redmine.org/issues/#{issue_id}.json?include=journals" }

      before do
        stub_request(:get, custom_url)
          .to_return(status: 200, body: JSON.generate({ issue: { id: issue_id } }),
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'uses the custom base URL' do
        result = api.fetch_issue(issue_id)
        expect(result['issue']['id']).to eq(issue_id)
      end
    end
  end
end
