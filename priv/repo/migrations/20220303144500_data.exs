defmodule ApplicationRunner.Repo.Migrations.Data do
  use Ecto.Migration

  def change do
    create table(:environments) do
      timestamps()
    end

    create table(:users) do
      timestamps()
    end

    create table(:datastores) do
      add(:environment_id, references(:environments), null: false)
      add(:name, :string)

      timestamps()
    end

    create(unique_index(:datastores, [:name, :environment_id], name: :datastores_name_application_id_index))

    create table(:datas) do
      add(:datastore_id, references(:datastores), null: false, on_delete: :delete_all)
      add(:data, :map, null: false)

      timestamps()
    end

    create table(:user_datas) do
      add(:user_id, references(:users), null: false)
      add(:data_id, references(:data), null: false)

      timestamps()
    end

    create table(:data_references) do
      add(:refs_id, references(:data), null: false)
      add(:refBy_id, references(:data), null: false)

      timestamps()
    end
  end
end
