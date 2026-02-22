# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Database provider' do
  before(:all) { Lapidary::Container.finalize! }

  let(:database) { Lapidary::Container['database'] }

  it 'registers a Sequel::Database' do
    expect(database).to be_a(Sequel::Database)
  end

  it 'configures WAL journal mode' do
    expect(database.opts[:connect_sqls]).to include('PRAGMA journal_mode=WAL')
  end
end
