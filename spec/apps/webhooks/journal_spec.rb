# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Journal do
  describe '#id' do
    it 'returns the journal id' do
      journal = described_class.new(id: 101)
      expect(journal.id).to eq(101)
    end
  end
end
