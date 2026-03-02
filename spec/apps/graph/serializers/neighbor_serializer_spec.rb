# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Serializers::NeighborSerializer do
  subject(:serializer) { described_class.new }

  let(:node) { Graph::Entities::Node.new(id: 'rubyist://matz', type: 'Rubyist', data: { display_name: 'Matz' }) }
  let(:neighbor_node) { Graph::Entities::Node.new(id: 'core_module://String', type: 'CoreModule') }

  let(:observation) do
    Graph::Entities::Observation.new(
      observed_at: Time.iso8601('2024-01-15T10:30:00Z'),
      source_entity_type: 'issue',
      source_entity_id: 1,
      evidence: 'matz committed to String'
    )
  end

  let(:edge) do
    Graph::Entities::Edge.new(
      source: 'rubyist://matz',
      target: 'core_module://String',
      relationship: 'Contribute',
      observations: [observation]
    )
  end

  let(:neighbor) { Graph::Entities::Neighbor.new(node: neighbor_node, edges: [edge]) }

  describe '#call' do
    context 'with include_archived: false' do
      let(:output) { { node: node, neighbors: [neighbor], include_archived: false } }

      it 'serializes node and neighbors' do
        result = serializer.call(output)

        expect(result[:node]).to eq({ id: 'rubyist://matz', type: 'Rubyist', data: { display_name: 'Matz' } })
        expect(result[:neighbors].size).to eq(1)
      end

      it 'omits archived_at from edges' do
        result = serializer.call(output)

        edge_hash = result[:neighbors].first[:edges].first
        expect(edge_hash).not_to have_key(:archived_at)
      end

      it 'serializes observations' do
        result = serializer.call(output)

        obs = result[:neighbors].first[:edges].first[:observations].first
        expect(obs[:observed_at]).to eq('2024-01-15T10:30:00Z')
        expect(obs[:source_entity_type]).to eq('issue')
        expect(obs[:source_entity_id]).to eq(1)
        expect(obs[:evidence]).to eq('matz committed to String')
      end
    end

    context 'with include_archived: true' do
      let(:archived_edge) do
        Graph::Entities::Edge.new(
          source: 'rubyist://matz',
          target: 'core_module://String',
          relationship: 'Contribute',
          observations: [observation],
          archived_at: Time.iso8601('2025-06-01T00:00:00Z')
        )
      end

      let(:archived_neighbor) { Graph::Entities::Neighbor.new(node: neighbor_node, edges: [archived_edge]) }
      let(:output) { { node: node, neighbors: [archived_neighbor], include_archived: true } }

      it 'includes archived_at in edges' do
        result = serializer.call(output)

        edge_hash = result[:neighbors].first[:edges].first
        expect(edge_hash[:archived_at]).to eq('2025-06-01T00:00:00Z')
      end
    end

    context 'when observation has nil observed_at' do
      let(:nil_observation) do
        Graph::Entities::Observation.new(
          observed_at: nil,
          source_entity_type: 'issue',
          source_entity_id: 2
        )
      end

      let(:edge_with_nil_obs) do
        Graph::Entities::Edge.new(
          source: 'rubyist://matz',
          target: 'core_module://String',
          relationship: 'Contribute',
          observations: [nil_observation]
        )
      end

      let(:neighbor_with_nil_obs) { Graph::Entities::Neighbor.new(node: neighbor_node, edges: [edge_with_nil_obs]) }
      let(:output) { { node: node, neighbors: [neighbor_with_nil_obs], include_archived: false } }

      it 'serializes observed_at as nil' do
        result = serializer.call(output)

        obs = result[:neighbors].first[:edges].first[:observations].first
        expect(obs[:observed_at]).to be_nil
      end
    end
  end
end
