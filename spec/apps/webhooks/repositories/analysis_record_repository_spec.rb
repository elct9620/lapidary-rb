# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Repositories::AnalysisRecordRepository do
  subject(:repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }

  def build_record(entity_type:, entity_id:)
    record = Webhooks::Entities::AnalysisRecord.new(entity_type: entity_type, entity_id: entity_id)
    record.analyze
    record
  end

  describe '#save' do
    it 'creates a new record' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      repository.save(record)

      expect(repository.exists?(record)).to be true
    end

    it 'does not raise on duplicate insert' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      repository.save(record)

      expect { repository.save(record) }.not_to raise_error
    end

    it 'does not create a duplicate record' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      repository.save(record)
      repository.save(record)

      db = Lapidary::Container['database']
      count = db[:analysis_records].where(entity_type: 'issue', entity_id: 1).count
      expect(count).to eq(1)
    end
  end

  describe '#exists?' do
    it 'returns false when no record exists' do
      record = Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 999)
      expect(repository.exists?(record)).to be false
    end

    it 'returns true when a record exists' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      repository.save(record)

      expect(repository.exists?(record)).to be true
    end
  end

  describe '#untracked_journal_ids' do
    it 'returns all IDs when none are tracked' do
      expect(repository.untracked_journal_ids([1, 2, 3])).to contain_exactly(1, 2, 3)
    end

    it 'excludes already tracked IDs' do
      record = build_record(entity_type: 'journal', entity_id: 2)
      repository.save(record)

      expect(repository.untracked_journal_ids([1, 2, 3])).to contain_exactly(1, 3)
    end

    it 'returns an empty array when given an empty list' do
      expect(repository.untracked_journal_ids([])).to eq([])
    end

    it 'returns an empty array when all are tracked' do
      repository.save(build_record(entity_type: 'journal', entity_id: 1))
      repository.save(build_record(entity_type: 'journal', entity_id: 2))

      expect(repository.untracked_journal_ids([1, 2])).to be_empty
    end
  end

  describe 'when migration has not been run' do
    before do
      Lapidary::Container['database'].drop_table(:analysis_records)
    end

    it '#save raises AnalysisTrackingError' do
      record = build_record(entity_type: 'issue', entity_id: 1)

      expect { repository.save(record) }.to raise_error(Webhooks::Entities::AnalysisTrackingError)
    end

    it '#exists? raises AnalysisTrackingError' do
      record = Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 1)

      expect { repository.exists?(record) }.to raise_error(Webhooks::Entities::AnalysisTrackingError)
    end

    it '#untracked_journal_ids raises AnalysisTrackingError' do
      expect { repository.untracked_journal_ids([1]) }.to raise_error(Webhooks::Entities::AnalysisTrackingError)
    end
  end

  describe 'error wrapping' do
    let(:database) { Lapidary::Container['database'] }

    it 'wraps Sequel::DatabaseError from #save as AnalysisTrackingError' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      allow(database).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.save(record)
      end.to raise_error(Webhooks::Entities::AnalysisTrackingError, 'connection lost')
    end

    it 'wraps Sequel::DatabaseError from #exists? as AnalysisTrackingError' do
      record = Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 1)
      allow(database).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.exists?(record)
      end.to raise_error(Webhooks::Entities::AnalysisTrackingError, 'connection lost')
    end

    it 'wraps Sequel::DatabaseError from #untracked_journal_ids as AnalysisTrackingError' do
      allow(database).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.untracked_journal_ids([1])
      end.to raise_error(Webhooks::Entities::AnalysisTrackingError, 'connection lost')
    end
  end
end
