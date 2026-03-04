# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::UseCases::QueryNeighbors do
  subject(:use_case) { described_class.new(neighbor_repository: repository) }

  let(:repository) { Lapidary::Container['graph.repositories.neighbor_repository'] }
  let(:db) { Lapidary::Container['database'] }

  describe '#call' do
    before do
      now = Time.now
      db[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist', created_at: now, updated_at: now)
      db[:nodes].insert(id: 'core_module://String', type: 'CoreModule', created_at: now, updated_at: now)
      db[:nodes].insert(id: 'core_module://Array', type: 'CoreModule', created_at: now, updated_at: now)

      db[:edges].insert(source: 'rubyist://matz', target: 'core_module://String',
                        relationship: 'Contribute', created_at: now, updated_at: now)
      db[:observations].insert(edge_source: 'rubyist://matz', edge_target: 'core_module://String',
                               edge_relationship: 'Contribute',
                               observed_at: Time.iso8601('2024-01-15T10:30:00Z'),
                               source_entity_type: 'issue', source_entity_id: 1, created_at: now)

      db[:edges].insert(source: 'core_module://Array', target: 'rubyist://matz',
                        relationship: 'MaintainedBy', created_at: now, updated_at: now)
      db[:observations].insert(edge_source: 'core_module://Array', edge_target: 'rubyist://matz',
                               edge_relationship: 'MaintainedBy',
                               observed_at: Time.iso8601('2024-06-01T00:00:00Z'),
                               source_entity_type: 'issue', source_entity_id: 2, created_at: now)
    end

    context 'when node exists' do
      it 'returns the node and its neighbors' do
        result = use_case.call(node_id: 'rubyist://matz')

        expect(result[:node].id).to eq('rubyist://matz')
        expect(result[:neighbors].size).to eq(2)
        expect(result[:neighbors].map { |n| n.node.id }).to contain_exactly('core_module://String',
                                                                            'core_module://Array')
      end
    end

    context 'when node does not exist' do
      it 'returns nil' do
        result = use_case.call(node_id: 'rubyist://unknown')
        expect(result).to be_nil
      end
    end

    context 'with direction filtering' do
      it 'returns only outbound neighbors' do
        result = use_case.call(node_id: 'rubyist://matz', direction: Graph::Entities::Direction::OUTBOUND)

        expect(result[:neighbors].size).to eq(1)
        expect(result[:neighbors].first.node.id).to eq('core_module://String')
      end
    end

    context 'with observation time-range filtering' do
      before do
        db[:observations].insert(edge_source: 'rubyist://matz', edge_target: 'core_module://String',
                                 edge_relationship: 'Contribute',
                                 observed_at: Time.iso8601('2024-07-01T00:00:00Z'),
                                 source_entity_type: 'journal', source_entity_id: 10, created_at: Time.now)
      end

      it 'filters observations by observed_after' do
        result = use_case.call(node_id: 'rubyist://matz', observed_after: '2024-06-01T00:00:00Z')

        string_neighbor = result[:neighbors].find { |n| n.node.id == 'core_module://String' }
        expect(string_neighbor.edges.first.observations.size).to eq(1)
        expect(string_neighbor.edges.first.observations.first.source_entity_id).to eq(10)
      end

      it 'filters observations by observed_before' do
        result = use_case.call(node_id: 'rubyist://matz', observed_before: '2024-02-01T00:00:00Z')

        expect(result[:neighbors].size).to eq(1)
        string_neighbor = result[:neighbors].find { |n| n.node.id == 'core_module://String' }
        expect(string_neighbor.edges.first.observations.size).to eq(1)
        expect(string_neighbor.edges.first.observations.first.source_entity_id).to eq(1)
      end

      it 'excludes neighbors with no matching observations' do
        result = use_case.call(node_id: 'rubyist://matz', observed_after: '2025-01-01T00:00:00Z')

        expect(result[:neighbors]).to be_empty
      end
    end
  end
end
