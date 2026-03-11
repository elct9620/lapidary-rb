# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::UseCases::HandleWebhook do
  subject(:use_case) do
    described_class.new(
      issue_repository: issue_repository,
      analysis_record_repository: analysis_record_repository,
      analysis_scheduler: analysis_scheduler
    )
  end

  let(:issue_repository) { Lapidary::Container['webhooks.repositories.issue_repository'] }
  let(:analysis_record_repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }
  let(:analysis_scheduler) { Lapidary::Container['webhooks.adapters.analysis_scheduler'] }

  let(:redmine_api_url) { 'https://bugs.ruby-lang.org/issues/42.json?include=journals' }
  let(:redmine_response) do
    {
      issue: {
        id: 42,
        subject: 'Add new feature',
        description: 'Detailed description of the new feature',
        author: { id: 1, name: 'matz (Yukihiro Matsumoto)' },
        created_on: '2024-01-15T10:30:00Z',
        journals: [
          { id: 101, user: { id: 2, name: 'nobu (Nobuyoshi Nakada)' },
            notes: 'First comment', created_on: '2024-01-16T08:00:00Z' },
          { id: 102, user: { id: 3, name: 'ko1 (Koichi Sasada)' },
            notes: 'Second comment', created_on: '2024-01-17T09:00:00Z' }
        ]
      }
    }
  end

  before do
    stub_request(:get, redmine_api_url)
      .to_return(status: 200, body: JSON.generate(redmine_response),
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#call' do
    it 'schedules untracked issue records with rich arguments' do
      use_case.call(42)

      db = Lapidary::Container['database']
      jobs = db[:jobs].all.map do |r|
        JSON.parse(r[:arguments], symbolize_names: true).reject do |k, _|
          k.start_with?('_')
        end
      end
      expect(jobs).to include(
        entity_type: 'issue',
        entity_id: 42,
        title: 'Add new feature',
        content: 'Detailed description of the new feature',
        author_username: 'matz',
        author_display_name: 'Yukihiro Matsumoto',
        created_on: '2024-01-15T10:30:00Z'
      )
    end

    it 'schedules untracked journal records with rich arguments' do
      use_case.call(42)

      db = Lapidary::Container['database']
      jobs = db[:jobs].all.map do |r|
        JSON.parse(r[:arguments], symbolize_names: true).reject do |k, _|
          k.start_with?('_')
        end
      end
      expect(jobs).to include(
        entity_type: 'journal',
        entity_id: 101,
        content: 'First comment',
        author_username: 'nobu',
        author_display_name: 'Nobuyoshi Nakada',
        issue_id: 42,
        issue_title: 'Add new feature',
        issue_content: 'Detailed description of the new feature',
        issue_author_username: 'matz',
        issue_author_display_name: 'Yukihiro Matsumoto',
        created_on: '2024-01-16T08:00:00Z'
      )
      expect(jobs).to include(
        entity_type: 'journal',
        entity_id: 102,
        content: 'Second comment',
        author_username: 'ko1',
        author_display_name: 'Koichi Sasada',
        issue_id: 42,
        issue_title: 'Add new feature',
        issue_content: 'Detailed description of the new feature',
        issue_author_username: 'matz',
        issue_author_display_name: 'Yukihiro Matsumoto',
        created_on: '2024-01-17T09:00:00Z'
      )
    end

    it 'does not schedule already tracked entities' do
      db = Lapidary::Container['database']
      db[:analysis_records].insert(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)

      use_case.call(42)

      jobs = db[:jobs].all.map do |r|
        JSON.parse(r[:arguments], symbolize_names: true).reject do |k, _|
          k.start_with?('_')
        end
      end
      expect(jobs.select { |j| j[:entity_type] == 'issue' }).to be_empty
    end

    it 'does not schedule anything when all entities are tracked' do
      db = Lapidary::Container['database']
      [['issue', 42], ['journal', 101], ['journal', 102]].each do |type, id|
        db[:analysis_records].insert(entity_type: type, entity_id: id, analyzed_at: Time.now)
      end

      use_case.call(42)

      expect(db[:jobs].count).to eq(0)
    end

    it 'returns the number of scheduled jobs' do
      count = use_case.call(42)

      expect(count).to eq(3)
    end

    context 'with force: true' do
      it 'schedules all entities even when already tracked' do
        db = Lapidary::Container['database']
        [['issue', 42], ['journal', 101], ['journal', 102]].each do |type, id|
          db[:analysis_records].insert(entity_type: type, entity_id: id, analyzed_at: Time.now)
        end

        count = use_case.call(42, force: true)

        expect(count).to eq(3)
        expect(db[:jobs].count).to eq(3)
      end
    end
  end
end
