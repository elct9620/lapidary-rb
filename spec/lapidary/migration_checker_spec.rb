# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::MigrationChecker do
  subject(:checker) { described_class.new(database: database, logger: logger) }

  let(:database) { Lapidary::Container['database'] }
  let(:logger) { instance_double(Console::Logger, warn: nil) }

  it 'does not warn when migrations are current' do
    checker.call

    expect(logger).not_to have_received(:warn)
  end

  context 'when migrations are pending' do
    before do
      database[:schema_migrations].delete
    end

    it 'logs a warning' do
      checker.call

      expect(logger).to have_received(:warn).with(
        checker,
        'Database migrations are pending. Run: bundle exec rake db:migrate'
      )
    end
  end
end
