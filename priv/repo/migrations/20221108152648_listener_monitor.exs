defmodule ApplicationRunner.Repo.Migrations.ListenerMonitor do
  use Ecto.Migration

  def change do
    create table(:session_listener_measurement, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:session_mesureament_uuid, references(:session_measurement), null: false)
      add(:start_time, :timestamp, null: false)
      add(:end_time, :timestamp)
      add(:duration, :integer)

      timestamps()
    end

    create table(:env_listener_measurement, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:environment_id, references(:environment), null: false)
      add(:start_time, :timestamp, null: false)
      add(:end_time, :timestamp)
      add(:duration, :integer)

      timestamps()
    end

  end
end
