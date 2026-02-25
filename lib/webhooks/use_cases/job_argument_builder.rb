# auto_register: false
# frozen_string_literal: true

module Webhooks
  module UseCases
    # Builds job arguments from an issue and an analysis record.
    # Maps entity data into the flat hash structure expected by the scheduler.
    class JobArgumentBuilder
      def initialize(issue)
        @issue = issue
      end

      def call(record)
        case record.entity_type
        when Entities::EntityType::ISSUE
          build_issue_arguments
        when Entities::EntityType::JOURNAL
          build_journal_arguments(record)
        else
          raise ArgumentError, "unknown entity type: #{record.entity_type}"
        end
      end

      private

      def build_issue_arguments
        {
          entity_type: Entities::EntityType::ISSUE.to_s,
          entity_id: @issue.id,
          content: @issue.subject,
          created_on: @issue.created_on,
          **author_fields(@issue.author)
        }
      end

      def build_journal_arguments(record)
        journal = find_journal(record)
        {
          entity_type: Entities::EntityType::JOURNAL.to_s,
          entity_id: journal.id,
          content: journal.notes,
          issue_id: @issue.id, issue_content: @issue.subject,
          created_on: journal.created_on,
          **author_fields(journal.author)
        }
      end

      def author_fields(author)
        { author_username: author&.username, author_display_name: author&.display_name }
      end

      def find_journal(record)
        journal = @issue.journals.find { |j| j.id == record.entity_id }
        raise ArgumentError, "journal #{record.entity_id} not found in issue #{@issue.id}" unless journal

        journal
      end
    end
  end
end
