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

    context 'when ProcessJob raises JobError' do
      let(:job_repository) { double('JobRepository') }
      let(:analysis_record_repository) { double('AnalysisRecordRepository') }
      let(:extractor) { double('Extractor') }
      let(:logger) { double('Logger', info: nil, error: nil) }

      before do
        Lapidary::Container.stub('analysis.repositories.job_repository', job_repository)
        Lapidary::Container.stub('analysis.repositories.analysis_record_repository', analysis_record_repository)
        Lapidary::Container.stub('analysis.extractors.llm_extractor', extractor)
        Lapidary::Container.stub('logger', logger)

        allow(job_repository).to receive(:claim_next).and_raise(
          Analysis::Entities::JobError, 'database connection lost'
        )
      end

      after do
        Lapidary::Container.unstub('analysis.repositories.job_repository')
        Lapidary::Container.unstub('analysis.repositories.analysis_record_repository')
        Lapidary::Container.unstub('analysis.extractors.llm_extractor')
        Lapidary::Container.unstub('logger')
      end

      it 'catches the error, logs it, and continues polling' do
        Async do |task|
          result = service.run(instance, evaluator)

          task.sleep(0.05)
          result.stop

          expect(logger).to have_received(:error).at_least(:once)
        end
      end
    end
  end
end
