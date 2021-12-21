defmodule ApplicationRunner.Repo.Migrations.UserData do
  use Ecto.Migration

  def change do
    create table(:applications) do
      timestamps()
    end

    create table(:datastores) do
      add(:application_id, references(:applications), null: false)
      add(:name, :string)

      timestamps()
    end

    create table(:data) do
      add(:datastore_id, references(:datastores), null: false)
      add(:data, :map, null: false)

      timestamps()
    end

    create table(:refs) do
      add(:referencer_id, references(:data), null: false)
      add(:referenced_id, references(:data), null: false)

      timestamps()
    end
  end
end
