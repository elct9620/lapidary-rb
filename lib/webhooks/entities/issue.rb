# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing an issue with its journals.
    class Issue
      attr_reader :id, :subject, :author, :journals

      def initialize(id:, subject: nil, author: nil, journals: [])
        @id = id
        @subject = subject
        @author = author
        @journals = journals
      end

      def author_username
        author&.username
      end

      def author_display_name
        author&.display_name
      end

      def journal_ids
        journals.map(&:id)
      end
    end
  end
end
