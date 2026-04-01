# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhooks::Entities::Author do
  describe '#display_name' do
    it 'can be nil' do
      author = described_class.new(username: 'matz', display_name: nil)
      expect(author.display_name).to be_nil
    end
  end

  describe 'value equality' do
    it 'is equal to another Author with the same attributes' do
      author1 = described_class.new(username: 'matz', display_name: 'Yukihiro Matsumoto')
      author2 = described_class.new(username: 'matz', display_name: 'Yukihiro Matsumoto')
      expect(author1).to eq(author2)
    end

    it 'is not equal to another Author with different attributes' do
      author1 = described_class.new(username: 'matz', display_name: 'Yukihiro Matsumoto')
      author2 = described_class.new(username: 'nobu', display_name: 'Nobuyoshi Nakada')
      expect(author1).not_to eq(author2)
    end
  end
end
