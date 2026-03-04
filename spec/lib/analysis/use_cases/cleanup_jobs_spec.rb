# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::UseCases::CleanupJobs do
  subject(:use_case) do
    described_class.new(
      job_repository: job_repository,
      retention_period: retention_period,
      logger: logger
    )
  end

  let(:job_repository) { Lapidary::Container['analysis.repositories.job_repository'] }
  let(:retention_period) { Analysis::Entities::RetentionPeriod.new(amount: 7, unit: 'd') }
  let(:logger) { instance_double(Console::Logger, info: nil) }
  let(:db) { Lapidary::Container['database'] }

  describe '#call' do
    let(:old_time) { Time.new(2026, 1, 1, 0, 0, 0) }
    let(:freeze_time) { Time.new(2026, 1, 15, 12, 0, 0) }

    before do
      # Create a done job with old updated_at (should be cleaned up)
      job_repository.enqueue(
        Analysis::Entities::Job.new(
          arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1)
        )
      )
      claimed = job_repository.claim_next
      claimed.complete
      job_repository.save(claimed)
      db[:jobs].where(id: claimed.id).update(updated_at: old_time)

      # Create a pending job (should NOT be cleaned up)
      job_repository.enqueue(
        Analysis::Entities::Job.new(
          arguments: Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 2)
        )
      )
    end

    it 'deletes expired done jobs' do
      result = use_case.call(now: freeze_time)

      expect(result).to eq(1)
      expect(db[:jobs].count).to eq(1)
    end

    it 'does not delete pending jobs' do
      use_case.call(now: freeze_time)

      remaining = db[:jobs].first
      expect(remaining[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
    end

    it 'returns the count of deleted jobs' do
      result = use_case.call(now: freeze_time)

      expect(result).to eq(1)
    end

    it 'returns zero when no jobs are expired' do
      result = use_case.call(now: old_time)

      expect(result).to eq(0)
    end
  end
end
