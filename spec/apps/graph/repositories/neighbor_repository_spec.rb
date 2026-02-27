# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Repositories::NeighborRepository do
  subject(:repository) { Lapidary::Container['graph.repositories.neighbor_repository'] }

  let(:db) { Lapidary::Container['database'] }

  before do
    now = Time.now
    db[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist', data: '{"display_name":"Matz"}',
                      created_at: now, updated_at: now)
    db[:nodes].insert(id: 'core_module://String', type: 'CoreModule', data: '{}',
                      created_at: now, updated_at: now)
    db[:nodes].insert(id: 'core_module://Array', type: 'CoreModule', data: '{}',
                      created_at: now, updated_at: now)

    db[:edges].insert(
      source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
      properties: JSON.generate([{ observed_at: '2024-01-15T10:30:00Z', source_entity_type: 'issue',
                                   source_entity_id: 1 }]),
      created_at: now, updated_at: now
    )
    db[:edges].insert(
      source: 'core_module://Array', target: 'rubyist://matz', relationship: 'MaintainedBy',
      properties: JSON.generate([{ observed_at: '2024-06-01T00:00:00Z', source_entity_type: 'issue',
                                   source_entity_id: 2 }]),
      created_at: now, updated_at: now
    )
  end

  describe '#find_node' do
    it 'returns a Node entity for an existing node' do
      node = repository.find_node('rubyist://matz')

      expect(node).to be_a(Graph::Entities::Node)
      expect(node.id).to eq('rubyist://matz')
      expect(node.type).to eq('Rubyist')
      expect(node.data).to eq({ display_name: 'Matz' })
    end

    it 'returns nil for a non-existent node' do
      expect(repository.find_node('rubyist://unknown')).to be_nil
    end

    it 'wraps Sequel errors as GraphQueryError' do
      allow(db).to receive(:[]).with(:nodes).and_raise(Sequel::Error, 'db error')

      expect { repository.find_node('rubyist://matz') }
        .to raise_error(Graph::Entities::GraphQueryError, 'db error')
    end
  end

  describe '#find_edges' do
    it 'returns outbound edges' do
      edges = repository.find_edges('rubyist://matz', direction: Graph::Entities::Direction::OUTBOUND)

      expect(edges.size).to eq(1)
      expect(edges.first.source).to eq('rubyist://matz')
      expect(edges.first.target).to eq('core_module://String')
    end

    it 'returns inbound edges' do
      edges = repository.find_edges('rubyist://matz', direction: Graph::Entities::Direction::INBOUND)

      expect(edges.size).to eq(1)
      expect(edges.first.source).to eq('core_module://Array')
      expect(edges.first.target).to eq('rubyist://matz')
    end

    it 'returns both directions by default' do
      edges = repository.find_edges('rubyist://matz')

      expect(edges.size).to eq(2)
    end

    it 'parses observations from properties JSON into Observation objects' do
      edges = repository.find_edges('rubyist://matz', direction: Graph::Entities::Direction::OUTBOUND)

      observation = edges.first.observations.first
      expect(observation).to be_a(Graph::Entities::Observation)
      expect(observation.observed_at).to eq(Time.iso8601('2024-01-15T10:30:00Z'))
      expect(observation.source_entity_type).to eq('issue')
      expect(observation.source_entity_id).to eq(1)
    end
  end

  describe '#find_nodes_by_ids' do
    it 'returns a hash of id to Node' do
      nodes = repository.find_nodes_by_ids(%w[core_module://String core_module://Array])

      expect(nodes.size).to eq(2)
      expect(nodes['core_module://String']).to be_a(Graph::Entities::Node)
      expect(nodes['core_module://Array']).to be_a(Graph::Entities::Node)
    end

    it 'returns an empty hash for empty ids' do
      expect(repository.find_nodes_by_ids([])).to eq({})
    end
  end
end
