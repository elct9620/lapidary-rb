# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::ArchiveEdges do
  subject(:use_case) do
    described_class.new(
      graph_repository: graph_repository,
      analysis_record_repository: analysis_record_repository,
      retention_period: retention_period,
      logger: logger
    )
  end

  let(:graph_repository) { instance_double(Analysis::Repositories::GraphRepository) }
  let(:analysis_record_repository) { instance_double(Analysis::Repositories::AnalysisRecordRepository) }
  let(:retention_period) { Analysis::Entities::RetentionPeriod.new(amount: 180, unit: 'd') }
  let(:logger) { instance_double(Console::Logger, info: nil) }

  describe '#call' do
    context 'when edges are archived' do
      let(:entity_pairs) { [{ entity_type: 'issue', entity_id: 1 }] }

      before do
        allow(graph_repository).to receive(:archive_expired)
          .and_return({ archived_count: 2, entity_pairs: entity_pairs })
        allow(analysis_record_repository).to receive(:delete_by_entities).and_return(1)
      end

      it 'archives expired edges via graph repository' do
        use_case.call

        expect(graph_repository).to have_received(:archive_expired).with(cutoff: an_instance_of(Time))
      end

      it 'resets analysis records for archived edge entities' do
        use_case.call

        expect(analysis_record_repository).to have_received(:delete_by_entities).with(entity_pairs)
      end

      it 'returns the archived count' do
        expect(use_case.call).to eq(2)
      end

      it 'logs the archiving result' do
        use_case.call

        expect(logger).to have_received(:info)
      end
    end

    context 'when no edges are archived' do
      before do
        allow(graph_repository).to receive(:archive_expired)
          .and_return({ archived_count: 0, entity_pairs: [] })
      end

      it 'does not call delete_by_entities' do
        use_case.call

        expect(analysis_record_repository).not_to receive(:delete_by_entities)
      end

      it 'returns zero' do
        expect(use_case.call).to eq(0)
      end
    end

    it 'computes cutoff from retention period' do
      freeze_time = Time.new(2026, 1, 15, 12, 0, 0)
      expected_cutoff = freeze_time - (180 * 86_400)
      allow(graph_repository).to receive(:archive_expired)
        .and_return({ archived_count: 0, entity_pairs: [] })

      use_case.call(now: freeze_time)

      expect(graph_repository).to have_received(:archive_expired).with(cutoff: expected_cutoff)
    end
  end
end
