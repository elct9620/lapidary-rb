# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Entities::Journal do
  describe '#id' do
    it 'returns the journal id' do
      journal = described_class.new(id: 101)
      expect(journal.id).to eq(101)
    end
  end

  describe '#notes' do
    it 'returns the notes' do
      journal = described_class.new(id: 101, notes: 'Review comment here')
      expect(journal.notes).to eq('Review comment here')
    end

    it 'defaults to nil' do
      journal = described_class.new(id: 101)
      expect(journal.notes).to be_nil
    end
  end
end
