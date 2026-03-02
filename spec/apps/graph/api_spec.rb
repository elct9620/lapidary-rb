# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Graph::API do
  include Rack::Test::Methods

  def app
    described_class
  end

  let(:db) { Lapidary::Container['database'] }

  def seed_nodes(db)
    now = Time.now
    db[:nodes].insert(id: 'rubyist://matz', type: 'Rubyist',
                      data: '{"display_name":"Yukihiro Matsumoto"}', created_at: now, updated_at: now)
    db[:nodes].insert(id: 'core_module://String', type: 'CoreModule', data: '{}',
                      created_at: now, updated_at: now)
    db[:nodes].insert(id: 'core_module://Array', type: 'CoreModule', data: '{}',
                      created_at: now, updated_at: now)
  end

  def seed_edges(db) # rubocop:disable Metrics/MethodLength
    now = Time.now
    db[:edges].insert(
      source: 'rubyist://matz', target: 'core_module://String', relationship: 'Contribute',
      created_at: now, updated_at: now
    )
    db[:observations].insert(edge_source: 'rubyist://matz', edge_target: 'core_module://String',
                             edge_relationship: 'Contribute', observed_at: '2024-01-15T10:30:00Z',
                             source_entity_type: 'issue', source_entity_id: 1,
                             evidence: 'Discussed String encoding', created_at: now)
    db[:observations].insert(edge_source: 'rubyist://matz', edge_target: 'core_module://String',
                             edge_relationship: 'Contribute', observed_at: '2024-07-01T00:00:00Z',
                             source_entity_type: 'journal', source_entity_id: 10,
                             evidence: 'Follow-up comment', created_at: now)

    db[:edges].insert(
      source: 'core_module://Array', target: 'rubyist://matz', relationship: 'MaintainedBy',
      created_at: now, updated_at: now
    )
    db[:observations].insert(edge_source: 'core_module://Array', edge_target: 'rubyist://matz',
                             edge_relationship: 'MaintainedBy', observed_at: '2024-06-01T00:00:00Z',
                             source_entity_type: 'issue', source_entity_id: 2, created_at: now)
  end

  def seed_graph
    seed_nodes(db)
    seed_edges(db)
  end

  describe 'GET /graph/nodes' do
    context 'with no filters' do
      before do
        seed_nodes(db)
        get '/graph/nodes', include_orphans: 'true'
      end

      it 'returns 200 OK' do
        expect(last_response.status).to eq(200)
      end

      it 'returns all nodes' do
        body = JSON.parse(last_response.body)
        expect(body['nodes'].size).to eq(3)
      end

      it 'returns total count' do
        body = JSON.parse(last_response.body)
        expect(body['total']).to eq(3)
      end

      it 'returns default pagination metadata' do
        body = JSON.parse(last_response.body)
        expect(body['limit']).to eq(20)
        expect(body['offset']).to eq(0)
      end
    end

    context 'with type filter' do
      before do
        seed_nodes(db)
        get '/graph/nodes', type: 'CoreModule', include_orphans: 'true'
      end

      it 'returns only matching type' do
        body = JSON.parse(last_response.body)
        types = body['nodes'].map { |n| n['type'] }
        expect(types).to all(eq('CoreModule'))
      end

      it 'returns correct total' do
        body = JSON.parse(last_response.body)
        expect(body['total']).to eq(2)
      end
    end

    context 'with q search matching node name' do
      before do
        seed_nodes(db)
        get '/graph/nodes', q: 'matz', include_orphans: 'true'
      end

      it 'returns matching nodes' do
        body = JSON.parse(last_response.body)
        expect(body['nodes'].size).to eq(1)
        expect(body['nodes'].first['id']).to eq('rubyist://matz')
      end
    end

    context 'with q search matching display_name' do
      before do
        seed_nodes(db)
        get '/graph/nodes', q: 'Yukihiro', include_orphans: 'true'
      end

      it 'returns matching nodes' do
        body = JSON.parse(last_response.body)
        expect(body['nodes'].size).to eq(1)
        expect(body['nodes'].first['id']).to eq('rubyist://matz')
      end
    end

    context 'with type and q combined' do
      before do
        seed_nodes(db)
        get '/graph/nodes', type: 'CoreModule', q: 'String', include_orphans: 'true'
      end

      it 'returns nodes matching both filters' do
        body = JSON.parse(last_response.body)
        expect(body['nodes'].size).to eq(1)
        expect(body['nodes'].first['id']).to eq('core_module://String')
      end
    end

    context 'with pagination' do
      before do
        seed_nodes(db)
        get '/graph/nodes', limit: '2', offset: '1', include_orphans: 'true'
      end

      it 'respects limit and offset' do
        body = JSON.parse(last_response.body)
        expect(body['nodes'].size).to eq(2)
        expect(body['limit']).to eq(2)
        expect(body['offset']).to eq(1)
      end

      it 'returns full total regardless of pagination' do
        body = JSON.parse(last_response.body)
        expect(body['total']).to eq(3)
      end
    end

    context 'with orphan filtering' do
      before do
        seed_graph
      end

      it 'excludes orphan nodes by default' do
        get '/graph/nodes'
        body = JSON.parse(last_response.body)
        ids = body['nodes'].map { |n| n['id'] }
        expect(ids).to contain_exactly('rubyist://matz', 'core_module://String', 'core_module://Array')
      end

      it 'includes orphan nodes when include_orphans=true' do
        get '/graph/nodes', include_orphans: 'true'
        body = JSON.parse(last_response.body)
        expect(body['total']).to eq(3)
      end
    end

    context 'with invalid type' do
      before { get '/graph/nodes', type: 'Invalid' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end

      it 'returns error message' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('type')
      end
    end

    context 'with invalid limit' do
      before { get '/graph/nodes', limit: '0' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with invalid offset' do
      before { get '/graph/nodes', offset: '-1' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with empty q' do
      before { get '/graph/nodes', q: '' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'when database error occurs' do
      before do
        allow(Lapidary::Container['database']).to receive(:[]).with(:nodes)
                                                              .and_raise(Sequel::Error, 'db error')
        get '/graph/nodes'
      end

      it 'returns 500 Internal Server Error' do
        expect(last_response.status).to eq(500)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'internal server error')
      end
    end
  end

  describe 'GET /graph/neighbors' do
    context 'with a valid request' do
      before do
        seed_graph
        get '/graph/neighbors', node_id: 'rubyist://matz'
      end

      it 'returns 200 OK' do
        expect(last_response.status).to eq(200)
      end

      it 'returns JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'returns the queried node' do
        body = JSON.parse(last_response.body)
        expect(body['node']['id']).to eq('rubyist://matz')
        expect(body['node']['type']).to eq('Rubyist')
        expect(body['node']['data']['display_name']).to eq('Yukihiro Matsumoto')
      end

      it 'returns neighbors with edges' do
        body = JSON.parse(last_response.body)
        expect(body['neighbors'].size).to eq(2)

        ids = body['neighbors'].map { |n| n['node']['id'] }
        expect(ids).to contain_exactly('core_module://String', 'core_module://Array')
      end
    end

    context 'with direction=outbound' do
      before do
        seed_graph
        get '/graph/neighbors', node_id: 'rubyist://matz', direction: 'outbound'
      end

      it 'returns only outbound neighbors' do
        body = JSON.parse(last_response.body)
        expect(body['neighbors'].size).to eq(1)
        expect(body['neighbors'].first['node']['id']).to eq('core_module://String')
      end
    end

    context 'with direction=inbound' do
      before do
        seed_graph
        get '/graph/neighbors', node_id: 'rubyist://matz', direction: 'inbound'
      end

      it 'returns only inbound neighbors' do
        body = JSON.parse(last_response.body)
        expect(body['neighbors'].size).to eq(1)
        expect(body['neighbors'].first['node']['id']).to eq('core_module://Array')
      end
    end

    context 'with time-range filtering' do
      before do
        seed_graph
        get '/graph/neighbors', node_id: 'rubyist://matz',
                                observed_after: '2024-06-01T00:00:00Z',
                                observed_before: '2024-12-31T23:59:59Z'
      end

      it 'filters observations within the time range' do
        body = JSON.parse(last_response.body)
        string_neighbor = body['neighbors'].find { |n| n['node']['id'] == 'core_module://String' }
        observations = string_neighbor['edges'].first['observations']

        expect(observations.size).to eq(1)
        expect(observations.first['source_entity_id']).to eq(10)
      end

      it 'includes neighbors with matching observations' do
        body = JSON.parse(last_response.body)
        ids = body['neighbors'].map { |n| n['node']['id'] }
        expect(ids).to contain_exactly('core_module://String', 'core_module://Array')
      end
    end

    context 'with time-range excluding all observations' do
      before do
        seed_graph
        get '/graph/neighbors', node_id: 'rubyist://matz', observed_after: '2025-01-01T00:00:00Z'
      end

      it 'returns empty neighbors' do
        body = JSON.parse(last_response.body)
        expect(body['neighbors']).to be_empty
      end

      it 'still returns the queried node' do
        body = JSON.parse(last_response.body)
        expect(body['node']['id']).to eq('rubyist://matz')
      end
    end

    context 'with missing node_id' do
      before { get '/graph/neighbors' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end

      it 'returns error message with field name' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('node_id')
      end
    end

    context 'with invalid node_id format' do
      before { get '/graph/neighbors', node_id: 'invalid-format' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body['errors']).to have_key('node_id')
      end
    end

    context 'with invalid direction' do
      before { get '/graph/neighbors', node_id: 'rubyist://matz', direction: 'sideways' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with invalid observed_after' do
      before { get '/graph/neighbors', node_id: 'rubyist://matz', observed_after: 'not-a-date' }

      it 'returns 400 Bad Request' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'when node not found' do
      before { get '/graph/neighbors', node_id: 'rubyist://unknown' }

      it 'returns 404 Not Found' do
        expect(last_response.status).to eq(404)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'node not found')
      end
    end

    context 'with archived edges' do
      before do
        seed_graph
        db[:edges].where(source: 'core_module://Array').update(archived_at: Time.now)
      end

      it 'excludes archived edges by default' do
        get '/graph/neighbors', node_id: 'rubyist://matz'
        body = JSON.parse(last_response.body)
        expect(body['neighbors'].size).to eq(1)
        expect(body['neighbors'].first['node']['id']).to eq('core_module://String')
      end

      it 'includes archived edges when include_archived=true' do
        get '/graph/neighbors', node_id: 'rubyist://matz', include_archived: 'true'
        body = JSON.parse(last_response.body)
        expect(body['neighbors'].size).to eq(2)
      end

      it 'includes archived_at in edge serialization when include_archived=true' do
        get '/graph/neighbors', node_id: 'rubyist://matz', include_archived: 'true'
        body = JSON.parse(last_response.body)
        archived_neighbor = body['neighbors'].find { |n| n['node']['id'] == 'core_module://Array' }
        expect(archived_neighbor['edges'].first).to have_key('archived_at')
        expect(archived_neighbor['edges'].first['archived_at']).not_to be_nil
      end

      it 'does not include archived_at field when include_archived is not set' do
        get '/graph/neighbors', node_id: 'rubyist://matz'
        body = JSON.parse(last_response.body)
        string_neighbor = body['neighbors'].find { |n| n['node']['id'] == 'core_module://String' }
        expect(string_neighbor['edges'].first).not_to have_key('archived_at')
      end
    end

    context 'when database error occurs' do
      before do
        allow(Lapidary::Container['database']).to receive(:[]).with(:nodes)
                                                              .and_raise(Sequel::Error, 'db error')
        get '/graph/neighbors', node_id: 'rubyist://matz'
      end

      it 'returns 500 Internal Server Error' do
        expect(last_response.status).to eq(500)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'internal server error')
      end
    end
  end
end
