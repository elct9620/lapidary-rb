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
