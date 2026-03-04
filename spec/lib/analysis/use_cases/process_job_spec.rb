# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::ProcessJob do
  subject(:use_case) do
    described_class.new(
      job_repository: job_repository,
      analysis_record_repository: analysis_record_repository,
      pipeline: pipeline,
      logger: logger
    )
  end

  let(:job_repository) { Lapidary::Container['analysis.repositories.job_repository'] }
  let(:analysis_record_repository) { Lapidary::Container['analysis.repositories.analysis_record_repository'] }
  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }
  let(:extractor) { instance_double(Analysis::Extractors::LlmExtractor, call: []) }
  let(:validator) { Analysis::Ontology::Validator.new }
  let(:normalizer) { Analysis::Ontology::Normalizer.new }
  let(:logger) { instance_double(Console::Logger, error: nil, warn: nil, info: nil) }

  let(:pipeline) do
    Analysis::UseCases::TripletPipeline.new(
      extractor: extractor,
      validator: validator,
      normalizer: normalizer,
      graph_repository: graph_repository,
      logger: logger
    )
  end

  describe '#call' do
    def claim_job
      job_repository.claim_next
    end

    context 'when there is a pending job' do
      before do
        job_repository.enqueue(
          Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue',
                                                                                      entity_id: 1))
        )
      end

      it 'creates an analysis record' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:analysis_records]
              .where(entity_type: 'issue', entity_id: 1).first
        expect(row).not_to be_nil
        expect(row[:analyzed_at]).not_to be_nil
      end

      it 'marks the job as done' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::DONE.to_s)
      end
    end

    context 'when processing fails' do
      before do
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 1
        )))
        allow(analysis_record_repository).to receive(:save)
          .and_raise(Analysis::Entities::AnalysisTrackingError, 'connection lost')
      end

      it 'retries the job back to pending' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
        expect(row[:attempts]).to eq(1)
      end

      it 'records the error on the job' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:error]).to eq('connection lost')
      end
    end

    context 'when processing fails and max attempts reached' do
      before do
        job = Analysis::Entities::Job.new(
          arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1),
          attempts: 2, max_attempts: 3
        )
        job_repository.enqueue(job)
        allow(analysis_record_repository).to receive(:save)
          .and_raise(Analysis::Entities::AnalysisTrackingError, 'permanent failure')
      end

      it 'marks the job as failed' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::FAILED.to_s)
      end
    end

    context 'when extraction produces invalid triplets' do
      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [invalid_triplet], correct: nil)
      end

      before do
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 1
        )))
      end

      it 'rejects invalid triplets and still completes the job' do
        use_case.call(claim_job)

        expect(Lapidary::Container['database'][:nodes].count).to eq(0)
        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::DONE.to_s)
      end
    end

    context 'when a valid triplet is extracted' do
      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor, call: [maintainer_triplet])
      end

      before do
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 1, author_username: 'matz'
        )))
      end

      it 'writes the triplet to the knowledge graph' do
        use_case.call(claim_job)

        db = Lapidary::Container['database']
        expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
        expect(db[:nodes].where(id: 'core_module://String').count).to eq(1)
        expect(db[:edges].count).to eq(1)
      end
    end

    context 'when extraction fails' do
      let(:extractor) do
        instance_double(Analysis::Extractors::LlmExtractor).tap do |ext|
          allow(ext).to receive(:call).and_raise(Analysis::Entities::ExtractionError, 'extraction error')
        end
      end

      before do
        job_repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 1
        )))
      end

      it 'retries the job via existing error handling' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
        expect(row[:error]).to eq('extraction error')
      end

      it 'does not create a ghost analysis record' do
        use_case.call(claim_job)

        row = Lapidary::Container['database'][:analysis_records]
              .where(entity_type: 'issue', entity_id: 1).first
        expect(row).to be_nil
      end
    end
  end
end
