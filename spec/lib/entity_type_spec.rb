# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EntityType do
  describe '::ISSUE' do
    it 'has value "issue"' do
      expect(EntityType::ISSUE.value).to eq('issue')
    end

    it 'converts to string as "issue"' do
      expect(EntityType::ISSUE.to_s).to eq('issue')
    end
  end

  describe '::JOURNAL' do
    it 'has value "journal"' do
      expect(EntityType::JOURNAL.value).to eq('journal')
    end

    it 'converts to string as "journal"' do
      expect(EntityType::JOURNAL.to_s).to eq('journal')
    end
  end

  describe 'equality' do
    it 'is equal when values match' do
      expect(EntityType.new(value: 'issue')).to eq(EntityType::ISSUE)
    end

    it 'is not equal when values differ' do
      expect(EntityType::ISSUE).not_to eq(EntityType::JOURNAL)
    end
  end
end
