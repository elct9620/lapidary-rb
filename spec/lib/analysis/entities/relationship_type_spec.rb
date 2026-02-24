# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::RelationshipType do
  describe 'constants' do
    it 'defines MAINTENANCE' do
      expect(described_class::MAINTENANCE.value).to eq('Maintenance')
    end

    it 'defines CONTRIBUTE' do
      expect(described_class::CONTRIBUTE.value).to eq('Contribute')
    end
  end

  describe '#to_s' do
    it 'returns the value' do
      expect(described_class::MAINTENANCE.to_s).to eq('Maintenance')
    end
  end
end
