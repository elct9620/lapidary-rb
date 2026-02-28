# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    # Immutable value object representing a structured LLM prompt with system and user parts.
    Prompt = Data.define(:system, :user)
  end
end
