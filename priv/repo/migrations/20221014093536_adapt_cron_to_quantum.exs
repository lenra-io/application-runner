defmodule ApplicationRunner.Repo.Migrations.AdaptCronToQuantum do
  use Ecto.Migration

  def change do
    alter table(:crons) do
      add :schedule, Crontab.CronExpression.t()
      add :overlap, :boolean
      # add :run_strategy, ???
      add :state, :atom
      # add :task, ???

      execute(fn ->
        from(c in "crons",
        update: [set: [schedule: Crontab.CronExpression.Parser.parse!(c.cron_expression)]],
        where: c.cron_expression)
        |> ApplicationRunner.Repo.update_all([])
      end, fn ->
        from(c in "crons",
        update: [set: [cron_expression: Crontab.CronExpression.Composer.compose(c.schedule)]],
        where: c.schedule)
        |> ApplicationRunner.Repo.update_all([])
      end)

      remove :cron_expression
    end
  end
end
