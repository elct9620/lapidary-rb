# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::AnalysisRecord do
  subject(:record) { described_class.new(entity_type: 'issue', entity_id: 42) }

  describe '#initialize' do
    it 'defaults analyzed_at to nil' do
      expect(record.analyzed_at).to be_nil
    end
  end

  describe '#analyze' do
    it 'sets analyzed_at to current time' do
      freeze_time = Time.now
      record.analyze(now: freeze_time)
      expect(record.analyzed_at).to eq(freeze_time)
    end

    it 'uses provided time via now: parameter' do
      custom_time = Time.new(2025, 1, 1, 12, 0, 0)
      record.analyze(now: custom_time)
      expect(record.analyzed_at).to eq(custom_time)
    end
  end
end
