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
    it 'does not raise when migrations are current' do
      expect { migrator.check }.not_to raise_error
    end

    context 'when migrations are pending' do
      before do
        database[:schema_migrations].delete
      end

      it 'does not raise' do
        expect { migrator.check }.not_to raise_error
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

    context 'when migrations are pending' do
      before do
        database.drop_table(:observations, :edges, :nodes, :jobs, :analysis_records)
        database[:schema_migrations].delete
      end

      it 'applies all pending migrations' do
        migrator.migrate

        expect(migrator.pending?).to be false
      end
    end
  end
end
