# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::HandleWebhook do
  subject(:use_case) { described_class.new(analysis_record_repository: repository) }

  let(:repository) { instance_double(Webhooks::AnalysisRecordRepository) }

  describe '#call' do
    it 'creates an analysis record for the issue' do
      allow(repository).to receive(:create_if_absent)

      use_case.call(42)

      expect(repository).to have_received(:create_if_absent).with(entity_type: 'issue', entity_id: 42)
    end

    it 'returns status ok' do
      allow(repository).to receive(:create_if_absent)

      result = use_case.call(1)

      expect(result).to eq(status: 'ok')
    end

    it 'returns status ok even when repository raises' do
      allow(repository).to receive(:create_if_absent).and_raise(StandardError, 'database error')

      result = use_case.call(1)

      expect(result).to eq(status: 'ok')
    end
  end
end
