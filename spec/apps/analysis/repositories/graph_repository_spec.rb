# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Repositories::GraphRepository do
  subject(:repository) { Lapidary::Container['analysis.repositories.graph_repository'] }

  let(:db) { Lapidary::Container['database'] }

  let(:triplet) do
    Analysis::Entities::Triplet.new(
      subject: Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::RUBYIST,
        name: 'matz',
        properties: { is_committer: true }
      ),
      relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
      object: Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::CORE_MODULE,
        name: 'String'
      )
    )
  end

  let(:observation) do
    Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue', source_entity_id: 1)
  end

  describe '#save_triplet' do
    it 'creates nodes for a new triplet' do
      repository.save_triplet(triplet, observation)

      expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
      expect(db[:nodes].where(id: 'core_module://String').count).to eq(1)
    end

    it 'creates an edge with observation' do
      repository.save_triplet(triplet, observation)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      expect(edge).not_to be_nil
      expect(edge[:relationship]).to eq('Maintenance')

      observations = JSON.parse(edge[:properties], symbolize_names: true)
      expect(observations.size).to eq(1)
      expect(observations.first[:source_entity_type]).to eq('issue')
    end

    it 'upserts existing node on second save' do
      repository.save_triplet(triplet, observation)

      updated_triplet = triplet.with(
        subject: triplet.subject.with(properties: { is_committer: true, role: 'creator' })
      )
      other_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                              source_entity_type: 'journal', source_entity_id: 2)
      repository.save_triplet(updated_triplet, other_observation)

      expect(db[:nodes].where(id: 'rubyist://matz').count).to eq(1)
      node = db[:nodes].where(id: 'rubyist://matz').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:role]).to eq('creator')
    end

    it 'preserves existing fields not present in new data during node upsert' do
      repository.save_triplet(triplet, observation)

      # Second save with only a new field, no is_committer
      partial_triplet = triplet.with(
        subject: triplet.subject.with(properties: { display_name: 'Yukihiro Matsumoto' })
      )
      other_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                              source_entity_type: 'journal', source_entity_id: 2)
      repository.save_triplet(partial_triplet, other_observation)

      node = db[:nodes].where(id: 'rubyist://matz').first
      data = JSON.parse(node[:data], symbolize_names: true)
      expect(data[:is_committer]).to be true
      expect(data[:display_name]).to eq('Yukihiro Matsumoto')
    end

    it 'appends observation to existing edge' do
      repository.save_triplet(triplet, observation)

      second_observation = Analysis::Entities::Observation.new(observed_at: Time.now.iso8601,
                                                               source_entity_type: 'journal', source_entity_id: 2)
      result = repository.save_triplet(triplet, second_observation)

      expect(result).to eq(:appended)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      observations = JSON.parse(edge[:properties], symbolize_names: true)
      expect(observations.size).to eq(2)
    end

    it 'skips duplicate observation' do
      repository.save_triplet(triplet, observation)

      result = repository.save_triplet(triplet, observation)

      expect(result).to eq(:duplicate)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://String').first
      observations = JSON.parse(edge[:properties], symbolize_names: true)
      expect(observations.size).to eq(1)
    end

    it 'wraps Sequel errors as GraphError' do
      allow(db).to receive(:[]).with(:nodes).and_raise(Sequel::Error, 'db error')

      expect { repository.save_triplet(triplet, observation) }
        .to raise_error(Analysis::Entities::GraphError, 'db error')
    end

    it 'builds correct URI for Stdlib nodes' do
      stdlib_triplet = Analysis::Entities::Triplet.new(
        subject: triplet.subject,
        relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
        object: Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::STDLIB,
          name: 'json'
        )
      )

      repository.save_triplet(stdlib_triplet, observation)

      expect(db[:nodes].where(id: 'stdlib://json').count).to eq(1)
    end
  end
end
