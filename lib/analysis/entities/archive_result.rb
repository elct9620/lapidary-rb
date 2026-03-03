# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing the result of an edge archiving operation.
    ArchiveResult = Data.define(:archived_count, :entity_pairs)
  end
end
