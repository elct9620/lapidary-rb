# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Repositories::AnalysisRecordRepository do
  subject(:repository) { Lapidary::Container['webhooks.repositories.analysis_record_repository'] }

  let(:db) { Lapidary::Container['database'] }

  def insert_record(entity_type:, entity_id:)
    db[:analysis_records].insert(entity_type: entity_type, entity_id: entity_id, analyzed_at: Time.now)
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
      insert_record(entity_type: 'journal', entity_id: 2)

      records = build_journal_records(1, 2, 3)
      result = repository.untracked(records)

      expect(result.map(&:entity_id)).to contain_exactly(1, 3)
    end

    it 'returns an empty array when given an empty list' do
      expect(repository.untracked([])).to eq([])
    end

    it 'returns an empty array when all are tracked' do
      insert_record(entity_type: 'journal', entity_id: 1)
      insert_record(entity_type: 'journal', entity_id: 2)

      records = build_journal_records(1, 2)
      expect(repository.untracked(records)).to be_empty
    end

    it 'handles mixed entity_types correctly' do
      insert_record(entity_type: 'issue', entity_id: 1)

      records = [
        Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 1),
        Webhooks::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 2),
        Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 10)
      ]

      result = repository.untracked(records)
      expect(result.map { |r| [r.entity_type.to_s, r.entity_id] }).to contain_exactly(
        ['issue', 2],
        ['journal', 10]
      )
    end
  end

  describe 'when migration has not been run' do
    before do
      Lapidary::Container['database'].drop_table(:analysis_records)
    end

    it '#untracked raises AnalysisTrackingError' do
      records = [Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 1)]
      expect { repository.untracked(records) }.to raise_error(Webhooks::Entities::AnalysisTrackingError)
    end
  end

  describe 'error wrapping' do
    it 'wraps Sequel::DatabaseError from #untracked as AnalysisTrackingError' do
      records = [Webhooks::Entities::AnalysisRecord.new(entity_type: 'journal', entity_id: 1)]
      allow(db).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.untracked(records)
      end.to raise_error(Webhooks::Entities::AnalysisTrackingError, 'connection lost')
    end
  end
end
