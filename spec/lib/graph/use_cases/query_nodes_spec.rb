# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::UseCases::QueryNodes do
  subject(:use_case) { described_class.new(node_repository: node_repository) }

  let(:node_repository) { instance_double(Graph::Repositories::NodeRepository) }
  let(:sample_nodes) do
    [
      Graph::Entities::Node.new(id: 'rubyist://matz', type: 'Rubyist', data: { display_name: 'Yukihiro Matsumoto' }),
      Graph::Entities::Node.new(id: 'core_module://String', type: 'CoreModule')
    ]
  end

  describe '#call' do
    before do
      allow(node_repository).to receive(:search).and_return(sample_nodes)
      allow(node_repository).to receive(:count).and_return(2)
    end

    it 'returns nodes, total, limit, and offset' do
      result = use_case.call

      expect(result[:nodes]).to eq(sample_nodes)
      expect(result[:total]).to eq(2)
      expect(result[:limit]).to eq(20)
      expect(result[:offset]).to eq(0)
    end

    it 'passes parameters to repository search' do
      use_case.call(type: 'Rubyist', query: 'matz', limit: 10, offset: 5)

      expect(node_repository).to have_received(:search).with(type: 'Rubyist', query: 'matz', limit: 10, offset: 5)
    end

    it 'passes parameters to repository count' do
      use_case.call(type: 'Rubyist', query: 'matz', limit: 10, offset: 5)

      expect(node_repository).to have_received(:count).with(type: 'Rubyist', query: 'matz')
    end

    it 'uses default limit and offset' do
      use_case.call

      expect(node_repository).to have_received(:search).with(type: nil, query: nil, limit: 20, offset: 0)
    end
  end
end
