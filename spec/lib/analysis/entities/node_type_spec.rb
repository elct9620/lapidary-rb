# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::NodeType do
  describe '#to_s' do
    it 'returns the value' do
      expect(described_class::RUBYIST.to_s).to eq('Rubyist')
    end
  end
end
