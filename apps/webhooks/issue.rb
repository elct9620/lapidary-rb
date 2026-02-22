# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Domain entity representing an issue with its journals.
  class Issue
    attr_reader :id, :journals

    def initialize(id:, journals: [])
      @id = id
      @journals = journals
    end

    def journal_ids
      journals.map(&:id)
    end
  end
end
