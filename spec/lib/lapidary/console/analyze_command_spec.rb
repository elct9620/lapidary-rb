# frozen_string_literal: true

require 'spec_helper'
require 'irb/command'
require 'lapidary/console/analyze_command'

RSpec.describe Lapidary::Console::AnalyzeCommand do
  subject(:command) { described_class.new(irb_context) }

  let(:irb_context) { double('irb_context') }

  let(:redmine_api_url) { 'https://bugs.ruby-lang.org/issues/42.json?include=journals' }
  let(:redmine_response) do
    {
      issue: {
        id: 42,
        subject: 'Test issue',
        description: 'Test description',
        author: { id: 1, name: 'matz (Yukihiro Matsumoto)' },
        created_on: '2024-01-15T10:30:00Z',
        journals: [
          { id: 101, user: { id: 2, name: 'nobu (Nobuyoshi Nakada)' },
            notes: 'A comment', created_on: '2024-01-16T08:00:00Z' }
        ]
      }
    }
  end

  before do
    stub_request(:get, redmine_api_url)
      .to_return(status: 200, body: JSON.generate(redmine_response),
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#execute' do
    it 'schedules analysis jobs for an issue' do
      expect { command.execute('42') }.to output(/Scheduled 2 analysis job\(s\) for issue #42/).to_stdout
    end

    it 'schedules only untracked entities by default' do
      db = Lapidary::Container['database']
      db[:analysis_records].insert(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)

      expect { command.execute('42') }.to output(/Scheduled 1 analysis job\(s\)/).to_stdout
    end

    it 'schedules all entities with --force' do
      db = Lapidary::Container['database']
      db[:analysis_records].insert(entity_type: 'issue', entity_id: 42, analyzed_at: Time.now)
      db[:analysis_records].insert(entity_type: 'journal', entity_id: 101, analyzed_at: Time.now)

      expect { command.execute('42 --force') }.to output(/Scheduled 2 analysis job\(s\)/).to_stdout
    end

    it 'displays usage for non-numeric input' do
      expect { command.execute('abc') }.to output(/Usage: analyze <issue_id>/).to_stderr
    end

    it 'displays usage for empty input' do
      expect { command.execute('') }.to output(/Usage: analyze <issue_id>/).to_stderr
    end

    it 'displays error when issue fetch fails' do
      stub_request(:get, redmine_api_url).to_return(status: 404, body: '{}',
                                                    headers: { 'Content-Type' => 'application/json' })

      expect { command.execute('42') }.to output(/Failed to fetch issue/).to_stderr
    end
  end
end
