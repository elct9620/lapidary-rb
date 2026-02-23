# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Adapters::AnalysisScheduler do
  subject(:scheduler) { Lapidary::Container['webhooks.adapters.analysis_scheduler'] }

  describe '#schedule' do
    it 'enqueues a job via the job repository' do
      scheduler.schedule(entity_type: 'issue', entity_id: 42)

      row = Lapidary::Container['database'][:jobs].first
      expect(row).to include(entity_type: 'issue', entity_id: '42', status: 'pending')
    end
  end
end
