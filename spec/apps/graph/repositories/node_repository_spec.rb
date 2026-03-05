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
    it 'returns all nodes when include_orphans is true' do
      nodes = repository.search(include_orphans: true)
      expect(nodes.size).to eq(5)
    end

    it 'filters by type' do
      nodes = repository.search(type: 'Rubyist', include_orphans: true)
      expect(nodes.size).to eq(2)
      expect(nodes.map(&:type)).to all(eq('Rubyist'))
    end

    it 'searches by name (from ID)' do
      nodes = repository.search(query: 'matz', include_orphans: true)
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'searches by display_name' do
      nodes = repository.search(query: 'Yukihiro', include_orphans: true)
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'searches case-insensitively' do
      nodes = repository.search(query: 'MATZ', include_orphans: true)
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('rubyist://matz')
    end

    it 'combines type and query filters' do
      nodes = repository.search(type: 'CoreModule', query: 'String', include_orphans: true)
      expect(nodes.size).to eq(1)
      expect(nodes.first.id).to eq('core_module://String')
    end

    it 'respects limit' do
      nodes = repository.search(limit: 2, include_orphans: true)
      expect(nodes.size).to eq(2)
    end

    it 'respects offset' do
      all_nodes = repository.search(include_orphans: true)
      offset_nodes = repository.search(offset: 2, include_orphans: true)
      expect(offset_nodes.size).to eq(3)
      expect(offset_nodes.first.id).to eq(all_nodes[2].id)
    end

    it 'does not treat % as a wildcard' do
      nodes = repository.search(query: '%', include_orphans: true)
      expect(nodes).to be_empty
    end

    it 'does not treat _ as a wildcard' do
      nodes = repository.search(query: 'mat_', include_orphans: true)
      expect(nodes).to be_empty
    end

    it 'returns Node entities' do
      nodes = repository.search(limit: 1, include_orphans: true)
      expect(nodes.first).to be_a(Graph::Entities::Node)
    end
  end

  describe '#count' do
    it 'returns total count with include_orphans' do
      expect(repository.count(include_orphans: true)).to eq(5)
    end

    it 'counts with type filter' do
      expect(repository.count(type: 'CoreModule', include_orphans: true)).to eq(2)
    end

    it 'counts with query filter' do
      expect(repository.count(query: 'matz', include_orphans: true)).to eq(1)
    end

    it 'counts with combined filters' do
      expect(repository.count(type: 'Rubyist', query: 'Sasada', include_orphans: true)).to eq(1)
    end
  end

  describe 'orphan filtering' do
    def seed_edges
      now = Time.now
      db[:edges].insert(source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
                        created_at: now, updated_at: now)
      db[:edges].insert(source: 'rubyist://ko1', target: 'core_module://Array', relationship: 'Contribute',
                        archived_at: now, created_at: now, updated_at: now)
    end

    before { seed_edges }

    it 'excludes nodes with only archived edges by default' do
      nodes = repository.search
      ids = nodes.map(&:id)
      expect(ids).to include('rubyist://matz', 'core_module://String')
      expect(ids).not_to include('stdlib://json')
    end

    it 'excludes orphan nodes (no edges) by default' do
      nodes = repository.search
      ids = nodes.map(&:id)
      expect(ids).not_to include('stdlib://json')
    end

    it 'includes nodes with only archived edges when include_orphans is true' do
      nodes = repository.search(include_orphans: true)
      expect(nodes.size).to eq(5)
    end

    it 'counts exclude orphans by default' do
      expect(repository.count).to eq(2)
    end

    it 'counts include orphans when requested' do
      expect(repository.count(include_orphans: true)).to eq(5)
    end
  end
end
