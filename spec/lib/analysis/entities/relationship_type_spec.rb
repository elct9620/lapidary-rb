# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::RelationshipType do
  describe '#to_s' do
    it 'returns the value' do
      expect(described_class::MAINTENANCE.to_s).to eq('Maintenance')
    end
  end
end
