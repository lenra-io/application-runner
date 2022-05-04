defmodule ApplicationRunner.Repo.Migrations.RemoveReference do
  use Ecto.Migration

  def change do
    alter table(:data_references) do
      remove(:refs_id, references(:datas), null: false)
      remove(:refBy_id, references(:datas), null: false)
      add(:refs_id, references(:datas, on_delete: :delete_all), null: false)
      add(:refBy_id, references(:datas, on_delete: :delete_all), null: false)
    end

    create(unique_index(:data_references, [:refs_id, :refBy_id], name: :data_references_refs_id_refBy_id))
  end
end
