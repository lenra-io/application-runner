defmodule ApplicationRunner.Repo.Migrations.AdaptCronToQuantum do
  use Ecto.Migration

  def change do
    alter table(:crons) do
      add :name, :string
      add :overlap, :boolean
      add :state, :string
      add :timezone, :date
      remove :last_run_date
    end

    rename table(:crons), :cron_expression, to: :schedule
  end
end
