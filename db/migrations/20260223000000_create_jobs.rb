# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:jobs) do
      primary_key :id
      String :entity_type, null: false
      String :entity_id, null: false
      String :status, null: false, default: 'pending'
      Integer :attempts, null: false, default: 0
      Integer :max_attempts, null: false, default: 3
      String :error
      DateTime :scheduled_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index %i[status scheduled_at]
    end
  end
end
