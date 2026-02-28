# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/lapidary/analysis/environment'

RSpec.describe Lapidary::Analysis::Environment do
  let(:test_class) do
    mod = described_class
    Class.new do
      include mod

      def name
        'analysis'
      end
    end
  end

  subject(:environment) { test_class.new }

  describe '#prepare!' do
    it 'calls Container.finalize!' do
      instance = double('Instance')

      allow(Lapidary::Container).to receive(:finalize!)

      environment.prepare!(instance)

      expect(Lapidary::Container).to have_received(:finalize!)
    end
  end

  describe '#service_class' do
    it 'returns Analysis::Service' do
      expect(environment.service_class).to eq(Lapidary::Analysis::Service)
    end
  end

  describe '#count' do
    it 'returns 1' do
      expect(environment.count).to eq(1)
    end
  end
end
