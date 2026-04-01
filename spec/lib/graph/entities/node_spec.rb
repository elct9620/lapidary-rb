# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Node do
  it 'defaults data to an empty hash' do
    node = described_class.new(id: 'rubyist://matz', type: 'Rubyist')

    expect(node.data).to eq({})
  end
end
