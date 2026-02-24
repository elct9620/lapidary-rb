# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Repositories::AnalysisRecordRepository do
  subject(:repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }

  def build_record(entity_type:, entity_id:)
    Webhooks::Entities::AnalysisRecord.new(entity_type: entity_type, entity_id: entity_id, analyzed_at: Time.now)
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

  describe '#untracked' do
    def build_journal_records(*ids)
      ids.map { |id| Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: id) }
    end

    it 'returns all records when none are tracked' do
      records = build_journal_records(1, 2, 3)
      result = repository.untracked(records)

      expect(result.map(&:entity_id)).to contain_exactly(1, 2, 3)
    end

    it 'excludes already tracked records' do
      repository.save(build_record(entity_type: 'journal', entity_id: 2))

      records = build_journal_records(1, 2, 3)
      result = repository.untracked(records)

      expect(result.map(&:entity_id)).to contain_exactly(1, 3)
    end

    it 'returns an empty array when given an empty list' do
      expect(repository.untracked([])).to eq([])
    end

    it 'returns an empty array when all are tracked' do
      repository.save(build_record(entity_type: 'journal', entity_id: 1))
      repository.save(build_record(entity_type: 'journal', entity_id: 2))

      records = build_journal_records(1, 2)
      expect(repository.untracked(records)).to be_empty
    end

    it 'raises ArgumentError when records have mixed entity_types' do
      records = [
        Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 1),
        Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 2)
      ]

      expect { repository.untracked(records) }.to raise_error(ArgumentError, 'records must have the same entity_type')
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

    it '#untracked raises AnalysisTrackingError' do
      records = [Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 1)]
      expect { repository.untracked(records) }.to raise_error(Webhooks::Entities::AnalysisTrackingError)
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

    it 'wraps Sequel::DatabaseError from #untracked as AnalysisTrackingError' do
      records = [Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 1)]
      allow(database).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.untracked(records)
      end.to raise_error(Webhooks::Entities::AnalysisTrackingError, 'connection lost')
    end
  end
end
