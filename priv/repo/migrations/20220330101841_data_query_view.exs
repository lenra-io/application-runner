defmodule ApplicationRunner.Repo.Migrations.DataQueryView do
  use Ecto.Migration

  def change do
    rename table(:data_references), :refBy_id, to: :ref_by_id

    execute("
    CREATE VIEW data_query_view AS
    SELECT
    d.id as id,
    json_build_object(
      '_datastore', ds.name,
      '_id', d.id,
      '_data', d.data,
      '_refs', (SELECT json_agg(dr.refs_id) FROM data_references as dr where ref_by_id = d.id GROUP BY dr.ref_by_id),
      '_refBy', (SELECT json_agg(dr.ref_by_id) FROM data_references as dr where refs_id = d.id GROUP BY dr.refs_id)
    ) as data
      FROM datas AS d
      INNER JOIN datastores AS ds ON (ds.id = d.datastore_id);
    ",  "DROP VIEW IF EXISTS data_query_view")
  end
end
