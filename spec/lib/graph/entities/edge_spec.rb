# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Entities::Edge do
  it 'defaults observations to an empty array' do
    edge = described_class.new(
      source: 'rubyist://matz',
      target: 'core_module://String',
      relationship: 'Contribute'
    )

    expect(edge.observations).to eq([])
  end
end
