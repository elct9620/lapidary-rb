# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Ontology::Validator do
  subject(:validator) { described_class.new }

  let(:rubyist) do
    Analysis::Entities::Node.new(
      type: Analysis::Entities::NodeType::RUBYIST,
      name: 'matz',
      properties: { role: 'maintainer' }
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

    context 'when subject name contains parenthetical annotation' do
      it 'returns a subject name error' do
        annotated_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'st0012 (Stan Lo)'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: annotated_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject name contains parenthetical annotation: st0012 (Stan Lo)')
      end
    end

    context 'when subject name is Anonymous' do
      it 'returns an anonymous identifier error' do
        anonymous_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'Anonymous'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: anonymous_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject name is a reserved anonymous identifier: Anonymous')
      end
    end

    context 'when subject name matches a known non-human agent' do
      it 'returns a non-human agent error' do
        ai_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'Claude Opus 4.6'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: ai_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject name matches a known non-human agent: Claude Opus 4.6')
      end

      it 'rejects GPT model names' do
        ai_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'GPT-4o'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: ai_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject name matches a known non-human agent: GPT-4o')
      end
    end

    context 'when subject name contains whitespace' do
      it 'returns a whitespace error' do
        spaced_subject = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'Some Name'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: spaced_subject,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('subject name contains whitespace: Some Name')
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

    context 'when Maintenance subject has role=maintainer' do
      it 'passes validation without modification' do
        triplet = Analysis::Entities::Triplet.new(
          subject: rubyist,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to be_empty
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      end
    end

    context 'when Maintenance subject has role=submaintainer' do
      it 'returns a role constraint error' do
        submaintainer = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'helper',
          properties: { role: 'submaintainer' }
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: submaintainer,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('Maintenance relationship requires role=maintainer, got role=submaintainer')
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      end
    end

    context 'when Maintenance subject has role=contributor' do
      it 'returns a role constraint error' do
        contributor = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'contributor',
          properties: { role: 'contributor' }
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: contributor,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include('Maintenance relationship requires role=maintainer, got role=contributor')
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      end
    end

    context 'when Maintenance subject has no role (defaults)' do
      it 'returns a role constraint error' do
        no_role = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'someone'
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: no_role,
          relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to include(a_string_matching(/Maintenance relationship requires role=maintainer/))
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
      end
    end

    context 'when Contribute with any role' do
      it 'passes validation without modification' do
        submaintainer = Analysis::Entities::Node.new(
          type: Analysis::Entities::NodeType::RUBYIST,
          name: 'helper',
          properties: { role: 'submaintainer' }
        )
        triplet = Analysis::Entities::Triplet.new(
          subject: submaintainer,
          relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
          object: core_module
        )

        result = validator.call(triplet)

        expect(result.errors).to be_empty
        expect(result.triplet.relationship).to eq(Analysis::Entities::RelationshipType::CONTRIBUTE)
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
