defmodule ApplicationRunner.SessionManagers do
  @moduledoc """
    This module handle all the session for one app.
    This allow to create/recreate/delete session for the app and possibly many other operations on sessions.
  """
  use DynamicSupervisor

  alias ApplicationRunner.{AppManagers, AppManager, SessionManager}

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start session for the given app_id and session_id and add it to the :sessions group of swarm.
  This in fact recreate a new process with the given session_id.
  This give the possibility for children modules to recreate their states (cache, UI etc..) if the session_id is the same as before.

  The session should be started with the same session_id if the client socket is disconnected for a short period of time.
  """
  @spec start_session(number(), term()) :: {:error, any} | {:ok, pid()}
  def start_session(app_id, session_id) do
    with {:ok, _pid} <- ensure_app_started(app_id),
         {:ok, session_managers_pid} <- fetch_session_managers_pid(app_id),
         {:ok, pid} <-
           DynamicSupervisor.start_child(
             session_managers_pid,
             {SessionManager, [app_id: app_id, session_id: session_id]}
           ) do
      Swarm.join(:sessions, pid)
      {:ok, pid}
    end
  end

  @doc """
    Ensure that the app process is started. Start the app if not.
  """
  @spec ensure_app_started(number()) :: {:ok, pid}
  def ensure_app_started(app_id) do
    case AppManagers.start_app(app_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_registered, pid}} -> {:ok, pid}
    end
  end

  defp fetch_session_managers_pid(app_id) do
    with {:ok, pid} <- AppManagers.fetch_app_manager_pid(app_id) do
      AppManager.fetch_module_pid(pid, ApplicationRunner.SessionManagers)
    end
  end

  def terminate_session(app_id, child_pid) do
    with {:ok, pid} <- fetch_session_managers_pid(app_id) do
      DynamicSupervisor.terminate_child(pid, child_pid)
    end
  end

  @spec fetch_session_manager_pid(any) :: {:error, :session_not_started} | {:ok, pid()}
  def fetch_session_manager_pid(session_id) do
    case Swarm.whereis_name({:session, session_id}) do
      :undefined -> {:error, :session_not_started}
      pid -> {:ok, pid}
    end
  end
end
