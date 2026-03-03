# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::Tools::SearchNodeTool do
  subject(:tool) { described_class.new(database) }

  let(:database) { Lapidary::Container['database'] }

  before do
    database[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist', data: '{"display_name":"Yukihiro Matsumoto"}')
    database[:nodes].insert(id: 'rubyist://nobu', type: 'Rubyist', data: '{"display_name":"Nobuyoshi Nakada"}')
    database[:nodes].insert(id: 'core_module://String', type: 'CoreModule', data: '{}')
  end

  describe '#execute' do
    it 'finds nodes matching the query' do
      results = JSON.parse(tool.execute(query: 'matz'))

      expect(results).to contain_exactly(a_hash_including('id' => 'rubyist://matz'))
    end

    it 'returns multiple matches' do
      results = JSON.parse(tool.execute(query: 'rubyist'))

      expect(results.size).to eq(2)
    end

    it 'filters by type when provided' do
      results = JSON.parse(tool.execute(query: 'String', type: 'CoreModule'))

      expect(results).to contain_exactly(a_hash_including('type' => 'CoreModule'))
    end

    it 'returns an empty array when no matches' do
      results = JSON.parse(tool.execute(query: 'nonexistent'))

      expect(results).to be_empty
    end

    it 'finds nodes by display_name in data' do
      results = JSON.parse(tool.execute(query: 'Yukihiro'))

      expect(results).to contain_exactly(a_hash_including('id' => 'rubyist://matz'))
    end

    it 'includes data in results' do
      results = JSON.parse(tool.execute(query: 'matz'))

      expect(results.first).to have_key('data')
    end

    it 'escapes LIKE wildcards in the query' do
      results = JSON.parse(tool.execute(query: '%'))

      expect(results).to be_empty
    end
  end

  describe '#name' do
    it 'returns the tool name' do
      expect(tool.name).to include('search_node')
    end
  end

  describe '#description' do
    it 'returns the tool description' do
      expect(tool.description).to include('Search for existing nodes in the knowledge graph by name or display name')
    end
  end
end
