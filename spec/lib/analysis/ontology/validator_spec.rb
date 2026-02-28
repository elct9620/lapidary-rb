# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Ontology::Validator do
  subject(:validator) { described_class.new }

  let(:rubyist) do
    Analysis::Entities::Node.new(
      type: Analysis::Entities::NodeType::RUBYIST,
      name: 'matz',
      properties: { is_committer: true }
    )
  end

  let(:core_module) do
    Analysis::Entities::Node.new(
      type: Analysis::Entities::NodeType::CORE_MODULE,
      name: 'String'
    )
  end

  let(:stdlib) do
    Analysis::Entities::Node.new(
      type: Analysis::Entities::NodeType::STDLIB,
      name: 'json'
    )
  end

  describe '#call' do
    context 'with a valid Maintenance triplet' do
      it 'returns no errors' do
        triplet = Analysis::Entities::Triplet.new(
          subject: rubyist,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to be_empty
      end
    end

    context 'with a valid Contribute triplet' do
      it 'returns no errors' do
        non_committer = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'contributor'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: non_committer,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: stdlib
        )

        result = validator.call(triplet)

        expect(result.errors).to be_empty
      end
    end

    context 'when subject type is invalid' do
      it 'returns a subject type error' do
        invalid_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::CORE_MODULE,
          name: 'String'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: invalid_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject type must be Rubyist, got CoreModule')
      end
    end

    context 'when object type is invalid' do
      it 'returns an object type error' do
        invalid_object = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'someone'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: rubyist,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: invalid_object
        )

        result = validator.call(triplet)

        expect(result.errors).to include('object type must be CoreModule or Stdlib, got Rubyist')
      end
    end

    context 'when relationship is invalid' do
      it 'returns a relationship error' do
        invalid_relationship = Analysis::Entities::RelationshipType.new(value: 'Unknown')
        triplet = Analysis::Entities::Triplet.new(
          subject: rubyist,
          relationship: invalid_relationship,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('relationship must be Maintenance or Contribute, got Unknown')
      end
    end

    context 'when Maintenance subject is not a committer' do
      it 'passes validation without modification' do
        non_committer = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'contributor'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: non_committer,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to be_empty
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      end
    end

    context 'when module name is unknown' do
      it 'returns a module name error' do
        unknown_module = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::CORE_MODULE,
          name: 'FakeModule'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: rubyist,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: unknown_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('unknown module name: FakeModule')
      end
    end

    context 'with multiple validation failures' do
      it 'returns all errors' do
        invalid_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::STDLIB,
          name: 'json'
        )
        invalid_object = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'someone'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: invalid_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: invalid_object
        )

        result = validator.call(triplet)

        expect(result.errors.size).to be >= 2
        expect(result.errors).to include('subject type must be Rubyist, got Stdlib')
        expect(result.errors).to include('object type must be CoreModule or Stdlib, got Rubyist')
      end
    end
  end
end
