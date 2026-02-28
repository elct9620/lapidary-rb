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

    context 'with job cleanup' do
      let(:job_repository) { double('JobRepository', claim_next: nil, delete_expired: 0) }
      let(:analysis_record_repository) { double('AnalysisRecordRepository') }
      let(:extractor) { double('Extractor') }
      let(:logger) { double('Logger', info: nil, warn: nil, error: nil) }

      before do
        Lapidary::Container.stub('analysis.repositories.job_repository', job_repository)
        Lapidary::Container.stub('analysis.repositories.analysis_record_repository', analysis_record_repository)
        Lapidary::Container.stub('analysis.extractors.llm_extractor', extractor)
        Lapidary::Container.stub('logger', logger)
      end

      after do
        Lapidary::Container.unstub('analysis.repositories.job_repository')
        Lapidary::Container.unstub('analysis.repositories.analysis_record_repository')
        Lapidary::Container.unstub('analysis.extractors.llm_extractor')
        Lapidary::Container.stub('logger', Console::Logger.new(Console::Output::Null.new))
      end

      it 'runs cleanup on first iteration' do
        Async do |task|
          result = service.run(instance, evaluator)
          task.sleep(0.05)
          result.stop

          expect(job_repository).to have_received(:delete_expired).at_least(:once)
        end
      end

      context 'when cleanup raises JobError' do
        before do
          allow(job_repository).to receive(:delete_expired).and_raise(
            Analysis::Entities::JobError, 'cleanup failed'
          )
        end

        it 'logs the error and continues polling' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(logger).to have_received(:error).at_least(:once)
          end
        end
      end

      context 'when JOB_RETENTION is invalid' do
        around do |example|
          original = Lapidary.config.analysis.job_retention
          Lapidary::Config.configure { |c| c.analysis.job_retention = 'invalid' }
          example.run
        ensure
          Lapidary::Config.configure { |c| c.analysis.job_retention = original }
        end

        it 'logs a warning and uses default retention' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(logger).to have_received(:warn).at_least(:once)
          end
        end
      end
    end

    context 'with Sentry queue transaction' do
      let(:job_repository) { double('JobRepository', claim_next: nil, delete_expired: 0) }
      let(:analysis_record_repository) { double('AnalysisRecordRepository') }
      let(:extractor) { double('Extractor') }
      let(:logger) { double('Logger', info: nil, warn: nil, error: nil) }
      let(:transaction) { double('Transaction', finish: nil) }

      before do
        Lapidary::Container.stub('analysis.repositories.job_repository', job_repository)
        Lapidary::Container.stub('analysis.repositories.analysis_record_repository', analysis_record_repository)
        Lapidary::Container.stub('analysis.extractors.llm_extractor', extractor)
        Lapidary::Container.stub('logger', logger)

        allow(Sentry).to receive(:start_transaction).and_return(transaction)
        allow(Sentry).to receive(:get_current_scope).and_return(double('Scope', set_span: nil))
        allow(transaction).to receive(:set_data)
      end

      after do
        Lapidary::Container.unstub('analysis.repositories.job_repository')
        Lapidary::Container.unstub('analysis.repositories.analysis_record_repository')
        Lapidary::Container.unstub('analysis.extractors.llm_extractor')
        Lapidary::Container.stub('logger', Console::Logger.new(Console::Output::Null.new))
      end

      it 'sets messaging.destination.name on the transaction' do
        Async do |task|
          result = service.run(instance, evaluator)
          task.sleep(0.05)
          result.stop

          expect(transaction).to have_received(:set_data)
            .with(Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, 'analysis.jobs')
            .at_least(:once)
        end
      end
    end

    context 'when ProcessJob raises JobError' do
      let(:job_repository) { double('JobRepository', delete_expired: 0) }
      let(:analysis_record_repository) { double('AnalysisRecordRepository') }
      let(:extractor) { double('Extractor') }
      let(:logger) { double('Logger', info: nil, warn: nil, error: nil) }

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
        Lapidary::Container.stub('logger', Console::Logger.new(Console::Output::Null.new))
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
