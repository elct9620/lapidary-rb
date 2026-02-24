# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../config/web'

RSpec.describe Webhooks::API do
  include Rack::Test::Methods

  def app
    described_class
  end

  let(:redmine_api_url) { 'https://bugs.ruby-lang.org/issues/1.json?include=journals' }

  let(:redmine_response) do
    {
      issue: {
        id: 1,
        subject: 'Test issue',
        author: { id: 1, name: 'matz (Yukihiro Matsumoto)' },
        journals: [
          { id: 101, user: { id: 2, name: 'nobu (Nobuyoshi Nakada)' }, notes: 'First comment' },
          { id: 102, user: { id: 3, name: 'ko1' }, notes: 'Second comment' }
        ]
      }
    }
  end

  let(:redmine_success_headers) { { 'Content-Type' => 'application/json' } }

  def stub_redmine_success
    stub_request(:get, redmine_api_url)
      .to_return(
        status: 200,
        body: JSON.generate(redmine_response),
        headers: redmine_success_headers
      )
  end

  shared_examples 'a validation error' do
    it 'returns 422 Unprocessable Entity' do
      expect(last_response.status).to eq(422)
    end

    it 'returns JSON error body' do
      body = JSON.parse(last_response.body)
      expect(body['errors']).to have_key('issue_id')
    end
  end

  describe 'POST /webhook' do
    context 'with a valid request' do
      before do
        stub_redmine_success

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 202 Accepted' do
        expect(last_response.status).to eq(202)
      end

      it 'returns JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'returns status accepted' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('status' => 'accepted')
      end

      it 'enqueues a job for the issue with rich arguments' do
        db = Lapidary::Container['database']
        jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
        expect(jobs).to include(
          entity_type: 'issue',
          entity_id: 1,
          content: 'Test issue',
          author_username: 'matz',
          author_display_name: 'Yukihiro Matsumoto'
        )
      end

      it 'enqueues jobs for journals with rich arguments' do
        db = Lapidary::Container['database']
        jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
        expect(jobs).to include(
          entity_type: 'journal',
          entity_id: 101,
          content: 'First comment',
          author_username: 'nobu',
          author_display_name: 'Nobuyoshi Nakada',
          issue_id: 1,
          issue_content: 'Test issue'
        )
        expect(jobs).to include(
          entity_type: 'journal',
          entity_id: 102,
          content: 'Second comment',
          author_username: 'ko1',
          author_display_name: nil,
          issue_id: 1,
          issue_content: 'Test issue'
        )
      end
    end

    context 'with incremental journal tracking' do
      let(:process_job) do
        Analysis::UseCases::ProcessJob.new(
          job_repository: Lapidary::Container['analysis.repositories.job_repository'],
          analysis_record_repository: Lapidary::Container['analysis.repositories.analysis_record_repository'],
          extractor: Lapidary::Container['analysis.extractors.mock_extractor'],
          validator: Analysis::Ontology::Validator.new,
          logger: Lapidary::Container['logger']
        )
      end

      before do
        stub_redmine_success

        # First request enqueues jobs
        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'

        # Process all jobs (worker simulation)
        nil until process_job.call == false

        # Second request should not enqueue duplicates
        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 202 Accepted on second request' do
        expect(last_response.status).to eq(202)
      end

      it 'does not enqueue duplicate journal jobs after processing' do
        db = Lapidary::Container['database']
        jobs = db[:jobs].all.map { |r| JSON.parse(r[:arguments], symbolize_names: true) }
        journal_count = jobs.count { |j| j[:entity_type] == 'journal' }
        expect(journal_count).to eq(2)
      end
    end

    context 'when Redmine API fails' do
      before do
        stub_request(:get, redmine_api_url)
          .to_return(status: 503, body: 'Service Unavailable')

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 502 Bad Gateway' do
        expect(last_response.status).to eq(502)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'upstream service error')
      end
    end

    context 'when migration has not been run' do
      before do
        stub_redmine_success

        database = Lapidary::Container['database']
        database.drop_table(:analysis_records)

        post '/webhook',
             JSON.generate(issue_id: 1),
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 500 Internal Server Error' do
        expect(last_response.status).to eq(500)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'internal server error')
      end
    end

    context 'with non-JSON Content-Type' do
      before do
        post '/webhook',
             'issue_id=1',
             'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
      end

      it 'returns 415 Unsupported Media Type' do
        expect(last_response.status).to eq(415)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'Content-Type must be application/json')
      end
    end

    context 'with invalid JSON body' do
      before do
        post '/webhook',
             'not valid json',
             'CONTENT_TYPE' => 'application/json'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(last_response.status).to eq(422)
      end

      it 'returns JSON error body' do
        body = JSON.parse(last_response.body)
        expect(body).to eq('error' => 'invalid JSON')
      end
    end

    context 'with missing issue_id' do
      before { post '/webhook', JSON.generate(other: 'data'), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with issue_id as zero' do
      before { post '/webhook', JSON.generate(issue_id: 0), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with negative issue_id' do
      before { post '/webhook', JSON.generate(issue_id: -1), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end

    context 'with issue_id as string' do
      before { post '/webhook', JSON.generate(issue_id: 'abc'), 'CONTENT_TYPE' => 'application/json' }

      include_examples 'a validation error'
    end
  end
end
