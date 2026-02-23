# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::JobRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.job_repository'] }

  let(:job) { Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 1 }) }

  describe '#enqueue' do
    it 'inserts a pending job into the database' do
      repository.enqueue(job)

      row = Lapidary::Container['database'][:jobs].first
      expect(JSON.parse(row[:arguments], symbolize_names: true)).to eq(entity_type: 'issue', entity_id: 1)
      expect(row[:status]).to eq('pending')
    end

    it 'sets created_at and updated_at' do
      repository.enqueue(job)

      row = Lapidary::Container['database'][:jobs].first
      expect(row[:created_at]).not_to be_nil
      expect(row[:updated_at]).not_to be_nil
    end
  end

  describe '#claim_next' do
    context 'when there are pending jobs' do
      before { repository.enqueue(job) }

      it 'returns a claimed job' do
        claimed = repository.claim_next
        expect(claimed).not_to be_nil
        expect(claimed).to be_claimed
      end

      it 'returns the job with correct attributes' do
        claimed = repository.claim_next
        expect(claimed.arguments).to eq(entity_type: 'issue', entity_id: 1)
      end

      it 'marks the job as claimed in the database' do
        repository.claim_next

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq('claimed')
      end
    end

    context 'when there are no pending jobs' do
      it 'returns nil' do
        expect(repository.claim_next).to be_nil
      end
    end

    context 'when jobs are scheduled in the future' do
      let(:future_job) do
        Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 1 }, scheduled_at: Time.now + 3600)
      end

      before { repository.enqueue(future_job) }

      it 'does not claim future jobs' do
        expect(repository.claim_next).to be_nil
      end
    end

    context 'with multiple pending jobs' do
      before do
        repository.enqueue(Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 1 }))
        repository.enqueue(Analysis::Entities::Job.new(arguments: { entity_type: 'issue', entity_id: 2 }))
      end

      it 'claims the oldest job first' do
        claimed = repository.claim_next
        expect(claimed.arguments[:entity_id]).to eq(1)
      end
    end
  end

  describe '#save' do
    before { repository.enqueue(job) }

    it 'updates the job status in the database' do
      claimed = repository.claim_next
      claimed.complete
      repository.save(claimed)

      row = Lapidary::Container['database'][:jobs].where(id: claimed.id).first
      expect(row[:status]).to eq('done')
    end
  end
end
