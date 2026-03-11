# auto_register: false
# frozen_string_literal: true

require 'irb/command'

module Lapidary
  module Console
    # IRB command to manually trigger analysis for an issue
    class AnalyzeCommand < IRB::Command::Base
      category 'Maintenance'
      description 'Trigger analysis for an issue'
      help_message <<~HELP
        Usage: analyze <issue_id> [--force]

        Fetch an issue from Redmine and schedule analysis jobs for its
        untracked entities. With --force, schedule all entities even if
        they have already been analyzed.

        Examples:
          analyze 42
          analyze 42 --force
      HELP

      def execute(arg)
        issue_id, force = parse_arguments(arg)
        return unless issue_id

        count = build_use_case.call(issue_id, force: force)
        puts "Scheduled #{count} analysis job(s) for issue ##{issue_id}"
      rescue Webhooks::Entities::IssueFetchError => e
        warn "Failed to fetch issue: #{e.message}"
      end

      private

      def parse_arguments(arg)
        parts = arg.strip.split
        force = !parts.delete('--force').nil?
        raw_id = parts.first

        unless raw_id&.match?(/\A\d+\z/)
          warn 'Usage: analyze <issue_id> [--force]'
          return nil
        end

        [Integer(raw_id), force]
      end

      def build_use_case
        Webhooks::UseCases::HandleWebhook.new(
          issue_repository: Lapidary::Container['webhooks.repositories.issue_repository'],
          analysis_record_repository: Lapidary::Container['webhooks.repositories.analysis_record_repository'],
          analysis_scheduler: Lapidary::Container['webhooks.adapters.analysis_scheduler']
        )
      end
    end
  end
end

IRB::Command.register(:analyze, Lapidary::Console::AnalyzeCommand)
