# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:jobs) do
      add_column :arguments, :text, null: false, default: '{}'
      drop_column :entity_type
      drop_column :entity_id
    end
  end

  down do
    alter_table(:jobs) do
      add_column :entity_type, String, null: false, default: ''
      add_column :entity_id, String, null: false, default: ''
      drop_column :arguments
    end
  end
end
