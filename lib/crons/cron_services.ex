defmodule ApplicationRunner.Crons.CronServices do
  @moduledoc """
    The service that manages the crons.
  """

  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Errors.TechnicalError

  @repo Application.compile_env(:application_runner, :repo)

  def create(env_id, params) do
    Cron.new(env_id, params)
    |> @repo.insert()
  end

  def get(id) do
    case @repo.get(Cron, id) do
      nil -> TechnicalError.error_404_tuple()
      cron -> {:ok, cron}
    end
  end

  def get_all(env_id) do
    @repo.all(from(c in Cron, where: c.environment_id == ^env_id))
  end

  def get_all(env_id, user_id) do
    @repo.all(from(c in Cron, where: c.environment_id == ^env_id and c.user_id == ^user_id))
  end

  def update(cron, params) do
    @repo.update(Ecto.Changeset.change(cron, params))
  end
end
