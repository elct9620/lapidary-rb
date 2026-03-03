# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::NodeRenamer do
  subject(:renamer) { Lapidary::Container['node_renamer'] }

  let(:db) { Lapidary::Container['database'] }
  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }

  let(:observation) do
    Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                        source_entity_id: 1)
  end

  def make_triplet(subject_name:, object_name:, relationship: Analysis::Entities::RelationshipType::CONTRIBUTE)
    Analysis::Entities::Triplet.new(
      subject: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::RUBYIST, name: subject_name),
      relationship: relationship,
      object: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::CORE_MODULE, name: object_name)
    )
  end

  describe '#call' do
    it 'renames a node and updates edges and observations' do
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      expect(db[:nodes].where(id: 'rubyist://old_user').count).to eq(0)
      expect(db[:nodes].where(id: 'rubyist://new_user').count).to eq(1)

      edge = db[:edges].where(source: 'rubyist://new_user', target: 'core_module://Array').first
      expect(edge).not_to be_nil

      obs = db[:observations].where(edge_source: 'rubyist://new_user').first
      expect(obs).not_to be_nil
      expect(obs[:source_entity_id]).to eq(1)
    end

    it 'infers display_name from parenthetical annotation in old ID' do
      triplet = make_triplet(subject_name: 'st0012 (Stan Lo)', object_name: 'Array')
      graph_repository.save_triplet(triplet, observation)

      old_id = 'rubyist://st0012 (Stan Lo)'
      renamer.call(old_id, 'rubyist://st0012')

      node = db[:nodes].where(id: 'rubyist://st0012').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:display_name]).to eq('Stan Lo')
    end

    it 'does not overwrite existing display_name when inferring' do
      triplet = make_triplet(subject_name: 'st0012 (Stan Lo)', object_name: 'Array')
      graph_repository.save_triplet(triplet, observation)

      # Manually set display_name on the node
      existing_data = JSON.generate({ display_name: 'Original Name' })
      db[:nodes].where(id: 'rubyist://st0012 (Stan Lo)').update(data: existing_data)

      renamer.call('rubyist://st0012 (Stan Lo)', 'rubyist://st0012')

      node = db[:nodes].where(id: 'rubyist://st0012').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:display_name]).to eq('Original Name')
    end

    it 'merges nodes when target already exists' do
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)
      other_obs = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                                      source_entity_id: 2)
      graph_repository.save_triplet(make_triplet(subject_name: 'new_user', object_name: 'String'), other_obs)

      # Add data to old node
      db[:nodes].where(id: 'rubyist://old_user').update(data: JSON.generate({ role: 'contributor' }))
      # Target node has different data
      db[:nodes].where(id: 'rubyist://new_user').update(data: JSON.generate({ team: 'core' }))

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      expect(db[:nodes].where(id: 'rubyist://old_user').count).to eq(0)
      node = db[:nodes].where(id: 'rubyist://new_user').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:role]).to eq('contributor')
      expect(data[:team]).to eq('core')
    end

    it 'merges edges when both nodes share an edge to the same target' do
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)
      other_obs = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                                      source_entity_id: 2)
      graph_repository.save_triplet(make_triplet(subject_name: 'new_user', object_name: 'Array'), other_obs)

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      edges = db[:edges].where(source: 'rubyist://new_user', target: 'core_module://Array').all
      expect(edges.size).to eq(1)

      obs = db[:observations].where(edge_source: 'rubyist://new_user', edge_target: 'core_module://Array').all
      expect(obs.size).to eq(2)
    end

    it 'skips duplicate observations when merging edges' do
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)
      # Same observation (same source_entity_type + source_entity_id) on target edge
      graph_repository.save_triplet(make_triplet(subject_name: 'new_user', object_name: 'Array'), observation)

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      obs = db[:observations].where(edge_source: 'rubyist://new_user', edge_target: 'core_module://Array').all
      expect(obs.size).to eq(1)
    end

    it 'merges mixed duplicate and unique observations when edges overlap' do
      # old_user -> Array with obs from issue 1 and issue 3
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)
      unique_obs = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                                       source_entity_id: 3)
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), unique_obs)

      # new_user -> Array with obs from issue 1 (duplicate) and issue 2 (unique to target)
      graph_repository.save_triplet(make_triplet(subject_name: 'new_user', object_name: 'Array'), observation)
      other_obs = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                                      source_entity_id: 2)
      graph_repository.save_triplet(make_triplet(subject_name: 'new_user', object_name: 'Array'), other_obs)

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      obs = db[:observations].where(edge_source: 'rubyist://new_user', edge_target: 'core_module://Array').all
      entity_ids = obs.map { |o| o[:source_entity_id] }.sort
      # issue 1 (kept from target), issue 2 (target-only), issue 3 (repointed from source)
      expect(entity_ids).to eq([1, 2, 3])
    end

    it 'raises NodeNotFoundError when old node does not exist' do
      expect { renamer.call('rubyist://nonexistent', 'rubyist://target') }
        .to raise_error(Lapidary::NodeRenamer::NodeNotFoundError, 'node not found: rubyist://nonexistent')
    end

    it 'leaves foreign keys valid after rename' do
      graph_repository.save_triplet(make_triplet(subject_name: 'old_user', object_name: 'Array'), observation)

      renamer.call('rubyist://old_user', 'rubyist://new_user')

      fk_violations = db.fetch('PRAGMA foreign_key_check').all
      expect(fk_violations).to be_empty
    end
  end
end
