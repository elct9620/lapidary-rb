# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::JobArguments do
  describe '#initialize' do
    it 'coerces entity_id from string to integer' do
      args = described_class.new(entity_type: 'issue', entity_id: '42')
      expect(args.entity_id).to eq(42)
    end

    it 'accepts integer entity_id unchanged' do
      args = described_class.new(entity_type: 'issue', entity_id: 42)
      expect(args.entity_id).to eq(42)
    end

    it 'raises ArgumentError for non-numeric entity_id' do
      expect { described_class.new(entity_type: 'issue', entity_id: 'abc') }.to raise_error(ArgumentError)
    end
  end
end
