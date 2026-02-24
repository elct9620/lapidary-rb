# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Entities::Issue do
  describe '#id' do
    it 'returns the issue id' do
      issue = described_class.new(id: 42)
      expect(issue.id).to eq(42)
    end
  end

  describe '#subject' do
    it 'returns the subject' do
      issue = described_class.new(id: 42, subject: 'Add new feature')
      expect(issue.subject).to eq('Add new feature')
    end

    it 'defaults to nil' do
      issue = described_class.new(id: 42)
      expect(issue.subject).to be_nil
    end
  end

  describe '#author_username' do
    it 'returns the author username' do
      issue = described_class.new(id: 42, author_username: 'matz')
      expect(issue.author_username).to eq('matz')
    end

    it 'defaults to nil' do
      issue = described_class.new(id: 42)
      expect(issue.author_username).to be_nil
    end
  end

  describe '#author_display_name' do
    it 'returns the author display name' do
      issue = described_class.new(id: 42, author_display_name: 'Yukihiro Matsumoto')
      expect(issue.author_display_name).to eq('Yukihiro Matsumoto')
    end

    it 'defaults to nil' do
      issue = described_class.new(id: 42)
      expect(issue.author_display_name).to be_nil
    end
  end

  describe '#journals' do
    it 'returns the journals' do
      journals = [Webhooks::Entities::Journal.new(id: 101), Webhooks::Entities::Journal.new(id: 102)]
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
      journals = [Webhooks::Entities::Journal.new(id: 101), Webhooks::Entities::Journal.new(id: 102)]
      issue = described_class.new(id: 42, journals: journals)
      expect(issue.journal_ids).to eq([101, 102])
    end

    it 'returns an empty array when there are no journals' do
      issue = described_class.new(id: 42)
      expect(issue.journal_ids).to eq([])
    end
  end
end
