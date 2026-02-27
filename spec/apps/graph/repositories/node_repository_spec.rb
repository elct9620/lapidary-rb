# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Repositories::NodeRepository do
  subject(:repository) { described_class.new }

  let(:db) { Lapidary::Container['database'] }

  def insert_node(id:, type:, data: '{}')
    now = Time.now
    db[:nodes].insert(id: id, type: type, data: data, created_at: now, updated_at: now)
  end

  def seed_nodes
    insert_node(id: 'rubyist://matz', type: 'Rubyist', data: '{"display_name":"Yukihiro Matsumoto"}')
    insert_node(id: 'rubyist://ko1', type: 'Rubyist', data: '{"display_name":"Koichi Sasada"}')
    insert_node(id: 'core_module://String', type: 'CoreModule')
    insert_node(id: 'core_module://Array', type: 'CoreModule')
    insert_node(id: 'stdlib://json', type: 'Stdlib')
  end

  before { seed_nodes }

  describe '#search' do
    it 'returns all nodes when no filters' do
      nodes = repository.search
      expect(nodes.size).to eq(5)
    end

    it 'filters by type' do
      nodes = repository.search(type: 'Rubyist')
      expect(nodes.size).to eq(2)
      expect(nodes.map(&:type)).to all(eq('Rubyist'))
    end

    it 'searches by name (from ID)' do
      nodes = repository.search(query: 'matz')
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'searches by display_name' do
      nodes = repository.search(query: 'Yukihiro')
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'searches case-insensitively' do
      nodes = repository.search(query: 'MATZ')
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'combines type and query filters' do
      nodes = repository.search(type: 'CoreModule', query: 'String')
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('core_module://String')
    end

    it 'respects limit' do
      nodes = repository.search(limit: 2)
      expect(nodes.size).to eq(2)
    end

    it 'respects offset' do
      all_nodes = repository.search
      offset_nodes = repository.search(offset: 2)
      expect(offset_nodes.size).to eq(3)
      expect(offset_nodes.first.id).to eq(all_nodes[2].id)
    end

    it 'returns Node entities' do
      nodes = repository.search(limit: 1)
      expect(nodes.first).to be_a(Graph::Entities::Node)
    end
  end

  describe '#count' do
    it 'returns total count without filters' do
      expect(repository.count).to eq(5)
    end

    it 'counts with type filter' do
      expect(repository.count(type: 'CoreModule')).to eq(2)
    end

    it 'counts with query filter' do
      expect(repository.count(query: 'matz')).to eq(1)
    end

    it 'counts with combined filters' do
      expect(repository.count(type: 'Rubyist', query: 'Sasada')).to eq(1)
    end
  end
end
