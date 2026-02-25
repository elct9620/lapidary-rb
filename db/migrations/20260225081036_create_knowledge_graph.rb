# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:nodes) do
      String :id, primary_key: true
      String :type, null: false
      String :data
      DateTime :created_at
      DateTime :updated_at

      index :type
    end

    create_table(:edges) do
      String :source, null: false
      String :target, null: false
      String :relationship, null: false
      String :properties
      DateTime :created_at
      DateTime :updated_at

      foreign_key [:source], :nodes, key: :id
      foreign_key [:target], :nodes, key: :id
      unique %i[source target relationship]
      index :source
      index :target
    end
  end
end
