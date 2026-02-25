# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Domain entity representing an issue with its journals.
    class Issue
      attr_reader :id, :subject, :author, :created_on, :journals

      def initialize(id:, subject: nil, author: nil, created_on: nil, journals: [])
        @id = id
        @subject = subject
        @author = author
        @created_on = created_on
        @journals = journals
      end

      def journal_ids
        journals.map(&:id)
      end
    end
  end
end
