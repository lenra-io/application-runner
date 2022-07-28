defmodule ApplicationRunner.Session.Managers do
  @moduledoc """
    This module handles all the sessions for one app.
    This allows to create/recreate/delete sessions for the app and possibly many other operations on sessions.
  """
  use DynamicSupervisor

  alias ApplicationRunner.{Environments, Session}

  alias ApplicationRunner.Errors.BusinessError

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start session for the given env_id and session_id and add it to the :sessions group of swarm.
  This in fact recreate a new process with the given session_id.
  This give the possibility for children modules to recreate their states (cache, UI etc..) if the session_id is the same as before.

  The session should be started with the same session_id if the client socket is disconnected for a short period of time.
  """
  @spec start_session(term(), term(), term(), term()) ::
          {:error, any} | {:ok, pid()}
  def start_session(session_id, env_id, session_state, env_state, context) do
    with {:ok, _pid} <- Environments.ensure_env_started(env_id, env_state) do
      DynamicSupervisor.start_child(
        ApplicationRunner.Session.Managers,
        {Session.Manager, [env_id: env_id, session_id: session_id, session_state: session_state, context: context]}
      )
    end
  end

  @doc """
    Stop the `SessionManager` with the given `session_id` and return `:ok`.
    If there is no `SessionManager` for the given `session_id`, then return `{:error, :not_started}`
  """
  @spec stop_session(number()) :: :ok | {:error, :app_not_started}
  def stop_session(session_id) do
    with {:ok, pid} <- fetch_session_manager_pid(session_id) do
      GenServer.call(pid, :stop)
    end
  end

  def terminate_session(session_manager_pid) do
    DynamicSupervisor.terminate_child(ApplicationRunner.Session.Managers, session_manager_pid)
  end

  @spec fetch_session_manager_pid(any) ::
          {:error, LenraCommon.Errors.BusinessError.t()} | {:ok, pid()}
  def fetch_session_manager_pid(session_id) do
    case Swarm.whereis_name({:session, session_id}) do
      :undefined -> BusinessError.session_not_started_tuple({:session, session_id})
      pid -> {:ok, pid}
    end
  end
end
