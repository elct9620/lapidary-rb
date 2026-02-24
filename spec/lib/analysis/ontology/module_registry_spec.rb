# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Ontology::ModuleRegistry do
  describe '.core_module?' do
    it 'returns true for a valid core module' do
      expect(described_class.core_module?('String')).to be true
    end

    it 'returns false for a stdlib name' do
      expect(described_class.core_module?('json')).to be false
    end

    it 'returns false for an unknown name' do
      expect(described_class.core_module?('FakeModule')).to be false
    end
  end

  describe '.stdlib?' do
    it 'returns true for a valid stdlib' do
      expect(described_class.stdlib?('json')).to be true
    end

    it 'returns false for a core module name' do
      expect(described_class.stdlib?('String')).to be false
    end

    it 'returns false for an unknown name' do
      expect(described_class.stdlib?('fake_lib')).to be false
    end
  end

  describe '.valid?' do
    it 'returns true for a core module' do
      expect(described_class.valid?('Array')).to be true
    end

    it 'returns true for a stdlib' do
      expect(described_class.valid?('net/http')).to be true
    end

    it 'returns false for an unknown name' do
      expect(described_class.valid?('nonexistent')).to be false
    end
  end
end
