# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :observations, :parent_entity_id, Integer
  end
end
