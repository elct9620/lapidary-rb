# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::PromptBuilder do
  subject(:prompt_builder) { described_class.new }

  describe '#call' do
    let(:prompt) { prompt_builder.call(job_arguments) }

    context 'with an issue job' do
      let(:job_arguments) { { entity_type: 'issue', entity_id: 12_345 } }

      it 'includes issue content in the prompt' do
        expect(prompt).to match(/Issue #12345/)
      end
    end

    context 'with a journal job' do
      let(:job_arguments) { { entity_type: 'journal', entity_id: 67_890 } }

      it 'includes journal content in the prompt' do
        expect(prompt).to match(/Journal #67890/)
      end
    end

    context 'with ontology definitions' do
      let(:job_arguments) { { entity_type: 'issue', entity_id: 1 } }

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
      let(:job_arguments) { { entity_type: 'issue', entity_id: 1 } }

      it 'includes core module names' do
        expect(prompt).to match(/String/)
      end

      it 'includes stdlib names' do
        expect(prompt).to match(/json/)
      end
    end
  end
end
