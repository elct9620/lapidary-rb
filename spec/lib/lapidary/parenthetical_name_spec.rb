# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::ParentheticalName do
  describe '.parse' do
    it 'extracts username and display name from parenthetical format' do
      result = described_class.parse('matz (Yukihiro Matsumoto)')

      expect(result).to eq(['matz', 'Yukihiro Matsumoto'])
    end

    it 'strips whitespace around both components' do
      result = described_class.parse('st0012   (  Stan Lo  )')

      expect(result).to eq(['st0012', 'Stan Lo'])
    end

    it 'returns nil when no parenthetical is present' do
      expect(described_class.parse('matz')).to be_nil
    end

    it 'handles nested parentheses by matching outermost' do
      result = described_class.parse('user (Name (Nickname))')

      expect(result).to eq(['user', 'Name (Nickname)'])
    end
  end

  describe '::PATTERN' do
    it 'matches parenthetical format' do
      expect(described_class::PATTERN).to match('matz (Yukihiro Matsumoto)')
    end

    it 'does not match plain names' do
      expect(described_class::PATTERN).not_to match('matz')
    end
  end
end
