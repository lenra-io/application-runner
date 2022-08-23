defmodule ApplicationRunner.Session.DynamicSupervisor do
  @moduledoc """
    This module handles all the sessions for one app.
    This allows to create/recreate/delete sessions for the app and possibly many other operations on sessions.
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.{Environment, Session}

  def start_link(%Environment.Metadata{env_id: env_id}) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(env_id))
  end

  def start_link(opts) do
    raise "No Env Metadata #{inspect(opts)}"
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
  @spec start_session(term(), term()) ::
          {:error, any} | {:ok, pid()}
  def start_session(session_metadata, env_metadata) do
    with {:ok, _pid} <- Environment.ensure_env_started(env_metadata) do
      DynamicSupervisor.start_child(
        get_full_name(env_metadata.env_id),
        {Session.Supervisor, session_metadata}
      )
    end
  end

  @doc """
    Stop the `SessionManager` with the given `session_id` and return `:ok`.
    If there is no `SessionManager` for the given `session_id`, then return `{:error, :not_started}`
  """
  @spec stop_session(number()) :: :ok | {:error, :app_not_started}
  def stop_session(session_id) do
    Supervisor.stop(Session.Supervisor.get_full_name(session_id))
  end

  def terminate_session(session_manager_pid) do
    DynamicSupervisor.terminate_child(ApplicationRunner.Session.Managers, session_manager_pid)
  end
end
