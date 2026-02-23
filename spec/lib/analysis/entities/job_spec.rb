# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::Job do
  subject(:job) { described_class.new(arguments: { entity_type: 'issue', entity_id: 1 }) }

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
        job.claim
        expect(job).to be_claimed
      end

      it 'updates updated_at' do
        job.claim
        expect(job.updated_at).to be_within(1).of(Time.now)
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
        job.complete
        expect(job).to be_done
      end

      it 'updates updated_at' do
        job.complete
        expect(job.updated_at).to be_within(1).of(Time.now)
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
end
