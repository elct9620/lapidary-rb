# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Entities::Triplet do
  describe 'construction' do
    it 'creates a triplet with subject, relationship, and object' do
      subject_node = Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::RUBYIST,
        name: 'matz',
        properties: { role: 'maintainer' }
      )
      object_node = Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::CORE_MODULE,
        name: 'String'
      )
      relationship = Analysis::Entities::RelationshipType::MAINTENANCE

      triplet = described_class.new(
        subject: subject_node,
        relationship: relationship,
        object: object_node
      )

      expect(triplet.subject).to eq(subject_node)
      expect(triplet.relationship).to eq(relationship)
      expect(triplet.object).to eq(object_node)
    end
  end
end
