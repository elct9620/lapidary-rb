# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::UseCases::QueryNodes do
  subject(:use_case) { described_class.new(node_repository: node_repository) }

  let(:node_repository) { Lapidary::Container['graph.repositories.node_repository'] }
  let(:db) { Lapidary::Container['database'] }

  describe '#call' do
    before do
      db[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist',
                        data: '{"display_name":"Yukihiro Matsumoto"}',
                        created_at: Time.now, updated_at: Time.now)
      db[:nodes].insert(id: 'core_module://String', type: 'CoreModule',
                        created_at: Time.now, updated_at: Time.now)
      db[:edges].insert(source: 'rubyist://matz', target: 'core_module://String',
                        relationship: 'Contribute',
                        created_at: Time.now, updated_at: Time.now)
      db[:observations].insert(edge_source: 'rubyist://matz', edge_target: 'core_module://String',
                               edge_relationship: 'Contribute',
                               observed_at: Time.now, source_entity_type: 'issue', source_entity_id: 1,
                               created_at: Time.now)
    end

    it 'returns nodes, total, limit, and offset' do
      result = use_case.call

      expect(result[:nodes].size).to eq(2)
      expect(result[:total]).to eq(2)
      expect(result[:limit]).to eq(20)
      expect(result[:offset]).to eq(0)
    end

    it 'filters by type' do
      result = use_case.call(type: 'Rubyist')

      expect(result[:nodes].size).to eq(1)
      expect(result[:nodes].first.id).to eq('rubyist://matz')
      expect(result[:total]).to eq(1)
    end

    it 'applies limit and offset' do
      result = use_case.call(limit: 1, offset: 0)

      expect(result[:nodes].size).to eq(1)
      expect(result[:limit]).to eq(1)
      expect(result[:offset]).to eq(0)
    end

    it 'uses default limit and offset' do
      result = use_case.call

      expect(result[:limit]).to eq(20)
      expect(result[:offset]).to eq(0)
    end
  end
end
