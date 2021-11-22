defmodule ApplicationRunner.SessionManager do
  @moduledoc """
    This module is the Session supervisor that handle the SupervisorManager children modules.
  """
  use GenServer
  alias ApplicationRunner.{SessionManagers, SessionSupervisor}

  @inactivity_timeout Application.fetch_env!(:application_runner, :session_inactivity_timeout)

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, {:session, session_id}})
  end

  @impl true
  def init(opts) do
    {:ok, session_supervisor_pid} = SessionSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The SessionManager should be restarted by the SessionManagers then it will restart the supervisor.
    Process.link(session_supervisor_pid)
    {:ok, [session_supervisor_pid: session_supervisor_pid, opts: opts], @inactivity_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    app_id = Keyword.fetch!(state.opts, :app_id)
    SessionManagers.terminate_session(app_id, self())
    {:noreply, state}
  end

  @doc """
    return the app-level module.
    This can be used to get module declared in the `AppSupervisor` (like the cache module for example)
  """
  def fetch_module_pid(session_manager_pid, module_name) when is_pid(session_manager_pid) do
    with {:ok, supervisor_pid} <- fetch_supervisor_pid(session_manager_pid) do
      Supervisor.which_children(supervisor_pid)
      |> Enum.find({:error, :no_such_module}, fn
        {name, _, _, _} -> module_name == name
      end)
      |> case do
        {_, pid, _, _} ->
          {:ok, pid}

        {:error, :no_such_module} ->
          raise "No such Module in AppSupervisor. This should not happen."
      end
    end
  end

  defp fetch_supervisor_pid(session_manager_pid) when is_pid(session_manager_pid) do
    {:ok, GenServer.call(session_manager_pid, :get_session_supervisor_pid)}
  end

  @impl true
  def handle_call(:get_session_supervisor_pid, _from, state) do
    case Keyword.fetch!(state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, state, @inactivity_timeout}
    end
  end
end
