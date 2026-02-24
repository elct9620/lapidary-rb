# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Subscribers::EntityDiscoveredSubscriber do
  subject(:subscriber) { Lapidary::Container['analysis.subscribers.entity_discovered_subscriber'] }

  describe '#on_webhooks_entity_discovered' do
    it 'enqueues a job with rich issue arguments' do
      event = Dry::Events::Event.new('webhooks.entity_discovered', {
                                       entity_type: 'issue',
                                       entity_id: 42,
                                       content: 'Add new feature',
                                       author_username: 'matz',
                                       author_display_name: 'Yukihiro Matsumoto'
                                     })

      subscriber.on_webhooks_entity_discovered(event)

      row = Lapidary::Container['database'][:jobs].first
      expect(row[:status]).to eq(Analysis::Entities::JobStatus::PENDING.to_s)
      expect(JSON.parse(row[:arguments], symbolize_names: true)).to eq(
        entity_type: 'issue',
        entity_id: 42,
        content: 'Add new feature',
        author_username: 'matz',
        author_display_name: 'Yukihiro Matsumoto'
      )
    end

    it 'enqueues a job with rich journal arguments' do
      event = Dry::Events::Event.new('webhooks.entity_discovered', {
                                       entity_type: 'journal',
                                       entity_id: 101,
                                       content: 'Review comment',
                                       author_username: 'nobu',
                                       author_display_name: 'Nobuyoshi Nakada',
                                       issue_id: 42,
                                       issue_content: 'Add new feature'
                                     })

      subscriber.on_webhooks_entity_discovered(event)

      row = Lapidary::Container['database'][:jobs].first
      expect(JSON.parse(row[:arguments], symbolize_names: true)).to eq(
        entity_type: 'journal',
        entity_id: 101,
        content: 'Review comment',
        author_username: 'nobu',
        author_display_name: 'Nobuyoshi Nakada',
        issue_id: 42,
        issue_content: 'Add new feature'
      )
    end
  end
end
