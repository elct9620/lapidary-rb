# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Node do
  describe 'construction' do
    it 'creates a node with id, type, and data' do
      node = described_class.new(id: 'rubyist://matz', type: 'Rubyist', data: { display_name: 'Matz' })

      expect(node.id).to eq('rubyist://matz')
      expect(node.type).to eq('Rubyist')
      expect(node.data).to eq({ display_name: 'Matz' })
    end

    it 'defaults data to an empty hash' do
      node = described_class.new(id: 'rubyist://matz', type: 'Rubyist')

      expect(node.data).to eq({})
    end
  end
end
