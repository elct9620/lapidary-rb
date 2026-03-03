# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::ResponseParser do
  subject(:parser) { described_class.new(logger: logger) }

  let(:logger) { instance_double(Console::Logger, warn: nil) }

  describe '#call' do
    context 'with a valid response' do
      let(:content) do
        {
          'triplets' => [
            {
              'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'CoreModule', 'name' => 'String' },
              'evidence' => 'matz maintains the String class'
            },
            {
              'subject' => { 'name' => 'contributor', 'role' => 'contributor' },
              'relationship' => 'Contribute',
              'object' => { 'type' => 'Stdlib', 'name' => 'json' },
              'evidence' => 'contributor worked on json stdlib'
            }
          ]
        }
      end

      it 'returns an array of Triplet entities' do
        triplets = parser.call(content)

        expect(triplets).to all(be_a(Analysis::Entities::Triplet))
        expect(triplets.size).to eq(2)
      end

      it 'maps subject correctly' do
        triplets = parser.call(content)

        expect(triplets.first.subject.type).to eq(Analysis::Entities::NodeType::RUBYIST)
        expect(triplets.first.subject.name).to eq('matz')
        expect(triplets.first.subject.properties).to eq({ role: 'maintainer' })
      end

      it 'maps relationship correctly' do
        triplets = parser.call(content)

        expect(triplets.first.relationship).to eq(Analysis::Entities::RelationshipType::MAINTENANCE)
        expect(triplets.last.relationship).to eq(Analysis::Entities::RelationshipType::CONTRIBUTE)
      end

      it 'maps object correctly' do
        triplets = parser.call(content)

        expect(triplets.first.object.type).to eq(Analysis::Entities::NodeType::CORE_MODULE)
        expect(triplets.first.object.name).to eq('String')
        expect(triplets.last.object.type).to eq(Analysis::Entities::NodeType::STDLIB)
        expect(triplets.last.object.name).to eq('json')
      end

      it 'carries evidence through to the triplet' do
        triplets = parser.call(content)

        expect(triplets.first.evidence).to eq('matz maintains the String class')
        expect(triplets.last.evidence).to eq('contributor worked on json stdlib')
      end

      it 'returns triplets that pass ontology validation' do
        validator = Analysis::Ontology::Validator.new
        triplets = parser.call(content)

        results = triplets.map { |triplet| validator.call(triplet) }

        expect(results).to all(satisfy { |r| r.errors.empty? })
      end
    end

    context 'with empty triplets' do
      it 'returns an empty array' do
        expect(parser.call({ 'triplets' => [] })).to eq([])
      end
    end

    context 'with non-Hash content' do
      it 'returns an empty array' do
        expect(parser.call('unexpected string')).to eq([])
      end

      it 'logs a malformed response warning' do
        parser.call('unexpected string')

        expect(logger).to have_received(:warn).with(parser, a_kind_of(String), anything)
      end
    end

    context 'with nil content' do
      it 'returns an empty array' do
        expect(parser.call(nil)).to eq([])
      end

      it 'does not log a warning' do
        parser.call(nil)

        expect(logger).not_to have_received(:warn)
      end
    end

    context 'with nil name fields in triplets' do
      let(:content) do
        {
          'triplets' => [
            {
              'subject' => { 'name' => nil, 'role' => 'maintainer' },
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'CoreModule', 'name' => 'String' }
            },
            {
              'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'CoreModule', 'name' => nil }
            },
            {
              'subject' => { 'name' => 'nobu', 'role' => 'maintainer' },
              'relationship' => 'Contribute',
              'object' => { 'type' => 'CoreModule', 'name' => 'Array' }
            }
          ]
        }
      end

      it 'skips triplets with nil names and returns only valid ones' do
        triplets = parser.call(content)

        expect(triplets.size).to eq(1)
        expect(triplets.first.subject.name).to eq('nobu')
        expect(triplets.first.object.name).to eq('Array')
      end

      it 'logs a warning for each malformed triplet' do
        parser.call(content)

        expect(logger).to have_received(:warn).with(parser, a_string_matching(/Skipping malformed triplet/)).twice
      end
    end

    context 'with incomplete triplet data' do
      let(:content) do
        {
          'triplets' => [
            {
              'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'CoreModule', 'name' => 'String' }
            },
            {
              'subject' => { 'name' => 'someone' },
              'relationship' => 'Contribute'
              # missing 'object'
            },
            {
              'subject' => nil,
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'CoreModule', 'name' => 'Array' }
            }
          ]
        }
      end

      it 'skips incomplete triplets and returns only valid ones' do
        triplets = parser.call(content)

        expect(triplets.size).to eq(1)
        expect(triplets.first.subject.name).to eq('matz')
      end

      it 'logs a warning for each incomplete triplet' do
        parser.call(content)

        expect(logger).to have_received(:warn).with(parser, a_string_matching(/Skipping malformed triplet/)).twice
      end
    end

    context 'with an invalid relationship value' do
      let(:content) do
        {
          'triplets' => [
            {
              'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
              'relationship' => 'Unknown',
              'object' => { 'type' => 'CoreModule', 'name' => 'String' }
            }
          ]
        }
      end

      it 'raises ExtractionError with a descriptive message' do
        expect { parser.call(content) }
          .to raise_error(Analysis::Entities::ExtractionError, 'unknown relationship: Unknown')
      end
    end

    context 'with an invalid object type' do
      let(:content) do
        {
          'triplets' => [
            {
              'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
              'relationship' => 'Maintenance',
              'object' => { 'type' => 'InvalidType', 'name' => 'String' }
            }
          ]
        }
      end

      it 'raises ExtractionError with a descriptive message' do
        expect { parser.call(content) }
          .to raise_error(Analysis::Entities::ExtractionError, 'unknown node type: InvalidType')
      end
    end
  end
end
