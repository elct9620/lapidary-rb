# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::HandleWebhook do
  subject(:use_case) { described_class.new(analysis_record_repository: repository) }

  let(:repository) { Lapidary::Container['webhooks.analysis_record_repository'] }

  let(:journals) { [Webhooks::Journal.new(id: 101), Webhooks::Journal.new(id: 102)] }
  let(:issue) { Webhooks::Issue.new(id: 42, journals: journals) }

  describe '#call' do
    it 'saves an analysis record when the issue has not been analyzed' do
      use_case.call(issue)

      record = Webhooks::AnalysisRecord.new(entity_type: 'issue', entity_id: 42)
      expect(repository.exists?(record)).to be true
    end

    it 'does not duplicate when the issue has already been analyzed' do
      use_case.call(issue)
      use_case.call(issue)

      db = Lapidary::Container['database']
      count = db[:analysis_records].where(entity_type: 'issue', entity_id: 42).count
      expect(count).to eq(1)
    end

    it 'tracks untracked journals' do
      use_case.call(issue)

      journal101 = Webhooks::AnalysisRecord.new(entity_type: 'journal', entity_id: 101)
      journal102 = Webhooks::AnalysisRecord.new(entity_type: 'journal', entity_id: 102)
      expect(repository.exists?(journal101)).to be true
      expect(repository.exists?(journal102)).to be true
    end

    it 'does not duplicate already tracked journals' do
      use_case.call(issue)
      use_case.call(issue)

      db = Lapidary::Container['database']
      journal_count = db[:analysis_records].where(entity_type: 'journal').count
      expect(journal_count).to eq(2)
    end

    it 'returns status ok' do
      result = use_case.call(issue)

      expect(result).to eq(status: 'ok')
    end

    it 'propagates AnalysisTrackingError' do
      db = Lapidary::Container['database']
      db.drop_table(:analysis_records)

      expect { use_case.call(issue) }.to raise_error(Webhooks::AnalysisTrackingError)
    end
  end
end
