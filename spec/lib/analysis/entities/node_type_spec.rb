# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::NodeType do
  describe 'constants' do
    it 'defines RUBYIST' do
      expect(described_class::RUBYIST.value).to eq('Rubyist')
    end

    it 'defines CORE_MODULE' do
      expect(described_class::CORE_MODULE.value).to eq('CoreModule')
    end

    it 'defines STDLIB' do
      expect(described_class::STDLIB.value).to eq('Stdlib')
    end
  end

  describe '#to_s' do
    it 'returns the value' do
      expect(described_class::RUBYIST.to_s).to eq('Rubyist')
    end
  end
end
