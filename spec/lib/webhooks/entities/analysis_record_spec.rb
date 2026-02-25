# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Entities::AnalysisRecord do
  subject(:record) { described_class.new(entity_type: 'issue', entity_id: 42) }

  describe '#initialize' do
    it 'sets entity_type and entity_id' do
      expect(record).to have_attributes(entity_type: 'issue', entity_id: 42)
    end
  end

  describe '#entity_type' do
    it 'returns the entity type' do
      expect(record.entity_type).to eq('issue')
    end
  end

  describe '#entity_id' do
    it 'returns the entity id' do
      expect(record.entity_id).to eq(42)
    end
  end
end
