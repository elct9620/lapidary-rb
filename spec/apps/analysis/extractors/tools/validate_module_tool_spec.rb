# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Extractors::Tools::ValidateModuleTool do
  subject(:tool) { described_class.new }

  describe '#execute' do
    context 'with a valid core module name' do
      it 'returns valid: true' do
        result = JSON.parse(tool.execute(name: 'String'))

        expect(result).to eq({ 'valid' => true, 'name' => 'String' })
      end
    end

    context 'with a valid stdlib name' do
      it 'returns valid: true' do
        result = JSON.parse(tool.execute(name: 'json'))

        expect(result).to eq({ 'valid' => true, 'name' => 'json' })
      end
    end

    context 'with an invalid module name' do
      it 'returns valid: false with suggestions' do
        result = JSON.parse(tool.execute(name: 'Strin'))

        expect(result['valid']).to be false
        expect(result['name']).to eq('Strin')
        expect(result['suggestions']).to include('String')
      end
    end

    context 'with a completely unrelated name' do
      it 'returns valid: false with empty suggestions' do
        result = JSON.parse(tool.execute(name: 'Zzqxwv'))

        expect(result['valid']).to be false
        expect(result['suggestions']).to be_empty
      end
    end
  end

  describe '#name' do
    it 'returns the tool name' do
      expect(tool.name).to include('validate_module')
    end
  end

  describe '#description' do
    it 'returns the tool description' do
      expect(tool.description).to include('Validate whether a module name exists')
    end
  end
end
