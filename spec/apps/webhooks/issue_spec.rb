# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Issue do
  describe '#id' do
    it 'returns the issue id' do
      issue = described_class.new(id: 42)
      expect(issue.id).to eq(42)
    end
  end

  describe '#journals' do
    it 'returns the journals' do
      journals = [Webhooks::Journal.new(id: 101), Webhooks::Journal.new(id: 102)]
      issue = described_class.new(id: 42, journals: journals)
      expect(issue.journals).to eq(journals)
    end

    it 'defaults to an empty array' do
      issue = described_class.new(id: 42)
      expect(issue.journals).to eq([])
    end
  end

  describe '#journal_ids' do
    it 'returns all journal ids' do
      journals = [Webhooks::Journal.new(id: 101), Webhooks::Journal.new(id: 102)]
      issue = described_class.new(id: 42, journals: journals)
      expect(issue.journal_ids).to eq([101, 102])
    end

    it 'returns an empty array when there are no journals' do
      issue = described_class.new(id: 42)
      expect(issue.journal_ids).to eq([])
    end
  end
end
