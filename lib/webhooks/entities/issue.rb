# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing an issue with its journals.
    class Issue
      attr_reader :id, :subject, :author_username, :author_display_name, :journals

      def initialize(id:, subject: nil, author_username: nil, author_display_name: nil, journals: [])
        @id = id
        @subject = subject
        @author_username = author_username
        @author_display_name = author_display_name
        @journals = journals
      end

      def journal_ids
        journals.map(&:id)
      end
    end
  end
end
