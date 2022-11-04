defmodule ApplicationRunner.Storage do
  alias ApplicationRunner.Crons.CronServices
  alias Quantum.Storage

  @behaviour Storage

  use GenServer

  @repo Application.compile_env(:application_runner, :repo)

  @impl GenServer
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, arg)
  end

  @impl Storage
  def add_job(storage_pid, job) do
    GenServer.cast(storage_pid, {:add_job, job})
  end

  @impl Storage
  def delete_job(storage_pid, job_name) do
    GenServer.cast(storage_pid, {:delete_job, job_name})
  end

  @impl Storage
  def update_job(storage_pid, job) do
    GenServer.cast(storage_pid, {:update_job, job})
  end

  @impl Storage
  def jobs(storage_pid) do
    GenServer.call(storage_pid, :jobs)
  end

  @impl Storage
  def last_execution_date(storage_pid) do
    GenServer.call(storage_pid, :last_execution_date)
  end

  @impl Storage
  def purge(storage_pid) do
    GenServer.cast(storage_pid, :purge)
  end

  @impl Storage
  def update_job_state(storage_pid, job_name, state) do
    GenServer.cast(storage_pid, {:update_job_state, job_name, state})
  end

  @impl Storage
  def update_last_execution_date(storage_pid, last_execution_date) do
    GenServer.cast(storage_pid, {:update_last_execution_date, last_execution_date})
  end

  @impl GenServer
  @doc """
    This is handled by the CronServices, it should not be implemented
    because some parameters cannot be passed to this handle_cast
    such as `env_id`, `props`, `listener_name`, etc...

    Quantum can work without it thanks to the `update_job` method.
  """
  def handle_cast({:add_job, _job}, state) do
    {:noreply, state}
  end

  def handle_cast({:delete_job, job_name}, state) do
    with {:ok, cron} <- CronServices.get_by_name(job_name) do
      CronServices.delete(cron)
    end

    {:noreply, state}
  end

  def handle_cast({:update_job, job}, state) do
    with {:ok, cron} <- CronServices.get_by_name(job.name) do
      CronServices.update(cron, job)
    end

    {:noreply, state}
  end

  def handle_cast({:update_job_state, job_name, job_state}, state) do
    with {:ok, cron} <- CronServices.get_by_name(job_name) do
      CronServices.update(cron, %{"state" => job_state})
    end

    {:noreply, state}
  end

  def handle_cast(
        {:update_last_execution_date, last_execution_date},
        state
      ) do
    @repo.insert(ApplicationRunner.Quantum.update(last_execution_date),
      on_conflict: [set: [last_execution_date: last_execution_date]],
      conflict_target: :id
    )

    {:noreply, state}
  end

  def handle_cast(:purge, state) do
    # TODO: What do we want to purge ? Remove all crons ? Reset all dates (what does it mean) ?
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:jobs, _from, state) do
    {:reply, CronServices.all(), state}
  end

  def handle_call(:last_execution_date, _from, state) do
    case IO.inspect(@repo.get(ApplicationRunner.Quantum, 1)) do
      nil -> {:reply, NaiveDateTime.utc_now(), state}
      date -> {:reply, date, state}
    end
  end
end
