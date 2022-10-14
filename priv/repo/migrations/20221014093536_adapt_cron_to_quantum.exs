defmodule ApplicationRunner.Repo.Migrations.AdaptCronToQuantum do
  use Ecto.Migration

  def change do
    alter table(:crons) do
      add :schedule, Crontab.CronExpression.t()
      add :overlap, :boolean
      add :run_strategy, ???
      add :state, :atom
      add :task, ???
    end
  end
end
