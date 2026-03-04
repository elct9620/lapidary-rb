# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Migrator do
  subject(:migrator) { described_class.new(database: database, logger: logger) }

  let(:database) { Lapidary::Container['database'] }
  let(:logger) { Lapidary::Container['logger'] }

  describe '#pending?' do
    it 'returns false when migrations are current' do
      expect(migrator.pending?).to be false
    end

    context 'when migrations are pending' do
      before do
        database[:schema_migrations].delete
      end

      it 'returns true' do
        expect(migrator.pending?).to be true
      end
    end

    context 'when Sequel raises during migration check' do
      before do
        allow(Sequel::Migrator).to receive(:is_current?).and_raise(Sequel::Error, 'connection lost')
      end

      it 'returns false' do
        expect(migrator.pending?).to be false
      end
    end
  end

  describe '#check' do
    it 'does not warn when migrations are current' do
      allow(logger).to receive(:warn)

      migrator.check

      expect(logger).not_to have_received(:warn)
    end

    context 'when migrations are pending' do
      before do
        database[:schema_migrations].delete
      end

      it 'logs a warning' do
        allow(logger).to receive(:warn)

        migrator.check

        expect(logger).to have_received(:warn).with(migrator,
                                                    'Database migrations are pending. Run: bundle exec rake db:migrate')
      end
    end
  end

  describe '#migrate' do
    before do
      allow(logger).to receive(:info)
    end

    it 'runs without error when migrations are current' do
      expect { migrator.migrate }.not_to raise_error
    end

    it 'accepts a target version' do
      expect { migrator.migrate(target: 0) }.not_to raise_error
    end

    it 'logs that database is already up to date when no pending migrations' do
      migrator.migrate

      expect(logger).to have_received(:info).with(migrator, 'Database is already up to date')
    end

    context 'when migrations are pending' do
      before do
        database.drop_table(:observations, :edges, :nodes, :jobs, :analysis_records)
        database[:schema_migrations].delete
      end

      it 'logs each pending migration filename' do
        migrator.migrate

        migration_files = Dir.glob(File.join(Lapidary::Container.root, 'db', 'migrations', '*.rb')).map do |f|
          File.basename(f)
        end

        migration_files.each do |filename|
          expect(logger).to have_received(:info).with(migrator, "Applying #{filename}...")
        end
      end

      it 'logs completion message with migration count' do
        migration_count = Dir.glob(File.join(Lapidary::Container.root, 'db', 'migrations', '*.rb')).size

        migrator.migrate

        expect(logger).to have_received(:info).with(migrator, "Applied #{migration_count} migration(s)")
      end
    end
  end
end
