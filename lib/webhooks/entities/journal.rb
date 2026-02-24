# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing a journal entry on an issue.
    class Journal
      attr_reader :id, :notes, :author_username, :author_display_name

      def initialize(id:, notes: nil, author_username: nil, author_display_name: nil)
        @id = id
        @notes = notes
        @author_username = author_username
        @author_display_name = author_display_name
      end
    end
  end
end
