defmodule ApplicationRunner.Storage do
  @moduledoc """
    ApplicationRunner.Storage implements everything needed for the crons to run properly.
  """
  alias ApplicationRunner.Crons.CronServices
  alias Quantum.Storage

  @dialyzer {:nowarn_function, child_spec: 1}

  @behaviour Storage

  @repo Application.compile_env(:application_runner, :repo)

  use GenServer

  @doc false
  @impl GenServer
  def init(_args), do: {:ok, nil}

  @doc false
  def start_link(_opts), do: :ignore

  @impl Storage
  @doc """
    This is handled by the CronServices, it should not be implemented
    because some parameters cannot be passed to this handle_cast
    such as `env_id`, `props`, `listener_name`, etc...

    Quantum can work without it thanks to the `update_job` method.
  """
  def add_job(_storage_pid, _job) do
    :ok
  end

  @impl Storage
  def delete_job(_storage_pid, job_name) do
    with {:ok, cron} <- CronServices.get_by_name(job_name) do
      CronServices.delete(cron)
    end
  end

  @impl Storage
  def update_job(_storage_pid, job) do
    with {:ok, cron} <- CronServices.get_by_name(job.name) do
      CronServices.update(cron, job)
    end
  end

  @impl Storage
  def jobs(_storage_pid) do
    CronServices.all()
    |> Enum.map(&CronServices.to_quantum/1)
  end

  @impl Storage
  def last_execution_date(_storage_pid) do
    case @repo.get(ApplicationRunner.Quantum, 1) do
      nil -> NaiveDateTime.utc_now()
      quantum_response -> quantum_response.last_execution_date
    end
  end

  @impl Storage
  def purge(_storage_pid) do
    # We do not want to purge the crons on Lenra
    :ok
  end

  @impl Storage
  def update_job_state(_storage_pid, job_name, state) do
    with {:ok, cron} <- CronServices.get_by_name(job_name) do
      CronServices.update(cron, %{"state" => state})
    end
  end

  @impl Storage
  def update_last_execution_date(_storage_pid, last_execution_date) do
    @repo.insert(ApplicationRunner.Quantum.update(last_execution_date),
      on_conflict: [set: [last_execution_date: last_execution_date]],
      conflict_target: :id
    )
  end
end
