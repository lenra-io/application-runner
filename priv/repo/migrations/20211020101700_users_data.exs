defmodule ApplicationRunner.Repo.Migrations.UserData do
  use Ecto.Migration

  def change do
    create table(:environments) do
      timestamps()
    end

    create table(:datastores) do
      add(:environment_id, references(:environments), null: false)
      add(:name, :string)

      timestamps()
    end

    create(unique_index(:datastores, [:name, :environment_id], name: :datastores_name_application_id_index))

    create table(:data) do
      add(:datastore_id, references(:datastores), null: false)
      add(:data, :map, null: false)

      timestamps()
    end

    create table(:data_references) do
      add(:refs_id, references(:data), null: false)
      add(:refBy_id, references(:data), null: false)

      timestamps()
    end
  end
end
