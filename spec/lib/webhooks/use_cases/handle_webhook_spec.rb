# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::UseCases::HandleWebhook do
  subject(:use_case) do
    described_class.new(
      analysis_record_repository: analysis_record_repository
    )
  end

  let(:analysis_record_repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }

  let(:journals) { [Webhooks::Entities::Journal.new(id: 101), Webhooks::Entities::Journal.new(id: 102)] }
  let(:issue) { Webhooks::Entities::Issue.new(id: 42, journals: journals) }

  describe '#call' do
    it 'returns untracked issue records' do
      result = use_case.call(issue)

      issue_records = result.select { |r| r.entity_type == 'issue' }
      expect(issue_records.map(&:entity_id)).to eq([42])
    end

    it 'returns untracked journal records' do
      result = use_case.call(issue)

      journal_records = result.select { |r| r.entity_type == 'journal' }
      expect(journal_records.map(&:entity_id)).to contain_exactly(101, 102)
    end

    it 'excludes already tracked entities' do
      # Pre-track the issue
      record = Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)
      analysis_record_repository.save(record)

      result = use_case.call(issue)

      issue_records = result.select { |r| r.entity_type == 'issue' }
      expect(issue_records).to be_empty
    end

    it 'returns an empty array when all entities are tracked' do
      # Pre-track everything
      [['issue', 42], ['journal', 101], ['journal', 102]].each do |type, id|
        record = Webhooks::Entities::AnalysisRecord.new(entity_type: type, entity_id: id, analyzed_at: Time.now)
        analysis_record_repository.save(record)
      end

      result = use_case.call(issue)
      expect(result).to be_empty
    end
  end
end
