# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Database provider' do
  let(:database) { Lapidary::Container['database'] }

  it 'registers a Sequel::Database' do
    expect(database).to be_a(Sequel::Database)
  end

  it 'configures single-threaded mode' do
    expect(database.pool).to be_a(Sequel::SingleConnectionPool)
  end

  it 'configures busy timeout' do
    expect(database.opts[:connect_sqls]).to include('PRAGMA busy_timeout=5000')
  end

  it 'configures WAL journal mode' do
    expect(database.opts[:connect_sqls]).to include('PRAGMA journal_mode=WAL')
  end

  it 'uses data/ directory for non-test database path' do
    provider_source = File.read(
      File.join(Lapidary::Container.config.root, 'system/providers/database.rb')
    )

    expect(provider_source).to include('sqlite://data/')
    expect(provider_source).not_to match(%r{sqlite://db/})
  end
end
