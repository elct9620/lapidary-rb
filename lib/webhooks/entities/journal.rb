# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing a journal entry on an issue.
    class Journal
      attr_reader :id, :notes, :author

      def initialize(id:, notes: nil, author: nil)
        @id = id
        @notes = notes
        @author = author
      end

      def author_username
        author&.username
      end

      def author_display_name
        author&.display_name
      end
    end
  end
end
