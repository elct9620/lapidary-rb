# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::PromptBuilder do
  subject(:prompt_builder) { described_class.new }

  describe '#call' do
    let(:result) { prompt_builder.call(job_arguments) }

    context 'with an issue job' do
      let(:job_arguments) do
        Analysis::Entities::JobArguments.new(
          entity_type: 'issue', entity_id: 12_345,
          title: 'Bug in String#encode', content: 'Detailed description of the encoding bug',
          author_username: 'matz', author_display_name: 'Yukihiro Matsumoto'
        )
      end

      it 'returns a Prompt value object' do
        expect(result).to be_a(Analysis::Extractors::Prompt)
      end

      it 'wraps issue in XML tag with id' do
        expect(result.user).to include('<issue id="12345">')
      end

      it 'includes title in XML tag' do
        expect(result.user).to include('<title>Bug in String#encode</title>')
      end

      it 'includes author in XML tag' do
        expect(result.user).to include('username="matz"')
          .and include('display_name="Yukihiro Matsumoto"')
      end

      it 'includes description content' do
        expect(result.user).to include('Detailed description of the encoding bug')
      end

      it 'does not include journal XML tag' do
        expect(result.user).not_to include('<journal')
      end

      it 'includes system instructions in the system prompt' do
        expect(result.system).to include('knowledge graph extraction assistant')
      end
    end

    context 'with a journal job' do
      let(:job_arguments) do
        Analysis::Entities::JobArguments.new(
          entity_type: 'journal', entity_id: 67_890,
          content: 'Patch submitted for review', author_username: 'nobu', author_display_name: 'Nobuyoshi Nakada',
          issue_id: 12_345, issue_title: 'Bug in String#encode',
          issue_content: 'Detailed description of the encoding bug',
          issue_author_username: 'matz',
          issue_author_display_name: 'Yukihiro Matsumoto'
        )
      end

      it 'includes journal XML tag with id and issue_id' do
        expect(result.user).to include('<journal id="67890" issue_id="12345">')
      end

      it 'includes journal content' do
        expect(result.user).to include('Patch submitted for review')
      end

      it 'includes parent issue XML with title and author' do
        expect(result.user).to include('<issue id="12345">')
          .and include('<title>Bug in String#encode</title>')
          .and include('username="matz"')
      end

      it 'includes parent issue description' do
        expect(result.user).to include('Detailed description of the encoding bug')
      end
    end

    context 'with ontology definitions' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes relationship types in the system prompt' do
        expect(result.system).to match(/Maintenance/)
          .and match(/Contribute/)
      end

      it 'includes node types in the system prompt' do
        expect(result.system).to match(/Rubyist/)
          .and match(/CoreModule/)
          .and match(/Stdlib/)
      end
    end

    context 'with module names from ModuleRegistry' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes core module names in the system prompt' do
        expect(result.system).to match(/String/)
      end

      it 'includes stdlib names in the system prompt' do
        expect(result.system).to match(/json/)
      end
    end

    context 'with evaluation steps' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes evaluation steps section in the system prompt' do
        expect(result.system).to include('Evaluation Steps')
      end

      it 'includes Y/N question format' do
        expect(result.system).to include('(Y/N)')
      end

      it 'includes reasoning field guidance' do
        expect(result.system).to include('reasoning')
      end
    end

    context 'with extraction rubric' do
      let(:job_arguments) { Analysis::Entities::JobArguments.new(entity_type: 'issue', entity_id: 1) }

      it 'includes the rubric table in the system prompt' do
        expect(result.system).to include('Extraction Rubric')
      end

      it 'includes Y/N decision table format' do
        expect(result.system).to match(/Y → Action/)
          .and match(/N → Action/)
      end

      it 'includes do-not-extract guidance' do
        expect(result.system).to include('Do NOT extract when')
      end

      it 'includes role guidance in extraction rules' do
        expect(result.system).to include('role')
      end
    end
  end

  describe '#correction_prompt' do
    let(:job_arguments) do
      Analysis::Entities::JobArguments.new(
        entity_type: 'issue', entity_id: 12_345,
        title: 'Bug in String#encode',
        content: 'Detailed description of the encoding bug',
        author_username: 'matz',
        author_display_name: 'Yukihiro Matsumoto'
      )
    end

    let(:triplet) do
      Analysis::Entities::Triplet.new(
        subject: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::RUBYIST, name: 'matz',
                                              properties: { role: 'maintainer' }),
        relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
        object: Analysis::Entities::Node.new(type: Analysis::Entities::NodeType::CORE_MODULE, name: 'InvalidModule'),
        evidence: 'matz committed to InvalidModule'
      )
    end

    let(:errors) { ['unknown module name: InvalidModule'] }
    let(:result) { prompt_builder.correction_prompt(triplet, errors, job_arguments) }

    it 'returns a Prompt value object' do
      expect(result).to be_a(Analysis::Extractors::Prompt)
    end

    it 'includes ontology definitions in the system prompt' do
      expect(result.system).to include('Ontology')
    end

    it 'includes module names in the system prompt' do
      expect(result.system).to include('Valid Module Names')
    end

    it 'includes correction instructions in the system prompt' do
      expect(result.system).to include('correct')
    end

    it 'includes extraction rules in the system prompt' do
      expect(result.system).to include('Extraction Rules')
    end

    it 'includes evaluation steps in the system prompt' do
      expect(result.system).to include('Evaluation Steps')
    end

    it 'includes extraction rubric in the system prompt' do
      expect(result.system).to include('Extraction Rubric')
    end

    it 'includes the failed triplet in XML format' do
      expect(result.user).to include('<failed-triplet>')
        .and include('name="matz"')
        .and include('name="InvalidModule"')
    end

    it 'includes validation errors in the user prompt' do
      expect(result.user).to include('unknown module name: InvalidModule')
    end

    it 'includes original context in XML wrapper' do
      expect(result.user).to include('<original-context>')
        .and include('<issue id="12345">')
    end
  end
end
