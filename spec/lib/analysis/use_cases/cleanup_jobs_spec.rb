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

  let(:job_repository) { instance_double(Analysis::Repositories::JobRepository) }
  let(:retention_period) { Analysis::Entities::RetentionPeriod.new(amount: 7, unit: 'd') }
  let(:logger) { instance_double(Console::Logger, info: nil) }

  describe '#call' do
    it 'deletes expired jobs via repository' do
      allow(job_repository).to receive(:delete_expired).and_return(3)

      use_case.call

      expect(job_repository).to have_received(:delete_expired).with(cutoff: an_instance_of(Time))
    end

    it 'logs the number of deleted jobs' do
      allow(job_repository).to receive(:delete_expired).and_return(5)

      use_case.call

      expect(logger).to have_received(:info)
    end

    it 'computes cutoff from retention period' do
      freeze_time = Time.new(2026, 1, 15, 12, 0, 0)
      expected_cutoff = freeze_time - (7 * 86_400)
      allow(job_repository).to receive(:delete_expired).and_return(0)

      use_case.call(now: freeze_time)

      expect(job_repository).to have_received(:delete_expired).with(cutoff: expected_cutoff)
    end

    it 'returns the count of deleted jobs' do
      allow(job_repository).to receive(:delete_expired).and_return(2)

      result = use_case.call

      expect(result).to eq(2)
    end
  end
end
