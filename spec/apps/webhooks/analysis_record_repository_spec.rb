# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::AnalysisRecordRepository do
  subject(:repository) { Lapidary::Container['webhooks.analysis_record_repository'] }

  describe '#create_if_absent' do
    it 'creates a new record' do
      repository.create_if_absent(entity_type: 'issue', entity_id: 1)

      expect(repository.tracked?(entity_type: 'issue', entity_id: 1)).to be true
    end

    it 'does not raise on duplicate insert' do
      repository.create_if_absent(entity_type: 'issue', entity_id: 1)

      expect { repository.create_if_absent(entity_type: 'issue', entity_id: 1) }.not_to raise_error
    end

    it 'does not create a duplicate record' do
      repository.create_if_absent(entity_type: 'issue', entity_id: 1)
      repository.create_if_absent(entity_type: 'issue', entity_id: 1)

      db = Lapidary::Container['database']
      count = db[:analysis_records].where(entity_type: 'issue', entity_id: 1).count
      expect(count).to eq(1)
    end
  end

  describe '#tracked?' do
    it 'returns false when no record exists' do
      expect(repository.tracked?(entity_type: 'issue', entity_id: 999)).to be false
    end

    it 'returns true when a record exists' do
      repository.create_if_absent(entity_type: 'issue', entity_id: 1)

      expect(repository.tracked?(entity_type: 'issue', entity_id: 1)).to be true
    end
  end

  describe '#untracked_journal_ids' do
    it 'returns all IDs when none are tracked' do
      expect(repository.untracked_journal_ids([1, 2, 3])).to contain_exactly(1, 2, 3)
    end

    it 'excludes already tracked IDs' do
      repository.create_if_absent(entity_type: 'journal', entity_id: 2)

      expect(repository.untracked_journal_ids([1, 2, 3])).to contain_exactly(1, 3)
    end

    it 'returns an empty array when given an empty list' do
      expect(repository.untracked_journal_ids([])).to eq([])
    end

    it 'returns an empty array when all are tracked' do
      repository.create_if_absent(entity_type: 'journal', entity_id: 1)
      repository.create_if_absent(entity_type: 'journal', entity_id: 2)

      expect(repository.untracked_journal_ids([1, 2])).to be_empty
    end
  end
end
