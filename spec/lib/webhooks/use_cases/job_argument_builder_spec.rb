# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::UseCases::JobArgumentBuilder do
  let(:author) { Webhooks::Entities::Author.new(username: 'matz', display_name: 'Yukihiro Matsumoto') }
  let(:journals) do
    [
      Webhooks::Entities::Journal.new(
        id: 101, notes: 'First comment',
        author: Webhooks::Entities::Author.new(username: 'nobu', display_name: 'Nobuyoshi Nakada'),
        created_on: '2024-01-16T08:00:00Z'
      )
    ]
  end
  let(:issue) do
    Webhooks::Entities::Issue.new(
      id: 42, subject: 'Add new feature',
      author: author,
      created_on: '2024-01-15T10:30:00Z',
      journals: journals
    )
  end

  subject(:builder) { described_class.new(issue) }

  describe '#call' do
    context 'with an issue record' do
      let(:record) do
        Webhooks::Entities::AnalysisRecord.new(
          entity_type: Webhooks::Entities::EntityType::ISSUE,
          entity_id: 42
        )
      end

      it 'returns issue arguments' do
        result = builder.call(record)

        expect(result).to eq(
          entity_type: 'issue',
          entity_id: 42,
          content: 'Add new feature',
          created_on: '2024-01-15T10:30:00Z',
          author_username: 'matz',
          author_display_name: 'Yukihiro Matsumoto'
        )
      end
    end

    context 'with a journal record' do
      let(:record) do
        Webhooks::Entities::AnalysisRecord.new(
          entity_type: Webhooks::Entities::EntityType::JOURNAL,
          entity_id: 101
        )
      end

      it 'returns journal arguments with issue context' do
        result = builder.call(record)

        expect(result).to eq(
          entity_type: 'journal',
          entity_id: 101,
          content: 'First comment',
          issue_id: 42,
          issue_content: 'Add new feature',
          created_on: '2024-01-16T08:00:00Z',
          author_username: 'nobu',
          author_display_name: 'Nobuyoshi Nakada'
        )
      end
    end

    context 'with a nil author' do
      let(:author) { nil }

      let(:record) do
        Webhooks::Entities::AnalysisRecord.new(
          entity_type: Webhooks::Entities::EntityType::ISSUE,
          entity_id: 42
        )
      end

      it 'returns nil author fields' do
        result = builder.call(record)

        expect(result).to include(author_username: nil, author_display_name: nil)
      end
    end

    context 'with an unknown entity type' do
      let(:record) do
        Webhooks::Entities::AnalysisRecord.new(
          entity_type: Webhooks::Entities::EntityType.new(value: 'unknown'),
          entity_id: 99
        )
      end

      it 'raises ArgumentError' do
        expect { builder.call(record) }.to raise_error(ArgumentError, /unknown entity type/)
      end
    end

    context 'when journal is not found in issue' do
      let(:record) do
        Webhooks::Entities::AnalysisRecord.new(
          entity_type: Webhooks::Entities::EntityType::JOURNAL,
          entity_id: 999
        )
      end

      it 'raises ArgumentError' do
        expect { builder.call(record) }.to raise_error(ArgumentError, /journal 999 not found/)
      end
    end
  end
end
