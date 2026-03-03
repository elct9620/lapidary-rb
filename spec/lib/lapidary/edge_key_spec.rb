# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::EdgeKey do
  subject(:key) do
    described_class.new(source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute')
  end

  describe '#to_where' do
    it 'returns a hash for edge table queries' do
      expect(key.to_where).to eq(source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute')
    end
  end

  describe '#to_observation_where' do
    it 'returns a hash for observation table queries' do
      expect(key.to_observation_where).to eq(
        edge_source: 'rubyist://matz', edge_target: 'core_module://String', edge_relationship: 'Contribute'
      )
    end
  end

  describe '#to_a' do
    it 'returns an array of [source, target, relationship]' do
      expect(key.to_a).to eq(['rubyist://matz', 'core_module://String', 'Contribute'])
    end
  end

  describe '.from_edge_row' do
    it 'builds from an edge table row hash' do
      row = { source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
              created_at: Time.now }
      result = described_class.from_edge_row(row)

      expect(result).to eq(key)
    end
  end

  describe '.from_observation_row' do
    it 'builds from an observation table row hash' do
      row = { edge_source: 'rubyist://matz', edge_target: 'core_module://String',
              edge_relationship: 'Contribute', observed_at: Time.now }
      result = described_class.from_observation_row(row)

      expect(result).to eq(key)
    end
  end
end
