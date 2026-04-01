# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::Node do
  it 'defaults properties to an empty hash' do
    node = described_class.new(
      type: Analysis::Entities::NodeType::CORE_MODULE,
      name: 'String'
    )

    expect(node.properties).to eq({})
  end
end
