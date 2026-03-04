# frozen_string_literal: true

require 'spec_helper'
require 'async'
require_relative '../../../../lib/lapidary/analysis/worker'

RSpec.describe Lapidary::Analysis::Worker do
  let(:environment) do
    double('Environment', evaluator: evaluator)
  end

  let(:evaluator) do
    double('Evaluator', name: 'analysis', preload: nil)
  end

  let(:instance) { double('Instance') }

  subject(:service) { described_class.new(environment, evaluator) }

  shared_context 'with stubbed container' do
    let(:job_repository) { instance_double(Analysis::Repositories::JobRepository, claim_next: nil, delete_expired: 0) }
    let(:job_handler) { instance_double(Analysis::Jobs::AnalysisJob, call: nil) }
    let(:edge_archive_writer) do
      instance_double(Analysis::Repositories::EdgeArchiveWriter,
                      archive_expired: Analysis::Entities::ArchiveResult.new(archived_count: 0, entity_pairs: []))
    end
    let(:logger) { Lapidary::Container['logger'] }

    before do
      @orig_job_repo = Lapidary::Container['analysis.repositories.job_repository']
      @orig_edge_archive_repo = Lapidary::Container['analysis.repositories.edge_archive_writer']
      @orig_job_handler = Lapidary::Container['analysis.jobs.analysis_job']

      Lapidary::Container.stub('analysis.repositories.job_repository', job_repository)
      Lapidary::Container.stub('analysis.repositories.edge_archive_writer', edge_archive_writer)
      Lapidary::Container.stub('analysis.jobs.analysis_job', job_handler)
      Lapidary::Container.stub('logger', logger)
    end

    after do
      Lapidary::Container.stub('analysis.repositories.job_repository', @orig_job_repo)
      Lapidary::Container.stub('analysis.repositories.edge_archive_writer', @orig_edge_archive_repo)
      Lapidary::Container.stub('analysis.jobs.analysis_job', @orig_job_handler)
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

        it 'continues polling despite the error' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(result).to be_stopped
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

        it 'continues polling with default retention' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(result).to be_stopped
          end
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

          expect(edge_archive_writer).to have_received(:archive_expired).at_least(:once)
        end
      end

      context 'when archiving raises GraphError' do
        before do
          allow(edge_archive_writer).to receive(:archive_expired).and_raise(
            Analysis::Entities::GraphError, 'archive failed'
          )
        end

        it 'continues polling despite the error' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(result).to be_stopped
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

        it 'continues polling with default retention' do
          Async do |task|
            result = service.run(instance, evaluator)
            task.sleep(0.05)
            result.stop

            expect(result).to be_stopped
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

      it 'catches the error and continues polling' do
        Async do |task|
          result = service.run(instance, evaluator)

          task.sleep(0.05)
          result.stop

          expect(result).to be_stopped
        end
      end
    end
  end
end
