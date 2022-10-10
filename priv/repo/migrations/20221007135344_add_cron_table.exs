defmodule ApplicationRunner.Repo.Migrations.AddCronTable do
  use Ecto.Migration

  def change do
    create table(:crons) do
      add(:environment_id, references(:environments), null: false)
      add(:user_id, references(:users))
      add(:listener_name, :string, null: false)
      add(:cron, :string, null: false)
      add(:props, :map)

      timestamps()
    end
  end
end
