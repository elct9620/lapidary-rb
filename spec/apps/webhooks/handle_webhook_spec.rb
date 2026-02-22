# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::HandleWebhook do
  subject(:use_case) { described_class.new(analysis_record_repository: repository) }

  let(:repository) { instance_double(Webhooks::AnalysisRecordRepository) }

  describe '#call' do
    it 'saves an analysis record when the issue has not been analyzed' do
      allow(repository).to receive(:exists?).and_return(false)
      allow(repository).to receive(:save)

      use_case.call(42)

      expect(repository).to have_received(:save) do |record|
        expect(record.entity_type).to eq('issue')
        expect(record.entity_id).to eq(42)
        expect(record).to be_analyzed
      end
    end

    it 'does not save when the issue has already been analyzed' do
      allow(repository).to receive(:exists?).and_return(true)
      allow(repository).to receive(:save)

      use_case.call(42)

      expect(repository).not_to have_received(:save)
    end

    it 'returns status ok' do
      allow(repository).to receive(:exists?).and_return(false)
      allow(repository).to receive(:save)

      result = use_case.call(1)

      expect(result).to eq(status: 'ok')
    end

    it 'returns status ok even when repository raises' do
      allow(repository).to receive(:exists?).and_raise(StandardError, 'database error')

      result = use_case.call(1)

      expect(result).to eq(status: 'ok')
    end
  end
end
