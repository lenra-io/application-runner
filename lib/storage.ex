defmodule ApplicationRunner.Storage do
  alias Quantum.Storage

  @behaviour Storage

  use GenServer

  @impl GenServer
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
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
  def handle_cast({:add_job, _job}, state) do
    {:noreply, state}
  end

  def handle_cast({:delete_job, _job_name}, state) do
    {:noreply, state}
  end

  def handle_cast({:update_job_state, _job_name, _job_state}, state) do
    {:noreply, state}
  end

  def handle_cast(
        {:update_last_execution_date, _last_execution_date},
        state
      ) do
    {:noreply, state}
  end

  def handle_cast(:purge, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:jobs, _from, state) do
    {:reply, [], state}
  end

  def handle_call(:last_execution_date, _from, state) do
    {:reply, "", state}
  end
end
