# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::ProcessJob do
  subject(:use_case) do
    described_class.new(
      job_repository: job_repository,
      analysis_record_repository: analysis_record_repository
    )
  end

  let(:job_repository) { Lapidary::Container['analysis.repositories.job_repository'] }
  let(:analysis_record_repository) { Lapidary::Container['analysis.repositories.analysis_record_repository'] }

  describe '#call' do
    context 'when there is a pending job' do
      before do
        job = Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 1 })
        job_repository.enqueue(job)
      end

      it 'returns true' do
        expect(use_case.call).to be true
      end

      it 'creates an analysis record' do
        use_case.call

        row = Lapidary::Container['database'][:analysis_records]
              .where(entity_type: 'issue', entity_id: 1).first
        expect(row).not_to be_nil
        expect(row[:analyzed_at]).not_to be_nil
      end

      it 'marks the job as done' do
        use_case.call

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq('done')
      end
    end

    context 'when there are no pending jobs' do
      it 'returns false' do
        expect(use_case.call).to be false
      end
    end

    context 'with multiple pending jobs' do
      before do
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 1 }))
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: { entity_type: 'journal', entity_id: 101 }))
      end

      it 'processes one job per call' do
        use_case.call

        db = Lapidary::Container['database']
        expect(db[:jobs].where(status: 'done').count).to eq(1)
        expect(db[:jobs].where(status: 'pending').count).to eq(1)
      end
    end
  end
end
