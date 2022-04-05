defmodule ApplicationRunner.Repo.Migrations.DataQueryView do
  use Ecto.Migration

  def change do

    alter table(:data_references) do
      remove(:refBy_id, references(:datas), null: false)
      add(:ref_by_id, references(:datas, on_delete: :delete_all), null: false)
    end

    create(unique_index(:data_references, [:refs_id, :ref_by_id], name: :data_references_refs_id_ref_by_id))



    alter table(:users) do
      add(:email, :string, null: false, default: "test@lenra.io")
    end

    execute("
    CREATE VIEW data_query_view AS
    SELECT
    d.id as id,
    ds.environment_id as environment_id,
    jsonb_build_object(
      '_datastore', ds.name,
      '_id', d.id,
      '_data', d.data,
      '_refs', (SELECT COALESCE((SELECT jsonb_agg(dr.refs_id) FROM data_references as dr where ref_by_id = d.id GROUP BY dr.ref_by_id), '[]'::jsonb)),
      '_refBy', (SELECT COALESCE((SELECT jsonb_agg(dr.ref_by_id) FROM data_references as dr where refs_id = d.id GROUP BY dr.refs_id), '[]'::jsonb))
    ) ||
    CASE  WHEN ds.name != 'userData' THEN '{}'::jsonb
          WHEN ds.name = 'userData' THEN jsonb_build_object(
            '_user', (SELECT row_to_json(_) FROM (SELECT u.email, u.id) AS _)
          )
    END
    as data
      FROM datas AS d
      INNER JOIN datastores AS ds ON (ds.id = d.datastore_id)
      LEFT JOIN user_datas AS ud ON (ud.data_id = d.id)
      LEFT JOIN users AS u ON (u.id = ud.user_id);
    ",  "DROP VIEW IF EXISTS data_query_view")
  end
end
