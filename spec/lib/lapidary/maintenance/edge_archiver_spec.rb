# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Maintenance::EdgeArchiver do
  subject(:archiver) { Lapidary::Container['maintenance.edge_archiver'] }

  let(:db) { Lapidary::Container['database'] }
  let(:graph_repository) { Lapidary::Container['analysis.repositories.graph_repository'] }

  let(:triplet) do
    Analysis::Entities::Triplet.new(
      subject: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::RUBYIST, name: 'matz'),
      relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
      object: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::CORE_MODULE, name: 'Array')
    )
  end

  let(:observation) do
    Analysis::Entities::Observation.new(observed_at: Time.now.iso8601, source_entity_type: 'issue',
                                        source_entity_id: 42)
  end

  describe '#call' do
    before do
      graph_repository.save_triplet(triplet, observation)
      db[:analysis_records].insert(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)
    end

    it 'archives the edge and clears analysis records' do
      result = archiver.call(source: 'rubyist://matz', target: 'core_module://Array', relationship: 'Contribute')

      expect(result[:archived]).to eq(1)
      expect(result[:analysis_records_cleared]).to eq(1)

      edge = db[:edges].where(source: 'rubyist://matz', target: 'core_module://Array').first
      expect(edge[:archived_at]).not_to be_nil
      expect(db[:analysis_records].where(entity_type: 'issue', entity_id: 42).count).to eq(0)
    end
  end
end
