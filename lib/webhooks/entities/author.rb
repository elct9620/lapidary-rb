# auto_register: false
# frozen_string_literal: true

module Webhooks
  module Entities
    # Value object representing an author with username and display name.
    Author = Data.define(:username, :display_name)
  end
end
