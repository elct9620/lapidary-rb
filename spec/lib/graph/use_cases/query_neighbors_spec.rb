# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::UseCases::QueryNeighbors do
  subject(:use_case) { described_class.new(neighbor_repository: repository) }

  let(:repository) { instance_double(Graph::Repositories::NeighborRepository) }

  let(:matz_node) { Graph::Entities::Node.new(id: 'rubyist://matz', type: 'Rubyist') }
  let(:string_node) { Graph::Entities::Node.new(id: 'core_module://String', type: 'CoreModule') }
  let(:array_node) { Graph::Entities::Node.new(id: 'core_module://Array', type: 'CoreModule') }

  let(:outbound_edge) do
    Graph::Entities::Edge.new(
      source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
      observations: [{ observed_at: '2024-01-15T10:30:00Z', source_entity_type: 'issue', source_entity_id: 1 }]
    )
  end

  let(:inbound_edge) do
    Graph::Entities::Edge.new(
      source: 'core_module://Array', target: 'rubyist://matz', relationship: 'MaintainedBy',
      observations: [{ observed_at: '2024-06-01T00:00:00Z', source_entity_type: 'issue', source_entity_id: 2 }]
    )
  end

  describe '#call' do
    context 'when node exists' do
      before do
        allow(repository).to receive(:find_node).with('rubyist://matz').and_return(matz_node)
        allow(repository).to receive(:find_edges).with('rubyist://matz', direction: 'both')
                                                 .and_return([outbound_edge, inbound_edge])
        allow(repository).to receive(:find_nodes_by_ids)
          .with(match_array(%w[core_module://String core_module://Array]))
          .and_return({ 'core_module://String' => string_node, 'core_module://Array' => array_node })
      end

      it 'returns the node and its neighbors' do
        result = use_case.call(node_id: 'rubyist://matz')

        expect(result[:node]).to eq(matz_node)
        expect(result[:neighbors].size).to eq(2)
        expect(result[:neighbors].map { |n| n.node.id }).to contain_exactly('core_module://String',
                                                                            'core_module://Array')
      end
    end

    context 'when node does not exist' do
      before do
        allow(repository).to receive(:find_node).with('rubyist://unknown').and_return(nil)
      end

      it 'returns nil' do
        result = use_case.call(node_id: 'rubyist://unknown')
        expect(result).to be_nil
      end
    end

    context 'with direction filtering' do
      before do
        allow(repository).to receive(:find_node).with('rubyist://matz').and_return(matz_node)
        allow(repository).to receive(:find_edges).with('rubyist://matz', direction: 'outbound')
                                                 .and_return([outbound_edge])
        allow(repository).to receive(:find_nodes_by_ids)
          .with(%w[core_module://String])
          .and_return({ 'core_module://String' => string_node })
      end

      it 'passes direction to repository' do
        result = use_case.call(node_id: 'rubyist://matz', direction: 'outbound')

        expect(result[:neighbors].size).to eq(1)
        expect(result[:neighbors].first.node.id).to eq('core_module://String')
      end
    end

    context 'with observation time-range filtering' do
      let(:multi_obs_edge) do
        Graph::Entities::Edge.new(
          source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
          observations: [
            { observed_at: '2024-01-15T10:30:00Z', source_entity_type: 'issue', source_entity_id: 1 },
            { observed_at: '2024-07-01T00:00:00Z', source_entity_type: 'journal', source_entity_id: 10 }
          ]
        )
      end

      before do
        allow(repository).to receive(:find_node).with('rubyist://matz').and_return(matz_node)
        allow(repository).to receive(:find_edges).with('rubyist://matz', direction: 'both')
                                                 .and_return([multi_obs_edge, inbound_edge])
        allow(repository).to receive(:find_nodes_by_ids).and_return({
                                                                      'core_module://String' => string_node,
                                                                      'core_module://Array' => array_node
                                                                    })
      end

      it 'filters observations by observed_after' do
        result = use_case.call(node_id: 'rubyist://matz', observed_after: '2024-06-01T00:00:00Z')

        string_neighbor = result[:neighbors].find { |n| n.node.id == 'core_module://String' }
        expect(string_neighbor.edges.first.observations.size).to eq(1)
        expect(string_neighbor.edges.first.observations.first[:source_entity_id]).to eq(10)
      end

      it 'filters observations by observed_before' do
        result = use_case.call(node_id: 'rubyist://matz', observed_before: '2024-02-01T00:00:00Z')

        expect(result[:neighbors].size).to eq(1)
        string_neighbor = result[:neighbors].find { |n| n.node.id == 'core_module://String' }
        expect(string_neighbor.edges.first.observations.size).to eq(1)
        expect(string_neighbor.edges.first.observations.first[:source_entity_id]).to eq(1)
      end

      it 'excludes neighbors with no matching observations' do
        result = use_case.call(node_id: 'rubyist://matz', observed_after: '2025-01-01T00:00:00Z')

        expect(result[:neighbors]).to be_empty
      end
    end
  end
end
