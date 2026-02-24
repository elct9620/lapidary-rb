# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::RepositorySupport do
  let(:error_class) { Class.new(StandardError) }

  let(:repository_class) do
    err = error_class
    Class.new do
      include Lapidary::RepositorySupport

      table :test_table
      wraps_errors err

      attr_reader :database

      def initialize(database)
        @database = database
      end

      def query(&)
        with_error_wrapping(&)
      end

      def table_name
        dataset.opts[:from].first
      end
    end
  end

  let(:database) { Lapidary::Container['database'] }
  let(:repository) { repository_class.new(database) }

  describe '.table' do
    it 'defines a dataset method returning the named table' do
      expect(repository.table_name).to eq(:test_table)
    end
  end

  describe '.wraps_errors' do
    it 'yields the block on success' do
      expect(repository.query { 42 }).to eq(42)
    end

    it 'wraps Sequel::Error with the configured error class' do
      expect do
        repository.query { raise Sequel::Error, 'db failure' }
      end.to raise_error(error_class, 'db failure')
    end

    it 'does not wrap non-Sequel errors' do
      expect do
        repository.query { raise 'other' }
      end.to raise_error(RuntimeError, 'other')
    end
  end
end
