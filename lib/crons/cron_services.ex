defmodule ApplicationRunner.Crons.CronServices do
  @moduledoc """
    The service that manages the crons.
  """

  import Ecto.Query, only: [from: 2, from: 1]

  alias ApplicationRunner.EventHandler
  alias ApplicationRunner.Crons.{Cron, CronServices}
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Errors.TechnicalError
  alias Crontab.CronExpression.Parser

  @adapter Application.compile_env(:application_runner, :adapter)
  @repo Application.compile_env(:application_runner, :repo)

  def run_cron(
        action,
        props,
        event,
        env_id
      ) do
    with {:ok, metadata} <-
           Environment.create_metadata(env_id),
         {:ok, _pid} <-
           Environment.ensure_env_started(metadata) do
      EventHandler.send_env_event(env_id, action, props, event)
    end
  end

  def create(env_id, %{"listener_name" => _action} = params) do
    with {:ok, cron} = res <-
           Cron.new(env_id, params)
           |> @repo.insert() do
      cron
      |> to_quantum()
      |> ApplicationRunner.Scheduler.add_job()

      res
    end
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

  def to_quantum(cron) do
    {:ok, schedule} = Parser.parse(cron.schedule)

    job =
      ApplicationRunner.Scheduler.new_job(
        name: cron.name,
        overlap: cron.overlap,
        state: String.to_existing_atom(cron.state),
        schedule: schedule
      )

    job
    |> Quantum.Job.set_task(
      {CronServices, :run_cron,
       [
         cron.listener_name,
         cron.props,
         %{},
         cron.environment_id
       ]}
    )
  end
end
