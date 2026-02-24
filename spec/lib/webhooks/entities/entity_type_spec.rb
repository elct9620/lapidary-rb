# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Entities::EntityType do
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
end
