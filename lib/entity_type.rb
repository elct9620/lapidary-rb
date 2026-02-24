# auto_register: false
# frozen_string_literal: true

# Immutable value object representing the type of an entity being tracked.
EntityType = Data.define(:value) do
  def to_s
    value
  end
end

class EntityType
  ISSUE = new(value: 'issue')
  JOURNAL = new(value: 'journal')
end
