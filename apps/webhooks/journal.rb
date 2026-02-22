# auto_register: false
# frozen_string_literal: true

module Webhooks
  # Domain entity representing a journal entry on an issue.
  class Journal
    attr_reader :id

    def initialize(id:)
      @id = id
    end
  end
end
