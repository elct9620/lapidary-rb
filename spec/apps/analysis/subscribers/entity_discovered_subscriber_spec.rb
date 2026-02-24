# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Subscribers::EntityDiscoveredSubscriber do
  subject(:subscriber) { Lapidary::Container['analysis.subscribers.entity_discovered_subscriber'] }

  describe '#on_webhooks_entity_discovered' do
    it 'enqueues a job with the discovered entity' do
      event = Dry::Events::Event.new('webhooks.entity_discovered', { entity_type: 'issue', entity_id: 42 })

      subscriber.on_webhooks_entity_discovered(event)

      row = Lapidary::Container['database'][:jobs].first
      expect(row[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
      expect(JSON.parse(row[:arguments], symbolize_names: true)).to eq(entity_type: 'issue', entity_id: 42)
    end
  end
end
