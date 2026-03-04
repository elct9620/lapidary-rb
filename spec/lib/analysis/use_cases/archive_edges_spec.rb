# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::ArchiveEdges do
  subject(:use_case) do
    described_class.new(
      edge_archive_writer: edge_archive_writer,
      analysis_record_repository: analysis_record_repository,
      retention_period: retention_period,
      logger: logger
    )
  end

  let(:edge_archive_writer) { Lapidary::Container['analysis.repositories.edge_archive_writer'] }
  let(:analysis_record_repository) { Lapidary::Container['analysis.repositories.analysis_record_repository'] }
  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }
  let(:retention_period) { Analysis::Entities::RetentionPeriod.new(amount: 180, unit: 'd') }
  let(:logger) { Lapidary::Container['logger'] }
  let(:db) { Lapidary::Container['database'] }

  let(:freeze_time) { Time.new(2026, 1, 15, 12, 0, 0) }
  let(:expired_time) { (freeze_time - (181 * 86_400)).iso8601 }
  let(:recent_time) { (freeze_time - (10 * 86_400)).iso8601 }

  describe '#call' do
    context 'when edges are archived' do
      before do
        # Create an expired edge (observation older than 180 days)
        triplet = maintainer_triplet
        observation = Analysis::Entities::Observation.new(
          observed_at: expired_time, source_entity_type: 'issue', source_entity_id: 1
        )
        graph_repository.save_triplet(triplet, observation)

        # Create an analysis record for the entity
        record = Analysis::Entities::AnalysisRecord.new(entity_type: 'issue', entity_id: 1)
        record.analyze
        analysis_record_repository.save(record)
      end

      it 'archives expired edges' do
        result = use_case.call(now: freeze_time)

        expect(result).to eq(1)
        edge = db[:edges].first
        expect(edge[:archived_at]).not_to be_nil
      end

      it 'deletes analysis records for archived edge entities' do
        use_case.call(now: freeze_time)

        expect(db[:analysis_records].where(entity_type: 'issue', entity_id: 1).count).to eq(0)
      end

      it 'returns the archived count' do
        expect(use_case.call(now: freeze_time)).to eq(1)
      end
    end

    context 'when no edges are archived' do
      before do
        # Create a recent edge (observation within 180 days)
        triplet = maintainer_triplet
        observation = Analysis::Entities::Observation.new(
          observed_at: recent_time, source_entity_type: 'issue', source_entity_id: 2
        )
        graph_repository.save_triplet(triplet, observation)
      end

      it 'does not archive recent edges' do
        use_case.call(now: freeze_time)

        edge = db[:edges].first
        expect(edge[:archived_at]).to be_nil
      end

      it 'returns zero' do
        expect(use_case.call(now: freeze_time)).to eq(0)
      end
    end
  end
end
