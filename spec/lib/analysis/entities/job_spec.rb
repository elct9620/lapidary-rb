# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::Job do
  subject(:job) { described_class.new(arguments: { entity_type: 'issue', entity_id: 1 }) }

  let(:fixed_time) { Time.new(2025, 1, 1, 12, 0, 0) }

  describe '#initialize' do
    it 'defaults to pending status' do
      expect(job).to be_pending
    end

    it 'defaults attempts to 0' do
      expect(job.attempts).to eq(0)
    end

    it 'defaults max_attempts to 3' do
      expect(job.max_attempts).to eq(3)
    end

    it 'sets scheduled_at to current time when not provided' do
      expect(job.scheduled_at).to be_within(1).of(Time.now)
    end
  end

  describe '#claim' do
    context 'when pending' do
      it 'transitions to claimed status' do
        job.claim(now: fixed_time)
        expect(job).to be_claimed
      end

      it 'updates updated_at' do
        job.claim(now: fixed_time)
        expect(job.updated_at).to eq(fixed_time)
      end
    end

    context 'when already claimed' do
      before { job.claim }

      it 'raises JobError' do
        expect { job.claim }.to raise_error(Analysis::Entities::JobError, /cannot claim/)
      end
    end

    context 'when done' do
      before do
        job.claim
        job.complete
      end

      it 'raises JobError' do
        expect { job.claim }.to raise_error(Analysis::Entities::JobError, /cannot claim/)
      end
    end
  end

  describe '#complete' do
    context 'when claimed' do
      before { job.claim }

      it 'transitions to done status' do
        job.complete(now: fixed_time)
        expect(job.status).to eq(Analysis::Entities::JobStatus::DONE)
      end

      it 'updates updated_at' do
        job.complete(now: fixed_time)
        expect(job.updated_at).to eq(fixed_time)
      end
    end

    context 'when pending' do
      it 'raises JobError' do
        expect { job.complete }.to raise_error(Analysis::Entities::JobError, /cannot complete/)
      end
    end

    context 'when already done' do
      before do
        job.claim
        job.complete
      end

      it 'raises JobError' do
        expect { job.complete }.to raise_error(Analysis::Entities::JobError, /cannot complete/)
      end
    end
  end

  describe '#retry' do
    context 'when claimed' do
      before { job.claim }

      it 'transitions back to pending status' do
        job.retry('something failed', now: fixed_time)
        expect(job).to be_pending
      end

      it 'increments attempts' do
        job.retry('something failed', now: fixed_time)
        expect(job.attempts).to eq(1)
      end

      it 'records the error message' do
        job.retry('something failed', now: fixed_time)
        expect(job.error).to eq('something failed')
      end

      it 'sets scheduled_at with exponential backoff' do
        job.retry('something failed', now: fixed_time)
        expect(job.scheduled_at).to eq(fixed_time + (2**1))
      end

      it 'updates updated_at' do
        job.retry('something failed', now: fixed_time)
        expect(job.updated_at).to eq(fixed_time)
      end
    end

    context 'when pending' do
      it 'raises JobError' do
        expect { job.retry('error') }.to raise_error(Analysis::Entities::JobError, /cannot retry/)
      end
    end

    context 'when done' do
      before do
        job.claim
        job.complete
      end

      it 'raises JobError' do
        expect { job.retry('error') }.to raise_error(Analysis::Entities::JobError, /cannot retry/)
      end
    end
  end

  describe '#fail' do
    context 'when claimed' do
      before { job.claim }

      it 'transitions to failed status' do
        job.fail('permanent failure', now: fixed_time)
        expect(job.status).to eq(Analysis::Entities::JobStatus::FAILED)
      end

      it 'records the error message' do
        job.fail('permanent failure', now: fixed_time)
        expect(job.error).to eq('permanent failure')
      end

      it 'updates updated_at' do
        job.fail('permanent failure', now: fixed_time)
        expect(job.updated_at).to eq(fixed_time)
      end
    end

    context 'when pending' do
      it 'raises JobError' do
        expect { job.fail('error') }.to raise_error(Analysis::Entities::JobError, /cannot fail/)
      end
    end

    context 'when done' do
      before do
        job.claim
        job.complete
      end

      it 'raises JobError' do
        expect { job.fail('error') }.to raise_error(Analysis::Entities::JobError, /cannot fail/)
      end
    end
  end

  describe '#release' do
    context 'when claimed' do
      before { job.claim }

      it 'transitions back to pending status' do
        job.release(now: fixed_time)
        expect(job).to be_pending
      end

      it 'sets scheduled_at to now without backoff' do
        job.release(now: fixed_time)
        expect(job.scheduled_at).to eq(fixed_time)
      end

      it 'does not increment attempts' do
        job.release(now: fixed_time)
        expect(job.attempts).to eq(0)
      end

      it 'updates updated_at' do
        job.release(now: fixed_time)
        expect(job.updated_at).to eq(fixed_time)
      end
    end

    context 'when pending' do
      it 'raises JobError' do
        expect { job.release }.to raise_error(Analysis::Entities::JobError, /cannot release/)
      end
    end

    context 'when done' do
      before do
        job.claim
        job.complete
      end

      it 'raises JobError' do
        expect { job.release }.to raise_error(Analysis::Entities::JobError, /cannot release/)
      end
    end
  end

  describe '#retryable?' do
    it 'returns true when attempts have not reached max' do
      job.claim
      expect(job).to be_retryable
    end

    it 'returns false when next attempt would reach max_attempts' do
      job = described_class.new(arguments: { entity_type: 'issue', entity_id: 1 }, attempts: 2, max_attempts: 3)
      job.claim
      expect(job).not_to be_retryable
    end
  end
end
