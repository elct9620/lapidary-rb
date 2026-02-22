# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:analysis_records) do
      primary_key :id
      String :entity_type, null: false
      Integer :entity_id, null: false
      DateTime :analyzed_at, null: false

      unique %i[entity_type entity_id]
    end
  end
end
