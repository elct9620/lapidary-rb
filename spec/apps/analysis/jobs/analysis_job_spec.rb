# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Jobs::AnalysisJob do
  let(:job_repository) { Lapidary::Container['analysis.repositories.job_repository'] }
  let(:db) { Lapidary::Container['database'] }

  let(:llm_response) do
    {
      'triplets' => [
        {
          'subject' => { 'name' => 'matz', 'role' => 'maintainer' },
          'relationship' => 'Maintenance',
          'object' => { 'type' => 'CoreModule', 'name' => 'String' },
          'evidence' => 'matz maintains the String class'
        }
      ]
    }
  end

  let(:response_double) { double('Response', content: llm_response) }
  let(:chat_double) { double('Chat') }

  before do
    @orig_llm = Lapidary::Container['llm']
    llm_double = double('RubyLLM', chat: chat_double)
    allow(chat_double).to receive_messages(
      with_instructions: chat_double,
      with_tools: chat_double,
      with_schema: chat_double,
      ask: response_double
    )
    Lapidary::Container.stub('llm', llm_double)
  end

  after do
    Lapidary::Container.stub('llm', @orig_llm)
  end

  # Fresh instance so stubbed `llm` gets injected via dry-auto_inject
  subject(:analysis_job) { described_class.new }

  def enqueue_and_claim_job
    job = Analysis::Entities::Job.new(
      arguments: Analysis::Entities::JobArguments.new(
        entity_type: 'issue', entity_id: 42,
        content: 'Add new feature', author_username: 'matz',
        author_display_name: 'Yukihiro Matsumoto',
        created_on: '2024-01-15T10:30:00Z'
      )
    )
    job_repository.enqueue(job)
    job_repository.claim_next
  end

  it 'processes a job to completion' do
    job = enqueue_and_claim_job

    analysis_job.call(job)

    row = db[:jobs].where(id: job.id).first
    expect(row[:status]).to eq('done')
  end

  it 'creates an analysis record' do
    job = enqueue_and_claim_job

    analysis_job.call(job)

    record = db[:analysis_records].where(entity_type: 'issue', entity_id: 42).first
    expect(record).not_to be_nil
    expect(record[:analyzed_at]).not_to be_nil
  end
end
