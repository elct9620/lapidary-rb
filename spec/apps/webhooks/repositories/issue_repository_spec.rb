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
          subject: 'Add new feature',
          author: { id: 1, name: 'matz (Yukihiro Matsumoto)' },
          created_on: '2024-01-15T10:30:00Z',
          journals: [
            { id: 101, user: { id: 2, name: 'nobu (Nobuyoshi Nakada)' }, notes: 'First comment',
              created_on: '2024-01-16T08:00:00Z' },
            { id: 102, user: { id: 3, name: 'ko1 (Koichi Sasada)' }, notes: 'Second comment',
              created_on: '2024-01-17T09:00:00Z' }
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

    it 'extracts the subject' do
      issue = repository.find(42)
      expect(issue.subject).to eq('Add new feature')
    end

    it 'parses author username and display name' do
      issue = repository.find(42)
      expect(issue.author.username).to eq('matz')
      expect(issue.author.display_name).to eq('Yukihiro Matsumoto')
    end

    it 'extracts created_on from the issue' do
      issue = repository.find(42)
      expect(issue.created_on).to eq('2024-01-15T10:30:00Z')
    end

    it 'includes journals with notes and author info' do
      issue = repository.find(42)
      journal = issue.journals.first
      expect(journal.id).to eq(101)
      expect(journal.notes).to eq('First comment')
      expect(journal.author.username).to eq('nobu')
      expect(journal.author.display_name).to eq('Nobuyoshi Nakada')
    end

    it 'extracts created_on from journals' do
      issue = repository.find(42)
      expect(issue.journals.first.created_on).to eq('2024-01-16T08:00:00Z')
      expect(issue.journals.last.created_on).to eq('2024-01-17T09:00:00Z')
    end

    it 'includes all journal ids' do
      issue = repository.find(42)
      expect(issue.journal_ids).to eq([101, 102])
    end

    context 'when author name has no display name' do
      let(:response_body) do
        {
          issue: {
            id: 42,
            subject: 'Test',
            author: { id: 1, name: 'matz' },
            journals: []
          }
        }
      end

      it 'sets display name to nil' do
        issue = repository.find(42)
        expect(issue.author.username).to eq('matz')
        expect(issue.author.display_name).to be_nil
      end
    end

    context 'when journal user has no display name' do
      let(:response_body) do
        {
          issue: {
            id: 42,
            subject: 'Test',
            author: { id: 1, name: 'matz' },
            journals: [
              { id: 101, user: { id: 2, name: 'nobu' }, notes: 'A comment' }
            ]
          }
        }
      end

      it 'sets journal author display name to nil' do
        issue = repository.find(42)
        journal = issue.journals.first
        expect(journal.author.username).to eq('nobu')
        expect(journal.author.display_name).to be_nil
      end
    end

    context 'when author name is nil' do
      let(:response_body) do
        {
          issue: {
            id: 42,
            subject: 'Test',
            author: { id: 1, name: nil },
            journals: []
          }
        }
      end

      it 'returns nil for the author' do
        issue = repository.find(42)
        expect(issue.author).to be_nil
      end
    end

    context 'when the issue has no journals' do
      let(:response_body) do
        { issue: { id: 42, subject: 'Test issue', author: { id: 1, name: 'matz' }, journals: [] } }
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
