# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::RetentionPeriod do
  describe '.parse' do
    it 'parses days format' do
      period = described_class.parse('7d')
      expect(period.amount).to eq(7)
      expect(period.unit).to eq('d')
    end

    it 'parses hours format' do
      period = described_class.parse('12h')
      expect(period.amount).to eq(12)
      expect(period.unit).to eq('h')
    end

    it 'parses single digit amounts' do
      period = described_class.parse('1d')
      expect(period.amount).to eq(1)
      expect(period.unit).to eq('d')
    end

    it 'returns nil for invalid format' do
      expect(described_class.parse('invalid')).to be_nil
    end

    it 'returns nil for unsupported units' do
      expect(described_class.parse('7m')).to be_nil
    end

    it 'returns nil for empty string' do
      expect(described_class.parse('')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.parse(nil)).to be_nil
    end
  end

  describe '.default' do
    it 'returns 7 days' do
      period = described_class.default
      expect(period.amount).to eq(7)
      expect(period.unit).to eq('d')
    end
  end

  describe '.graph_default' do
    it 'returns 180 days' do
      period = described_class.graph_default
      expect(period.amount).to eq(180)
      expect(period.unit).to eq('d')
    end
  end

  describe '#cutoff' do
    it 'computes cutoff for days' do
      period = described_class.new(amount: 7, unit: 'd')
      now = Time.new(2026, 1, 15, 12, 0, 0)

      cutoff = period.cutoff(now: now)

      expect(cutoff).to eq(now - (7 * 86_400))
    end

    it 'computes cutoff for hours' do
      period = described_class.new(amount: 12, unit: 'h')
      now = Time.new(2026, 1, 15, 12, 0, 0)

      cutoff = period.cutoff(now: now)

      expect(cutoff).to eq(now - (12 * 3600))
    end
  end

  describe '#to_s' do
    it 'returns the formatted string' do
      period = described_class.new(amount: 7, unit: 'd')
      expect(period.to_s).to eq('7d')
    end

    it 'returns hours format' do
      period = described_class.new(amount: 12, unit: 'h')
      expect(period.to_s).to eq('12h')
    end
  end
end
