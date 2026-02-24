# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Adapters::AnalysisScheduler do
  subject(:scheduler) { Lapidary::Container['webhooks.adapters.analysis_scheduler'] }

  describe '#schedule' do
    it 'publishes a webhooks.entity_discovered event' do
      received = []
      event_bus = Lapidary::Container['event_bus']
      event_bus.subscribe('webhooks.entity_discovered') do |event|
        received << event.to_h
      end

      scheduler.schedule(entity_type: 'issue', entity_id: 42)

      expect(received).to contain_exactly(
        a_hash_including(entity_type: 'issue', entity_id: 42)
      )
    end
  end
end
