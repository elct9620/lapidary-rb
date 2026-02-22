# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Contract do
  subject(:contract) { described_class.new }

  describe '#call' do
    context 'with valid input' do
      it 'succeeds' do
        result = contract.call(issue_id: 1)
        expect(result).to be_success
      end
    end

    context 'with missing issue_id' do
      it 'fails' do
        result = contract.call({})
        expect(result).to be_failure
        expect(result.errors[:issue_id]).to include('is missing')
      end
    end

    context 'with issue_id as string' do
      it 'fails' do
        result = contract.call(issue_id: 'abc')
        expect(result).to be_failure
        expect(result.errors[:issue_id]).to include('must be an integer')
      end
    end

    context 'with issue_id as zero' do
      it 'fails' do
        result = contract.call(issue_id: 0)
        expect(result).to be_failure
        expect(result.errors[:issue_id]).to include('must be positive')
      end
    end

    context 'with negative issue_id' do
      it 'fails' do
        result = contract.call(issue_id: -1)
        expect(result).to be_failure
        expect(result.errors[:issue_id]).to include('must be positive')
      end
    end
  end
end
