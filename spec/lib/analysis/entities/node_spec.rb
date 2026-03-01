# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::Node do
  describe 'construction' do
    it 'creates a node with type, name, and properties' do
      node = described_class.new(
        type: Analysis::Entities::NodeType::RUBYIST,
        name: 'matz',
        properties: { role: 'maintainer' }
      )

      expect(node.type).to eq(Analysis::Entities::NodeType::RUBYIST)
      expect(node.name).to eq('matz')
      expect(node.properties).to eq({ role: 'maintainer' })
    end

    it 'defaults properties to an empty hash' do
      node = described_class.new(
        type: Analysis::Entities::NodeType::CORE_MODULE,
        name: 'String'
      )

      expect(node.properties).to eq({})
    end
  end
end
