# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing a journal entry on an issue.
    class Journal
      attr_reader :id, :notes, :author, :created_on

      def initialize(id:, notes: nil, author: nil, created_on: nil)
        @id = id
        @notes = notes
        @author = author
        @created_on = created_on
      end
    end
  end
end
