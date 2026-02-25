# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Edge do
  describe 'construction' do
    it 'creates an edge with source, target, relationship, and observations' do
      edge = described_class.new(
        source: 'rubyist://matz',
        target: 'core_module://String',
        relationship: 'Contribute',
        observations: [{ observed_at: '2024-01-15T10:30:00Z' }]
      )

      expect(edge.source).to eq('rubyist://matz')
      expect(edge.target).to eq('core_module://String')
      expect(edge.relationship).to eq('Contribute')
      expect(edge.observations).to eq([{ observed_at: '2024-01-15T10:30:00Z' }])
    end

    it 'defaults observations to an empty array' do
      edge = described_class.new(
        source: 'rubyist://matz',
        target: 'core_module://String',
        relationship: 'Contribute'
      )

      expect(edge.observations).to eq([])
    end
  end
end
