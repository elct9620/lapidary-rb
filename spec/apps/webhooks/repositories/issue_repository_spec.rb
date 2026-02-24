# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Repositories::IssueRepository do
  subject(:repository) { described_class.new(redmine_api: Redmine::API.new) }

  let(:url) { 'https://bugs.ruby-lang.org/issues/42.json?include=journals' }

  describe '#find' do
    let(:response_body) do
      {
        issue: {
          id: 42,
          subject: 'Test issue',
          journals: [
            { id: 101, notes: 'First comment' },
            { id: 102, notes: 'Second comment' }
          ]
        }
      }
    end

    before do
      stub_request(:get, url)
        .to_return(status: 200, body: JSON.generate(response_body), headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an Issue entity' do
      issue = repository.find(42)
      expect(issue).to be_a(Webhooks::Entities::Issue)
      expect(issue.id).to eq(42)
    end

    it 'includes journals' do
      issue = repository.find(42)
      expect(issue.journal_ids).to eq([101, 102])
    end

    context 'when the issue has no journals' do
      let(:response_body) do
        { issue: { id: 42, subject: 'Test issue', journals: [] } }
      end

      it 'returns an Issue with empty journals' do
        issue = repository.find(42)
        expect(issue.journal_ids).to eq([])
      end
    end

    context 'when Redmine API fails' do
      before do
        stub_request(:get, url).to_return(status: 503, body: 'Service Unavailable')
      end

      it 'wraps as IssueFetchError' do
        expect { repository.find(42) }.to raise_error(Webhooks::Entities::IssueFetchError)
      end
    end
  end
end
