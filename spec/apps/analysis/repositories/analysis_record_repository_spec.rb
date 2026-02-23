# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::AnalysisRecordRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.analysis_record_repository'] }

  def build_record(entity_type:, entity_id:)
    record = Analysis::Entities::AnalysisRecord.new(entity_type: entity_type, entity_id: entity_id)
    record.analyze
    record
  end

  describe '#save' do
    it 'creates a new record' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      repository.save(record)

      db = Lapidary::Container['database']
      row = db[:analysis_records].where(entity_type: 'issue', entity_id: 1).first
      expect(row).not_to be_nil
      expect(row[:analyzed_at]).not_to be_nil
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

  describe 'when migration has not been run' do
    before do
      Lapidary::Container['database'].drop_table(:analysis_records)
    end

    it '#save raises AnalysisTrackingError' do
      record = build_record(entity_type: 'issue', entity_id: 1)

      expect { repository.save(record) }.to raise_error(Analysis::Entities::AnalysisTrackingError)
    end
  end

  describe 'error wrapping' do
    let(:database) { Lapidary::Container['database'] }

    it 'wraps Sequel::DatabaseError from #save as AnalysisTrackingError' do
      record = build_record(entity_type: 'issue', entity_id: 1)
      allow(database).to receive(:[]).and_raise(Sequel::DatabaseError, 'connection lost')

      expect do
        repository.save(record)
      end.to raise_error(Analysis::Entities::AnalysisTrackingError, 'connection lost')
    end
  end
end
