# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::NodeQueryContract do
  subject(:contract) { described_class.new }

  describe 'type validation' do
    %w[Rubyist CoreModule Stdlib].each do |valid_type|
      it "accepts #{valid_type}" do
        result = contract.call(type: valid_type)
        expect(result).to be_success
      end
    end

    it 'rejects invalid type' do
      result = contract.call(type: 'Invalid')
      expect(result.errors[:type]).to include('must be Rubyist, CoreModule, or Stdlib')
    end
  end

  describe 'q validation' do
    it 'accepts a non-empty string' do
      result = contract.call(q: 'matz')
      expect(result).to be_success
    end

    it 'rejects empty string' do
      result = contract.call(q: '')
      expect(result.errors[:q]).not_to be_empty
    end
  end

  describe 'limit validation' do
    it 'accepts valid limit' do
      result = contract.call(limit: 50)
      expect(result).to be_success
    end

    it 'rejects limit below 1' do
      result = contract.call(limit: 0)
      expect(result.errors[:limit]).to include('must be between 1 and 100')
    end

    it 'rejects limit above 100' do
      result = contract.call(limit: 101)
      expect(result.errors[:limit]).to include('must be between 1 and 100')
    end
  end

  describe 'offset validation' do
    it 'accepts zero' do
      result = contract.call(offset: 0)
      expect(result).to be_success
    end

    it 'accepts positive offset' do
      result = contract.call(offset: 10)
      expect(result).to be_success
    end

    it 'rejects negative offset' do
      result = contract.call(offset: -1)
      expect(result.errors[:offset]).to include('must be non-negative')
    end
  end

  describe 'with no parameters' do
    it 'succeeds' do
      result = contract.call({})
      expect(result).to be_success
    end
  end
end
