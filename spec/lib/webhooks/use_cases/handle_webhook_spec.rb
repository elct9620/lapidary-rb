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

  let(:analysis_record_repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }
  let(:analysis_scheduler) { Lapidary::Container['webhooks.adapters.analysis_scheduler'] }

  let(:journals) do
    [
      Webhooks::Entities::Journal.new(
        id: 101, notes: 'First comment',
        author: Webhooks::Entities::Author.new(username: 'nobu', display_name: 'Nobuyoshi Nakada'),
        created_on: '2024-01-16T08:00:00Z'
      ),
      Webhooks::Entities::Journal.new(
        id: 102, notes: 'Second comment',
        author: Webhooks::Entities::Author.new(username: 'ko1', display_name: 'Koichi Sasada'),
        created_on: '2024-01-17T09:00:00Z'
      )
    ]
  end
  let(:issue) do
    Webhooks::Entities::Issue.new(
      id: 42, subject: 'Add new feature',
      author: Webhooks::Entities::Author.new(username: 'matz', display_name: 'Yukihiro Matsumoto'),
      created_on: '2024-01-15T10:30:00Z',
      journals: journals
    )
  end
  let(:issue_repository) { instance_double(Webhooks::Repositories::IssueRepository, find: issue) }

  describe '#call' do
    it 'fetches the issue from the repository' do
      use_case.call(42)
      expect(issue_repository).to have_received(:find).with(42)
    end

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
        content: 'Add new feature',
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
        issue_content: 'Add new feature',
        created_on: '2024-01-16T08:00:00Z'
      )
      expect(jobs).to include(
        entity_type: 'journal',
        entity_id: 102,
        content: 'Second comment',
        author_username: 'ko1',
        author_display_name: 'Koichi Sasada',
        issue_id: 42,
        issue_content: 'Add new feature',
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

    context 'when entity type is unknown' do
      let(:analysis_record_repository) do
        repo = Lapidary::Container['webhooks.repositories.analysis_record_repository']
        allow(repo).to receive(:untracked).and_return(
          [Webhooks::Entities::AnalysisRecord.new(entity_type: Webhooks::Entities::EntityType.new(value: 'unknown'),
                                                  entity_id: 99)]
        )
        repo
      end

      it 'raises ArgumentError' do
        expect { use_case.call(42) }.to raise_error(ArgumentError, /unknown entity type/)
      end
    end

    context 'when journal ID is not found in issue' do
      let(:analysis_record_repository) do
        repo = Lapidary::Container['webhooks.repositories.analysis_record_repository']
        allow(repo).to receive(:untracked).and_return(
          [Webhooks::Entities::AnalysisRecord.new(entity_type: Webhooks::Entities::EntityType::JOURNAL,
                                                  entity_id: 999)]
        )
        repo
      end

      it 'raises ArgumentError' do
        expect { use_case.call(42) }.to raise_error(ArgumentError, /journal 999 not found/)
      end
    end
  end
end
