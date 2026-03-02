# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Ontology::ModuleRegistry do
  describe '.valid?' do
    it 'returns true for a core module' do
      expect(described_class.valid?('Array')).to be true
    end

    it 'returns true for a stdlib' do
      expect(described_class.valid?('net/http')).to be true
    end

    it 'returns true for another core module' do
      expect(described_class.valid?('String')).to be true
    end

    it 'returns true for another stdlib' do
      expect(described_class.valid?('json')).to be true
    end

    it 'returns false for an unknown name' do
      expect(described_class.valid?('nonexistent')).to be false
    end

    it 'returns false for a fabricated name' do
      expect(described_class.valid?('FakeModule')).to be false
    end
  end
end
