# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::GraphRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.graph_repository'] }

  let(:db) { Lapidary::Container['database'] }

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

  describe '#save_triplet' do
    it 'creates nodes for a new triplet' do
      repository.save_triplet(triplet, observation)

      expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
      expect(db[:nodes].where(id: 'core_module://String').count).to eq(1)
    end

    it 'creates an edge with observation in observations table' do
      repository.save_triplet(triplet, observation)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge).not_to be_nil
      expect(edge[:relationship]).to eq('Maintenance')

      obs_rows = db[:observations].where(edge_source: 'rubyist://matz', edge_target: 'core_module://String').all
      expect(obs_rows.size).to eq(1)
      expect(obs_rows.first[:source_entity_type]).to eq('issue')
    end

    it 'upserts existing node on second save' do
      repository.save_triplet(triplet, observation)

      updated_triplet = triplet.with(
        subject: triplet.subject.with(properties: { role: 'maintainer', title: 'creator' })
      )
      other_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                              source_entity_type: 'journal', source_entity_id: 2)
      repository.save_triplet(updated_triplet, other_observation)

      expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
      node = db[:nodes].where(id: 'rubyist://matz').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:title]).to eq('creator')
    end

    it 'preserves existing fields not present in new data during node upsert' do
      repository.save_triplet(triplet, observation)

      # Second save with only a new field, no role
      partial_triplet = triplet.with(
        subject: triplet.subject.with(properties: { display_name: 'Yukihiro Matsumoto' })
      )
      other_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                              source_entity_type: 'journal', source_entity_id: 2)
      repository.save_triplet(partial_triplet, other_observation)

      node = db[:nodes].where(id: 'rubyist://matz').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:role]).to eq('maintainer')
      expect(data[:display_name]).to eq('Yukihiro Matsumoto')
    end

    it 'appends observation to existing edge' do
      repository.save_triplet(triplet, observation)

      second_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                               source_entity_type: 'journal', source_entity_id: 2)
      result = repository.save_triplet(triplet, second_observation)

      expect(result).to eq(:appended)

      obs_rows = db[:observations].where(edge_source: 'rubyist://matz', edge_target: 'core_module://String').all
      expect(obs_rows.size).to eq(2)
    end

    it 'skips duplicate observation' do
      repository.save_triplet(triplet, observation)

      result = repository.save_triplet(triplet, observation)

      expect(result).to eq(:duplicate)

      obs_rows = db[:observations].where(edge_source: 'rubyist://matz', edge_target: 'core_module://String').all
      expect(obs_rows.size).to eq(1)
    end

    it 'wraps Sequel errors as GraphError' do
      allow(db).to receive(:[]).with(:nodes).and_raise(Sequel::Error, 'db error')

      expect { repository.save_triplet(triplet, observation) }
        .to raise_error(Analysis::Entities::GraphError, 'db error')
    end

    it 'clears archived_at when appending observation to archived edge' do
      repository.save_triplet(triplet, observation)

      db[:edges].where(source: 'rubyist://matz', target: 'core_module://String')
                .update(archived_at: Time.now)

      second_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                               source_entity_type: 'journal', source_entity_id: 2)
      repository.save_triplet(triplet, second_observation)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge[:archived_at]).to be_nil
    end

    it 'builds correct URI for Stdlib nodes' do
      stdlib_triplet = Analysis::Entities::Triplet.new(
        subject: triplet.subject,
        relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
        object: Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::STDLIB,
          name: 'json'
        )
      )

      repository.save_triplet(stdlib_triplet, observation)

      expect(db[:nodes].where(id: 'stdlib://json').count).to eq(1)
    end
  end

  describe '#archive_expired' do
    let(:old_time) { Time.now - (86_400 * 200) }
    let(:recent_time) { Time.now - 3600 }
    let(:cutoff) { Time.now - (86_400 * 180) }

    before do
      repository.save_triplet(triplet, observation)
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
end
