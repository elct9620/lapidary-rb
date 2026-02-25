# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Direction do
  describe '::OUTBOUND' do
    it 'has value "outbound"' do
      expect(described_class::OUTBOUND.value).to eq('outbound')
    end

    it 'converts to string as "outbound"' do
      expect(described_class::OUTBOUND.to_s).to eq('outbound')
    end
  end

  describe '::INBOUND' do
    it 'has value "inbound"' do
      expect(described_class::INBOUND.value).to eq('inbound')
    end

    it 'converts to string as "inbound"' do
      expect(described_class::INBOUND.to_s).to eq('inbound')
    end
  end

  describe '::BOTH' do
    it 'has value "both"' do
      expect(described_class::BOTH.value).to eq('both')
    end

    it 'converts to string as "both"' do
      expect(described_class::BOTH.to_s).to eq('both')
    end
  end

  describe 'equality' do
    it 'is equal when values match' do
      expect(described_class.new(value: 'outbound')).to eq(described_class::OUTBOUND)
    end

    it 'is not equal when values differ' do
      expect(described_class::OUTBOUND).not_to eq(described_class::INBOUND)
    end
  end
end
