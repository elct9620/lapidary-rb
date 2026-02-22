# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::HandleWebhook do
  subject(:use_case) { described_class.new(analysis_record_repository: repository) }

  let(:repository) { instance_double(Webhooks::AnalysisRecordRepository) }

  let(:journals) { [Webhooks::Journal.new(id: 101), Webhooks::Journal.new(id: 102)] }
  let(:issue) { Webhooks::Issue.new(id: 42, journals: journals) }

  describe '#call' do
    it 'saves an analysis record when the issue has not been analyzed' do
      allow(repository).to receive(:exists?).and_return(false)
      allow(repository).to receive(:save)
      allow(repository).to receive(:untracked_journal_ids).and_return([])

      use_case.call(issue)

      expect(repository).to have_received(:save) do |record|
        expect(record.entity_type).to eq('issue')
        expect(record.entity_id).to eq(42)
        expect(record).to be_analyzed
      end
    end

    it 'does not save when the issue has already been analyzed' do
      allow(repository).to receive(:exists?).and_return(true)
      allow(repository).to receive(:save)
      allow(repository).to receive(:untracked_journal_ids).and_return([])

      use_case.call(issue)

      expect(repository).not_to have_received(:save)
    end

    it 'tracks untracked journals' do
      allow(repository).to receive(:exists?).and_return(true)
      allow(repository).to receive(:untracked_journal_ids).with([101, 102]).and_return([101, 102])
      allow(repository).to receive(:save)

      use_case.call(issue)

      expect(repository).to have_received(:save).twice
    end

    it 'does not track already tracked journals' do
      allow(repository).to receive(:exists?).and_return(true)
      allow(repository).to receive(:save)
      allow(repository).to receive(:untracked_journal_ids).with([101, 102]).and_return([])

      use_case.call(issue)

      expect(repository).not_to have_received(:save)
    end

    it 'returns status ok' do
      allow(repository).to receive(:exists?).and_return(false)
      allow(repository).to receive(:save)
      allow(repository).to receive(:untracked_journal_ids).and_return([])

      result = use_case.call(issue)

      expect(result).to eq(status: 'ok')
    end

    it 'propagates AnalysisTrackingError' do
      allow(repository).to receive(:exists?).and_raise(Webhooks::AnalysisTrackingError, 'database error')

      expect { use_case.call(issue) }.to raise_error(Webhooks::AnalysisTrackingError, 'database error')
    end
  end
end
