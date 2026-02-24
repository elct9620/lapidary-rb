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

  let(:journals) { [Webhooks::Entities::Journal.new(id: 101), Webhooks::Entities::Journal.new(id: 102)] }
  let(:issue) { Webhooks::Entities::Issue.new(id: 42, journals: journals) }
  let(:issue_repository) { instance_double(Webhooks::Repositories::IssueRepository, find: issue) }

  describe '#call' do
    it 'fetches the issue from the repository' do
      use_case.call(42)
      expect(issue_repository).to have_received(:find).with(42)
    end

    it 'schedules untracked issue records' do
      use_case.call(42)

      db = Lapidary::Container['database']
      jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
      expect(jobs).to include(entity_type: 'issue', entity_id: 42)
    end

    it 'schedules untracked journal records' do
      use_case.call(42)

      db = Lapidary::Container['database']
      jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
      expect(jobs).to include(entity_type: 'journal', entity_id: 101)
      expect(jobs).to include(entity_type: 'journal', entity_id: 102)
    end

    it 'does not schedule already tracked entities' do
      record = Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)
      analysis_record_repository.save(record)

      use_case.call(42)

      db = Lapidary::Container['database']
      jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
      expect(jobs.select { |j| j[:entity_type] == 'issue' }).to be_empty
    end

    it 'does not schedule anything when all entities are tracked' do
      [['issue', 42], ['journal', 101], ['journal', 102]].each do |type, id|
        record = Webhooks::Entities::AnalysisRecord.new(entity_type: type, entity_id: id, analyzed_at: Time.now)
        analysis_record_repository.save(record)
      end

      use_case.call(42)

      db = Lapidary::Container['database']
      expect(db[:jobs].count).to eq(0)
    end
  end
end
