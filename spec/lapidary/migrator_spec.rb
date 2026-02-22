# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Migrator do
  subject(:migrator) { described_class.new(database: database, logger: logger) }

  let(:database) { Lapidary::Container['database'] }
  let(:logger) { instance_double(Console::Logger, warn: nil) }

  describe '#check' do
    it 'does not warn when migrations are current' do
      migrator.check

      expect(logger).not_to have_received(:warn)
    end

    context 'when migrations are pending' do
      before do
        database[:schema_migrations].delete
      end

      it 'logs a warning' do
        migrator.check

        expect(logger).to have_received(:warn).with(
          migrator,
          'Database migrations are pending. Run: bundle exec rake db:migrate'
        )
      end
    end
  end

  describe '#migrate' do
    it 'runs without error when migrations are current' do
      expect { migrator.migrate }.not_to raise_error
    end

    it 'accepts a target version' do
      expect { migrator.migrate(target: 0) }.not_to raise_error
    end
  end
end
