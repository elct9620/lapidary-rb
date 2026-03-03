# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::Tools::SearchEdgeTool do
  subject(:tool) { described_class.new(database) }

  let(:database) { Lapidary::Container['database'] }

  before do
    database[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist', data: '{}')
    database[:nodes].insert(id: 'core_module://String', type: 'CoreModule', data: '{}')
    database[:nodes].insert(id: 'core_module://Array', type: 'CoreModule', data: '{}')
    database[:edges].insert(
      source: 'rubyist://matz', target: 'core_module://String',
      relationship: 'Maintenance', created_at: Time.now, updated_at: Time.now
    )
    database[:edges].insert(
      source: 'rubyist://matz', target: 'core_module://Array',
      relationship: 'Contribute', created_at: Time.now, updated_at: Time.now,
      archived_at: Time.now
    )
  end

  describe '#execute' do
    it 'finds edges matching source and target' do
      results = JSON.parse(tool.execute(source_name: 'matz', target_name: 'String'))

      expect(results).to contain_exactly(
        a_hash_including('source' => 'rubyist://matz', 'target' => 'core_module://String',
                         'relationship' => 'Maintenance')
      )
    end

    it 'returns an empty array when no matches' do
      results = JSON.parse(tool.execute(source_name: 'nonexistent', target_name: 'String'))

      expect(results).to be_empty
    end

    it 'excludes archived edges' do
      results = JSON.parse(tool.execute(source_name: 'matz', target_name: 'Array'))

      expect(results).to be_empty
    end

    it 'escapes LIKE wildcards in the query' do
      results = JSON.parse(tool.execute(source_name: '%', target_name: '%'))

      expect(results).to be_empty
    end
  end

  describe '#name' do
    it 'returns the tool name' do
      expect(tool.name).to include('search_edge')
    end
  end

  describe '#description' do
    it 'returns the tool description' do
      expect(tool.description).to include('Search for existing edges')
    end
  end
end
