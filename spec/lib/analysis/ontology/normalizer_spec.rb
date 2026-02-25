# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Ontology::Normalizer do
  subject(:normalizer) { described_class.new }

  let(:core_module) do
    Analysis::Entities::Node.new(
      type: Analysis::Entities::NodeType::CORE_MODULE,
      name: 'String'
    )
  end

  def build_triplet(subject_name:)
    Analysis::Entities::Triplet.new(
      subject: Analysis::Entities::Node.new(
        type: Analysis::Entities::NodeType::RUBYIST,
        name: subject_name
      ),
      relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
      object: core_module
    )
  end

  def build_arguments(author_username: nil, author_display_name: nil)
    Analysis::Entities::JobArguments.new(
      entity_type: 'issue', entity_id: 1,
      author_username: author_username, author_display_name: author_display_name
    )
  end

  describe '#call' do
    context 'when subject name matches author_username' do
      it 'resolves to author_username' do
        triplet = build_triplet(subject_name: 'matz')
        arguments = build_arguments(author_username: 'matz')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.name).to eq('matz')
      end

      it 'sets display_name property when author has display_name' do
        triplet = build_triplet(subject_name: 'matz')
        arguments = build_arguments(author_username: 'matz', author_display_name: 'Yukihiro Matsumoto')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.properties[:display_name]).to eq('Yukihiro Matsumoto')
      end
    end

    context 'when subject name matches author_display_name' do
      it 'resolves to author_username' do
        triplet = build_triplet(subject_name: 'Yukihiro Matsumoto')
        arguments = build_arguments(author_username: 'matz', author_display_name: 'Yukihiro Matsumoto')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.name).to eq('matz')
      end

      it 'sets display_name property' do
        triplet = build_triplet(subject_name: 'Yukihiro Matsumoto')
        arguments = build_arguments(author_username: 'matz', author_display_name: 'Yukihiro Matsumoto')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.properties[:display_name]).to eq('Yukihiro Matsumoto')
      end
    end

    context 'when subject name does not match any author field' do
      it 'passes through unchanged' do
        triplet = build_triplet(subject_name: 'nobu')
        arguments = build_arguments(author_username: 'matz', author_display_name: 'Yukihiro Matsumoto')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.name).to eq('nobu')
      end
    end

    context 'with case-insensitive comparison' do
      it 'matches regardless of case' do
        triplet = build_triplet(subject_name: 'MATZ')
        arguments = build_arguments(author_username: 'matz')

        result = normalizer.call(triplet, arguments)

        expect(result.subject.name).to eq('matz')
      end
    end

    context 'when author fields are nil' do
      it 'passes through unchanged' do
        triplet = build_triplet(subject_name: 'matz')
        arguments = build_arguments

        result = normalizer.call(triplet, arguments)

        expect(result.subject.name).to eq('matz')
      end
    end

    context 'when arguments is nil' do
      it 'passes through unchanged' do
        triplet = build_triplet(subject_name: 'matz')

        result = normalizer.call(triplet, nil)

        expect(result.subject.name).to eq('matz')
      end
    end

    it 'does not modify the object node' do
      triplet = build_triplet(subject_name: 'matz')
      arguments = build_arguments(author_username: 'matz')

      result = normalizer.call(triplet, arguments)

      expect(result.object).to eq(core_module)
    end
  end
end
