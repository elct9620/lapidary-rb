# frozen_string_literal: true

require 'spec_helper'
require 'async'
require_relative '../../../../lib/lapidary/analysis/service'

RSpec.describe Lapidary::Analysis::Service do
  let(:environment) do
    double('Environment', evaluator: evaluator)
  end

  let(:evaluator) do
    double('Evaluator', name: 'analysis', preload: nil)
  end

  let(:instance) { double('Instance') }

  subject(:service) { described_class.new(environment, evaluator) }

  describe '#run' do
    it 'starts an async task that loops' do
      Async do |task|
        result = service.run(instance, evaluator)

        # The run method should return an Async::Task
        expect(result).to be_a(Async::Task)

        # Give the loop a moment to execute
        task.sleep(0.01)

        # Stop the task to verify graceful shutdown
        result.stop
        expect(result).to be_stopped
      end
    end
  end
end
