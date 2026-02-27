# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::NodeId do
  describe '.build' do
    it 'converts PascalCase type to snake_case slug' do
      expect(described_class.build('CoreModule', 'String')).to eq('core_module://String')
    end

    it 'handles single-word types' do
      expect(described_class.build('Rubyist', 'matz')).to eq('rubyist://matz')
    end

    it 'preserves name as-is' do
      expect(described_class.build('Feature', 'pattern matching')).to eq('feature://pattern matching')
    end
  end

  describe '.valid?' do
    it 'returns true for valid node IDs' do
      expect(described_class.valid?('core_module://String')).to be true
      expect(described_class.valid?('rubyist://matz')).to be true
    end

    it 'returns false for invalid node IDs' do
      expect(described_class.valid?('CoreModule://String')).to be false
      expect(described_class.valid?('://missing_type')).to be false
      expect(described_class.valid?('no_separator')).to be false
    end
  end

  describe '.build' do
    it 'raises ArgumentError for empty name' do
      expect { described_class.build('Rubyist', '') }.to raise_error(ArgumentError, /invalid node ID/)
    end
  end

  describe 'FORMAT' do
    it 'matches valid node IDs' do
      expect(described_class::FORMAT).to match('core_module://String')
      expect(described_class::FORMAT).to match('rubyist://matz')
    end

    it 'rejects invalid node IDs' do
      expect(described_class::FORMAT).not_to match('CoreModule://String')
      expect(described_class::FORMAT).not_to match('://missing_type')
      expect(described_class::FORMAT).not_to match('no_separator')
    end
  end
end
