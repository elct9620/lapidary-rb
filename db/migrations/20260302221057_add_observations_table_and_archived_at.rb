# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:observations) do
      String :edge_source, null: false
      String :edge_target, null: false
      String :edge_relationship, null: false
      DateTime :observed_at, null: false
      String :source_entity_type, null: false
      Integer :source_entity_id, null: false
      String :evidence
      DateTime :created_at

      foreign_key %i[edge_source edge_target edge_relationship], :edges,
                  key: %i[source target relationship]
      unique %i[edge_source edge_target edge_relationship source_entity_type source_entity_id]
      index :observed_at
    end

    alter_table(:edges) do
      add_column :archived_at, DateTime
      add_index :archived_at
    end

    # Migrate existing observations from edges.properties JSON into the observations table
    from(:edges).each do |edge|
      next unless edge[:properties]

      observations = JSON.parse(edge[:properties], symbolize_names: true)
      observations.each do |obs|
        from(:observations).insert(
          edge_source: edge[:source],
          edge_target: edge[:target],
          edge_relationship: edge[:relationship],
          observed_at: obs[:observed_at],
          source_entity_type: obs[:source_entity_type],
          source_entity_id: obs[:source_entity_id],
          evidence: obs[:evidence],
          created_at: Time.now
        )
      end

      from(:edges)
        .where(source: edge[:source], target: edge[:target], relationship: edge[:relationship])
        .update(properties: nil)
    end
  end

  down do
    # Migrate observations back to edges.properties JSON
    from(:edges).each do |edge|
      observations = from(:observations).where(
        edge_source: edge[:source],
        edge_target: edge[:target],
        edge_relationship: edge[:relationship]
      ).all

      next if observations.empty?

      json_observations = observations.map do |obs|
        {
          observed_at: obs[:observed_at]&.iso8601,
          source_entity_type: obs[:source_entity_type],
          source_entity_id: obs[:source_entity_id],
          evidence: obs[:evidence]
        }
      end

      from(:edges)
        .where(source: edge[:source], target: edge[:target], relationship: edge[:relationship])
        .update(properties: JSON.generate(json_observations))
    end

    alter_table(:edges) do
      drop_index :archived_at
      drop_column :archived_at
    end

    drop_table(:observations)
  end
end
