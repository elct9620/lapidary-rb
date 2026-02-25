# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::JobRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.job_repository'] }

  let(:job) { Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1)) }

  describe '#enqueue' do
    it 'inserts a pending job into the database' do
      repository.enqueue(job)

      row = Lapidary::Container['database'][:jobs].first
      expect(JSON.parse(row[:arguments], symbolize_names: true)).to eq(entity_type: 'issue', entity_id: 1)
      expect(row[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
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
        expect(claimed.arguments.entity_type).to eq('issue')
        expect(claimed.arguments.entity_id).to eq(1)
      end

      it 'marks the job as claimed in the database' do
        repository.claim_next

        row = Lapidary::Container['database'][:jobs].first
        expect(row[:status]).to eq(Analysis::Entities::JobStatus::CLAIMED.to_s)
      end
    end

    context 'when there are no pending jobs' do
      it 'returns nil' do
        expect(repository.claim_next).to be_nil
      end
    end

    context 'when jobs are scheduled in the future' do
      let(:future_job) do
        Analysis::Entities::Job.new(
          arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue',
                                                          entity_id: 1), scheduled_at: Time.now + 3600
        )
      end

      before { repository.enqueue(future_job) }

      it 'does not claim future jobs' do
        expect(repository.claim_next).to be_nil
      end
    end

    context 'with multiple pending jobs' do
      before do
        repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 1
        )))
        repository.enqueue(Analysis::Entities::Job.new(arguments: Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 2
        )))
      end

      it 'claims the oldest job first' do
        claimed = repository.claim_next
        expect(claimed.arguments.entity_id).to eq(1)
      end
    end
  end

  describe '#delete_expired' do
    let(:db) { Lapidary::Container['database'] }

    it 'deletes done jobs older than cutoff' do
      repository.enqueue(job)
      claimed = repository.claim_next
      claimed.complete
      repository.save(claimed)
      db[:jobs].where(id: claimed.id).update(updated_at: Time.now - 86_400)

      deleted = repository.delete_expired(cutoff: Time.now - 3600)

      expect(deleted).to eq(1)
      expect(db[:jobs].count).to eq(0)
    end

    it 'deletes failed jobs older than cutoff' do
      repository.enqueue(job)
      claimed = repository.claim_next
      claimed.fail('permanent error')
      repository.save(claimed)
      db[:jobs].where(id: claimed.id).update(updated_at: Time.now - 86_400)

      deleted = repository.delete_expired(cutoff: Time.now - 3600)

      expect(deleted).to eq(1)
      expect(db[:jobs].count).to eq(0)
    end

    it 'deletes stale claimed jobs older than cutoff' do
      repository.enqueue(job)
      repository.claim_next
      db[:jobs].update(updated_at: Time.now - 86_400)

      deleted = repository.delete_expired(cutoff: Time.now - 3600)

      expect(deleted).to eq(1)
      expect(db[:jobs].count).to eq(0)
    end

    it 'does not delete pending jobs' do
      repository.enqueue(job)
      db[:jobs].update(updated_at: Time.now - 86_400)

      deleted = repository.delete_expired(cutoff: Time.now - 3600)

      expect(deleted).to eq(0)
      expect(db[:jobs].count).to eq(1)
    end

    it 'does not delete jobs newer than cutoff' do
      repository.enqueue(job)
      claimed = repository.claim_next
      claimed.complete
      repository.save(claimed)

      deleted = repository.delete_expired(cutoff: Time.now - 3600)

      expect(deleted).to eq(0)
      expect(db[:jobs].count).to eq(1)
    end

    it 'returns zero when no jobs match' do
      expect(repository.delete_expired(cutoff: Time.now)).to eq(0)
    end
  end

  describe '#save' do
    before { repository.enqueue(job) }

    it 'updates the job status in the database' do
      claimed = repository.claim_next
      claimed.complete
      repository.save(claimed)

      row = Lapidary::Container['database'][:jobs].where(id: claimed.id).first
      expect(row[:status]).to eq(Analysis::Entities::JobStatus::DONE.to_s)
    end

    it 'updates scheduled_at in the database' do
      claimed = repository.claim_next
      claimed.retry('transient error')
      repository.save(claimed)

      row = Lapidary::Container['database'][:jobs].where(id: claimed.id).first
      expect(row[:scheduled_at]).to be > Time.now
    end
  end
end
