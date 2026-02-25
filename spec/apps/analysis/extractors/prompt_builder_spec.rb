# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::PromptBuilder do
  subject(:prompt_builder) { described_class.new }

  describe '#call' do
    let(:prompt) { prompt_builder.call(job_arguments) }

    context 'with an issue job' do
      let(:job_arguments) do
        Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 12_345,
          content: 'Bug in String#encode', author_username: 'matz', author_display_name: 'Yukihiro Matsumoto'
        )
      end

      it 'includes issue content in the prompt' do
        expect(prompt).to match(/Issue #12345/)
      end

      it 'includes author information' do
        expect(prompt).to match(/Author: matz \(Yukihiro Matsumoto\)/)
      end

      it 'includes the content text' do
        expect(prompt).to include('Bug in String#encode')
      end

      it 'does not include journal context' do
        expect(prompt).not_to match(/Issue #\d+:/)
      end
    end

    context 'with a journal job' do
      let(:job_arguments) do
        Analysis::Entities::JobArguments.new(
          entity_type: 'journal', entity_id: 67_890,
          content: 'Patch submitted for review', author_username: 'nobu', author_display_name: 'Nobuyoshi Nakada',
          issue_id: 12_345, issue_content: 'Bug in String#encode'
        )
      end

      it 'includes journal content in the prompt' do
        expect(prompt).to match(/Journal #67890/)
      end

      it 'includes the content text' do
        expect(prompt).to include('Patch submitted for review')
      end

      it 'includes journal context with issue reference' do
        expect(prompt).to match(/Issue #12345: Bug in String#encode/)
      end
    end

    context 'with ontology definitions' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes relationship types' do
        expect(prompt).to match(/Maintenance/)
          .and match(/Contribute/)
      end

      it 'includes node types' do
        expect(prompt).to match(/Rubyist/)
          .and match(/CoreModule/)
          .and match(/Stdlib/)
      end
    end

    context 'with module names from ModuleRegistry' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes core module names' do
        expect(prompt).to match(/String/)
      end

      it 'includes stdlib names' do
        expect(prompt).to match(/json/)
      end
    end
  end
end
