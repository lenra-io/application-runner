defmodule ApplicationRunner.Repo.Migrations.SessionMonitor do
  use Ecto.Migration

  def change do
    create table(:session_measurement, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:user_id, references(:users), null: false)
      add(:environment_id, references(:environments), null: false)
      add(:start_time, :date, null: false)
      add(:end_time, :date)
      add(:duration, :string)

      timestamps()
    end
  end
end
