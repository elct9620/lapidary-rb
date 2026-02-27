# frozen_string_literal: true

RSpec.shared_examples 'an EntityType value object' do
  describe '::ISSUE' do
    it 'has value "issue"' do
      expect(described_class::ISSUE.value).to eq('issue')
    end

    it 'converts to string as "issue"' do
      expect(described_class::ISSUE.to_s).to eq('issue')
    end
  end

  describe '::JOURNAL' do
    it 'has value "journal"' do
      expect(described_class::JOURNAL.value).to eq('journal')
    end

    it 'converts to string as "journal"' do
      expect(described_class::JOURNAL.to_s).to eq('journal')
    end
  end

  describe 'equality' do
    it 'is equal when values match' do
      expect(described_class.new(value: 'issue')).to eq(described_class::ISSUE)
    end

    it 'is not equal when values differ' do
      expect(described_class::ISSUE).not_to eq(described_class::JOURNAL)
    end
  end

  describe '.parse' do
    it 'returns ISSUE for "issue"' do
      expect(described_class.parse('issue')).to eq(described_class::ISSUE)
    end

    it 'returns JOURNAL for "journal"' do
      expect(described_class.parse('journal')).to eq(described_class::JOURNAL)
    end

    it 'raises ArgumentError for unknown values' do
      expect { described_class.parse('unknown') }.to raise_error(ArgumentError, 'unknown entity type: unknown')
    end
  end
end
