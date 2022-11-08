defmodule ApplicationRunner.Crons.CronServices do
  @moduledoc """
    The service that manages the crons.
  """

  import Ecto.Query, only: [from: 2, from: 1]

  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Guardian.AppGuardian
  alias Crontab.CronExpression.Parser

  @repo Application.compile_env(:application_runner, :repo)

  def run_cron(
        function_name,
        action,
        props,
        event,
        env_id
      ) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id}),
         {:ok, _pid} <-
           Environment.ensure_env_started(%Environment.Metadata{
             env_id: env_id,
             function_name: function_name,
             token: token
           }) do
      ApplicationRunner.ApplicationServices.run_listener(
        function_name,
        action,
        props,
        event,
        Environment.fetch_token(env_id)
      )
    end
  end

  def create(env_id, %{"listener_name" => action} = params) do
    res =
      Cron.new(env_id, params)
      |> @repo.insert()

    {:ok, schedule} = Parser.parse(Map.get(params, "schedule"))

    # Map to keyword list
    job_params =
      params
      |> Map.take(["name", "overlap", "state", "timezone"])
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)

    ApplicationRunner.Scheduler.new_job(job_params ++ [schedule: schedule])
    |> Quantum.Job.set_task(
      {ApplicationRunner.Crons.CronServices, :run_cron,
       [Map.get(params, "function_name"), action, Map.get(params, "props"), %{}, env_id]}
    )
    |> ApplicationRunner.Scheduler.add_job()

    res
  end

  def create(_env_id, _params) do
    BusinessError.invalid_params_tuple()
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