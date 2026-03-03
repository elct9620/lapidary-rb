# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::EdgeArchiveRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.edge_archive_repository'] }

  let(:db) { Lapidary::Container['database'] }
  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }

  let(:triplet) do
    Analysis::Entities::Triplet.new(
      subject: Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::RUBYIST,
        name: 'matz',
        properties: { role: 'maintainer' }
      ),
      relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
      object: Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::CORE_MODULE,
        name: 'String'
      )
    )
  end

  let(:observation) do
    Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue', source_entity_id: 1)
  end

  describe '#archive_expired' do
    let(:old_time) { Time.now - (86_400 * 200) }
    let(:recent_time) { Time.now - 3600 }
    let(:cutoff) { Time.now - (86_400 * 180) }

    before do
      graph_repository.save_triplet(triplet, observation)
    end

    it 'archives edges whose latest observation is before cutoff' do
      db[:observations].where(edge_source: 'rubyist://matz').update(observed_at: old_time)

      result = repository.archive_expired(cutoff: cutoff)

      expect(result.archived_count).to eq(1)
      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge[:archived_at]).not_to be_nil
    end

    it 'does not archive edges with recent observations' do
      db[:observations].where(edge_source: 'rubyist://matz').update(observed_at: recent_time)

      result = repository.archive_expired(cutoff: cutoff)

      expect(result.archived_count).to eq(0)
      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge[:archived_at]).to be_nil
    end

    it 'returns entity pairs from archived edge observations' do
      db[:observations].where(edge_source: 'rubyist://matz').update(observed_at: old_time)

      result = repository.archive_expired(cutoff: cutoff)

      expect(result.entity_pairs).to contain_exactly(
        { entity_type: 'issue', entity_id: 1 }
      )
    end

    it 'skips already archived edges' do
      db[:observations].where(edge_source: 'rubyist://matz').update(observed_at: old_time)
      db[:edges].where(source: 'rubyist://matz').update(archived_at: Time.now)

      result = repository.archive_expired(cutoff: cutoff)

      expect(result.archived_count).to eq(0)
    end
  end

  describe '#archive_by_key' do
    before do
      graph_repository.save_triplet(triplet, observation)
    end

    it 'archives the specified edge' do
      result = repository.archive_by_key(source: 'rubyist://matz', target: 'core_module://String',
                                         relationship: 'Maintenance')

      expect(result.archived_count).to eq(1)
      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge[:archived_at]).not_to be_nil
    end

    it 'returns entity pairs from the edge observations' do
      result = repository.archive_by_key(source: 'rubyist://matz', target: 'core_module://String',
                                         relationship: 'Maintenance')

      expect(result.entity_pairs).to contain_exactly({ entity_type: 'issue', entity_id: 1 })
    end

    it 'raises GraphError when edge does not exist' do
      expect do
        repository.archive_by_key(source: 'rubyist://nobody', target: 'core_module://String',
                                  relationship: 'Maintenance')
      end.to raise_error(Analysis::Entities::GraphError, 'Edge not found')
    end
  end
end
