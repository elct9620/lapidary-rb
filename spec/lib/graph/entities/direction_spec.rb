# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Direction do
  describe '#to_s' do
    it 'converts to string as "outbound"' do
      expect(described_class::OUTBOUND.to_s).to eq('outbound')
    end

    it 'converts to string as "inbound"' do
      expect(described_class::INBOUND.to_s).to eq('inbound')
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

  describe '.parse' do
    it 'returns OUTBOUND for "outbound"' do
      expect(described_class.parse('outbound')).to eq(described_class::OUTBOUND)
    end

    it 'returns INBOUND for "inbound"' do
      expect(described_class.parse('inbound')).to eq(described_class::INBOUND)
    end

    it 'returns BOTH for "both"' do
      expect(described_class.parse('both')).to eq(described_class::BOTH)
    end

    it 'returns BOTH for nil' do
      expect(described_class.parse(nil)).to eq(described_class::BOTH)
    end

    it 'raises ArgumentError for unknown values' do
      expect { described_class.parse('foobar') }.to raise_error(ArgumentError, 'unknown direction: foobar')
    end
  end
end
