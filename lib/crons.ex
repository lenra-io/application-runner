defmodule ApplicationRunner.Crons do
  @moduledoc """
    ApplicationRunner.Crons delegates methods to the corresponding service.
  """

  alias ApplicationRunner.Crons

  defdelegate create(env_id, params), to: Crons.CronServices
  defdelegate get(id), to: Crons.CronServices
  defdelegate get_all(env_id), to: Crons.CronServices
  defdelegate get_all(env_id, user_id), to: Crons.CronServices
  defdelegate update(cron, params), to: Crons.CronServices
  defdelegate delete(cron), to: Crons.CronServices

  defdelegate new(env_id, params), to: Crons.Cron
end
