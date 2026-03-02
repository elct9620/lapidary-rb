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

  shared_context 'with stubbed container' do
    let(:job_repository) { double('JobRepository', claim_next: nil, delete_expired: 0) }
    let(:analysis_record_repository) { double('AnalysisRecordRepository') }
    let(:graph_repository) do
      double('GraphRepository', archive_expired: { archived_count: 0, entity_pairs: [] })
    end
    let(:extractor) { double('Extractor') }
    let(:logger) { double('Logger', info: nil, warn: nil, error: nil) }

    before do
      @orig_job_repo = Lapidary::Container['analysis.repositories.job_repository']
      @orig_analysis_repo = Lapidary::Container['analysis.repositories.analysis_record_repository']
      @orig_graph_repo = Lapidary::Container['analysis.repositories.graph_repository']
      @orig_extractor = Lapidary::Container['analysis.extractors.llm_extractor']

      Lapidary::Container.stub('analysis.repositories.job_repository', job_repository)
      Lapidary::Container.stub('analysis.repositories.analysis_record_repository', analysis_record_repository)
      Lapidary::Container.stub('analysis.repositories.graph_repository', graph_repository)
      Lapidary::Container.stub('analysis.extractors.llm_extractor', extractor)
      Lapidary::Container.stub('logger', logger)
    end

    after do
      Lapidary::Container.stub('analysis.repositories.job_repository', @orig_job_repo)
      Lapidary::Container.stub('analysis.repositories.analysis_record_repository', @orig_analysis_repo)
      Lapidary::Container.stub('analysis.repositories.graph_repository', @orig_graph_repo)
      Lapidary::Container.stub('analysis.extractors.llm_extractor', @orig_extractor)
      Lapidary::Container.stub('logger', Console::Logger.new(Console::Output::Null.new))
    end
  end

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
      include_context 'with stubbed container'

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
      include_context 'with stubbed container'

      let(:transaction) { double('Transaction', finish: nil) }

      before do
        allow(Sentry).to receive(:start_transaction).and_return(transaction)
        allow(Sentry).to receive(:get_current_scope).and_return(double('Scope', set_span: nil))
        allow(transaction).to receive(:set_data)
      end

      it 'does not start transaction on idle poll' do
        Async do |task|
          result = service.run(instance, evaluator)
          task.sleep(0.05)
          result.stop

          expect(Sentry).not_to have_received(:start_transaction)
        end
      end
    end

    context 'with graph archiving' do
      include_context 'with stubbed container'

      it 'runs archiving on first iteration' do
        Async do |task|
          result = service.run(instance, evaluator)
          task.sleep(0.05)
          result.stop

          expect(graph_repository).to have_received(:archive_expired).at_least(:once)
        end
      end

      context 'when archiving raises GraphError' do
        before do
          allow(graph_repository).to receive(:archive_expired).and_raise(
            Analysis::Entities::GraphError, 'archive failed'
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

      context 'when GRAPH_RETENTION is invalid' do
        around do |example|
          original = Lapidary.config.graph.retention
          Lapidary::Config.configure { |c| c.graph.retention = 'invalid' }
          example.run
        ensure
          Lapidary::Config.configure { |c| c.graph.retention = original }
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

    context 'when ProcessJob raises JobError' do
      include_context 'with stubbed container'

      before do
        allow(job_repository).to receive(:claim_next).and_raise(
          Analysis::Entities::JobError, 'database connection lost'
        )
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
