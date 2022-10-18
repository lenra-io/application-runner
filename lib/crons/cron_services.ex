defmodule ApplicationRunner.Crons.CronServices do
  @moduledoc """
    The service that manages the crons.
  """

  import Ecto.Query, only: [from: 2, from: 1]

  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Errors.TechnicalError

  @repo Application.compile_env(:application_runner, :repo)

  def create(env_id, params) do
    Cron.new(env_id, params)
    |> @repo.insert()

    ApplicationRunner.Scheduler.new_job(
      # Map to keyword list
      Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)
    )
    |> ApplicationRunner.Scheduler.add_job()
  end

  def get(id) do
    case @repo.get(Cron, id) do
      nil -> TechnicalError.error_404_tuple()
      cron -> {:ok, cron}
    end
  end

  def get_by_name(name) do
    case @repo.get_by(Cron, name: name) do
      nil -> TechnicalError.error_404_tuple()
      cron -> {:ok, cron}
    end
  end

  def all do
    @repo.all(from(c in Cron))
  end

  def all(env_id) do
    @repo.all(from(c in Cron, where: c.environment_id == ^env_id))
  end

  def all(env_id, user_id) do
    @repo.all(from(c in Cron, where: c.environment_id == ^env_id and c.user_id == ^user_id))
  end

  def update(cron, params) do
    Cron.update(cron, params)
    |> @repo.update()
  end

  def delete(cron) do
    @repo.delete(cron)
  end
end
