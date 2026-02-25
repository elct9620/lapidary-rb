# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Graph::Contract do
  subject(:contract) { described_class.new }

  describe '#call' do
    context 'with valid node_id only' do
      it 'succeeds' do
        result = contract.call(node_id: 'rubyist://matz')
        expect(result).to be_success
      end
    end

    context 'with all valid parameters' do
      it 'succeeds' do
        result = contract.call(
          node_id: 'core_module://String',
          direction: 'outbound',
          observed_after: '2024-01-01T00:00:00Z',
          observed_before: '2024-12-31T23:59:59Z'
        )
        expect(result).to be_success
      end
    end

    context 'with missing node_id' do
      it 'fails' do
        result = contract.call({})
        expect(result).to be_failure
        expect(result.errors[:node_id]).to include('is missing')
      end
    end

    context 'with empty node_id' do
      it 'fails' do
        result = contract.call(node_id: '')
        expect(result).to be_failure
        expect(result.errors[:node_id]).to include('must be filled')
      end
    end

    context 'with invalid node_id format' do
      it 'fails for missing protocol separator' do
        result = contract.call(node_id: 'rubyist_matz')
        expect(result).to be_failure
        expect(result.errors[:node_id]).to include('must match type://name format')
      end

      it 'fails for uppercase type' do
        result = contract.call(node_id: 'Rubyist://matz')
        expect(result).to be_failure
        expect(result.errors[:node_id]).to include('must match type://name format')
      end
    end

    context 'with invalid direction' do
      it 'fails' do
        result = contract.call(node_id: 'rubyist://matz', direction: 'up')
        expect(result).to be_failure
        expect(result.errors[:direction]).to include('must be outbound, inbound, or both')
      end
    end

    context 'with valid direction values' do
      %w[outbound inbound both].each do |dir|
        it "accepts '#{dir}'" do
          result = contract.call(node_id: 'rubyist://matz', direction: dir)
          expect(result).to be_success
        end
      end
    end

    context 'with invalid observed_after' do
      it 'fails' do
        result = contract.call(node_id: 'rubyist://matz', observed_after: 'not-a-date')
        expect(result).to be_failure
        expect(result.errors[:observed_after]).to include('must be a valid ISO 8601 datetime')
      end
    end

    context 'with invalid observed_before' do
      it 'fails' do
        result = contract.call(node_id: 'rubyist://matz', observed_before: 'not-a-date')
        expect(result).to be_failure
        expect(result.errors[:observed_before]).to include('must be a valid ISO 8601 datetime')
      end
    end
  end
end
