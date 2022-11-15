defmodule ApplicationRunner.Crons do
  @moduledoc """
    ApplicationRunner.Crons delegates methods to the corresponding service.
  """

  import Ecto.Query, only: [from: 2, from: 1]

  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.EventHandler
  alias ApplicationRunner.Repo
  alias Crontab.CronExpression.{Composer, Parser}

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
    env_id
    |> Cron.new(params)
    |> Ecto.Changeset.apply_changes()
    |> to_quantum()
    |> ApplicationRunner.Scheduler.add_job()
  end

  def create(_env_id, _params) do
    BusinessError.invalid_params_tuple()
  end

  def get(id) do
    case Repo.get(Cron, id) do
      nil -> TechnicalError.error_404_tuple()
      cron -> {:ok, cron}
    end
  end

  def get_by_name(name) do
    case Repo.get_by(Cron, name: name) do
      nil -> TechnicalError.error_404_tuple()
      cron -> {:ok, cron}
    end
  end

  def all do
    Repo.all(from(c in Cron))
  end

  def all(env_id) do
    Repo.all(from(c in Cron, where: c.environment_id == ^env_id))
  end

  def all(env_id, user_id) do
    Repo.all(from(c in Cron, where: c.environment_id == ^env_id and c.user_id == ^user_id))
  end

  def update(cron, params) do
    # Quantum's default behavior will update the job when using the add_job.
    # There is no Scheduler.update_job method.
    with %Ecto.Changeset{valid?: true} = changeset <-
           cron
           |> Cron.update(params) do
      changeset
      |> Ecto.Changeset.apply_changes()
      |> to_quantum()
      |> ApplicationRunner.Scheduler.add_job()
    end
  end

  def delete(cron) do
    cron
    |> ApplicationRunner.Scheduler.delete_job()
  end

  def to_quantum(cron) do
    with {:ok, schedule} <- Parser.parse(cron.schedule) do
      ApplicationRunner.Scheduler.new_job(
        name: cron.name,
        overlap: cron.overlap,
        state: String.to_existing_atom(cron.state),
        schedule: schedule,
        task:
          {ApplicationRunner.Crons, :run_cron,
           [
             cron.listener_name,
             cron.props,
             %{},
             cron.environment_id
           ]}
      )
    end
  end

  def to_schema(%Quantum.Job{
        name: name,
        overlap: overlap,
        schedule: schedule,
        state: state,
        task: {_, _, [listener_name, props, _, env_id]}
      }) do
    Cron.changeset(%Cron{environment_id: env_id}, %{
      "listener_name" => listener_name,
      "schedule" => Composer.compose(schedule),
      "props" => props,
      "name" => name,
      "overlap" => overlap,
      "state" => Atom.to_string(state)
    })
    |> Ecto.Changeset.apply_changes()
  end

  def to_schema(_invalid_job) do
    BusinessError.invalid_params_tuple()
  end

  defdelegate new(env_id, params), to: Cron
end
