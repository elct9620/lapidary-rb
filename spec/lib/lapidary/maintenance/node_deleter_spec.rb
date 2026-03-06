# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Maintenance::NodeDeleter do
  subject(:deleter) { Lapidary::Container['maintenance.node_deleter'] }

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
    it 'deletes an orphan node with no edges' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)

      # Remove all edges to make the node orphan
      db[:observations].where(edge_source: 'rubyist://user1').delete
      db[:edges].where(source: 'rubyist://user1').delete

      deleter.call('rubyist://user1')

      expect(db[:nodes].where(id: 'rubyist://user1').count).to eq(0)
    end

    it 'raises NodeNotFoundError for non-existent node' do
      expect { deleter.call('rubyist://nonexistent') }
        .to raise_error(Lapidary::Maintenance::NodeDeleter::NodeNotFoundError,
                        'node not found: rubyist://nonexistent')
    end

    it 'raises NodeHasActiveEdgesError when active edges exist' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)

      expect { deleter.call('rubyist://user1') }
        .to raise_error(Lapidary::Maintenance::NodeDeleter::NodeHasActiveEdgesError,
                        'node still has active edges: rubyist://user1')
    end

    it 'raises NodeHasActiveEdgesError when node is only a target of edges' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)

      expect { deleter.call('core_module://Array') }
        .to raise_error(Lapidary::Maintenance::NodeDeleter::NodeHasActiveEdgesError,
                        'node still has active edges: core_module://Array')
    end

    it 'deletes node and purges archived edges and observations' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)

      # Archive the edge but keep it in the table
      db[:edges].where(source: 'rubyist://user1').update(archived_at: Time.now)

      deleter.call('rubyist://user1')

      expect(db[:nodes].where(id: 'rubyist://user1').count).to eq(0)
      expect(db[:edges].where(Sequel.or(source: 'rubyist://user1', target: 'rubyist://user1')).count).to eq(0)
      expect(db[:observations].where(edge_source: 'rubyist://user1').count).to eq(0)
    end

    it 'purges archived edges when node is the target' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)

      db[:edges].where(target: 'core_module://Array').update(archived_at: Time.now)

      deleter.call('core_module://Array')

      expect(db[:nodes].where(id: 'core_module://Array').count).to eq(0)
      expect(db[:edges].where(Sequel.or(source: 'core_module://Array', target: 'core_module://Array')).count).to eq(0)
      expect(db[:observations].where(edge_target: 'core_module://Array').count).to eq(0)
    end

    it 'raises NodeHasActiveEdgesError when active edges exist alongside archived ones' do
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'Array'), observation)
      graph_repository.save_triplet(make_triplet(subject_name: 'user1', object_name: 'String'), observation)

      # Archive only one edge
      db[:edges].where(source: 'rubyist://user1', target: 'core_module://Array').update(archived_at: Time.now)

      expect { deleter.call('rubyist://user1') }
        .to raise_error(Lapidary::Maintenance::NodeDeleter::NodeHasActiveEdgesError,
                        'node still has active edges: rubyist://user1')
    end
  end
end
