# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Migrator do
  subject(:migrator) { described_class.new(database: database, logger: logger) }

  let(:database) { Lapidary::Container['database'] }
  let(:logger) { Lapidary::Container['logger'] }

  describe '#check' do
    it 'completes without error when migrations are current' do
      expect { migrator.check }.not_to raise_error
    end

    context 'when migrations are pending' do
      before do
        database[:schema_migrations].delete
      end

      it 'completes without error' do
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
  end
end
