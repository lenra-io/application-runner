defmodule ApplicationRunner.EnvManagers do
  @moduledoc """
    This module manage all the applications.
    It can start/stop an `EnvManager`, get the `EnvManager` process, send a message to all the `EnvManager`, etc..
  """
  use DynamicSupervisor

  alias ApplicationRunner.{EnvManagers}

  @doc false
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
    Fetch the `EnvManager` pid corresponding to the `env_id`.
  """
  @spec fetch_env_manager_pid(number()) :: {:error, :env_not_started} | {:ok, pid()}
  def fetch_env_manager_pid(env_id) do
    case Swarm.whereis_name({:env, env_id}) do
      :undefined -> {:error, :env_not_started}
      pid -> {:ok, pid}
    end
  end

  @doc """
    Ask swarm to start the `EnvManager` with the given `env_id` and add it to the :apps group.
    This `EnvManager` process will be started in one of the cluster node.
    If the node is closed, swarm will try to restart this `EnvManager` on an other node.
    The children of this `EnvManager` process are restarted from scratch. That means the Sessions process will be lost.
    The app cannot be started twice.
    If the app is not already started, it returns `{:ok, <PID>}`
    If the app is already started, return `{:error, {:already_started, <PID>}}`
  """
  @spec start_env(number(), number(), String.t()) ::
          {:error, {:already_started, pid()}} | {:ok, pid()}
  def start_env(env_id, build_number, app_name) do
    DynamicSupervisor.start_child(
      EnvManagers,
      {ApplicationRunner.EnvManager,
       [env_id: env_id, build_number: build_number, app_name: app_name]}
    )
  end

  @doc """
    Ensure that the app env process is started. Start the app env if not.
  """
  @spec ensure_env_started(number(), number(), String.t()) :: {:ok, pid}
  def ensure_env_started(env_id, build_number, app_name) do
    case EnvManagers.start_env(env_id, build_number, app_name) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @doc """
    Stop the `EnvManager` with the given `env_id` and return `:ok`.
    If there is no `EnvManager` for the given `env_id`, then return `{:error, :not_started}`
  """
  @spec stop_env(number()) :: :ok | {:error, :app_not_started}
  def stop_env(env_id) do
    with {:ok, pid} <- fetch_env_manager_pid(env_id) do
      # Stop all the session node for the given app and stop the app.
      Swarm.publish({:sessions, env_id}, :stop)
      GenServer.cast(pid, :stop)
    end
  end

  def terminate_app(app_manager_pid) do
    DynamicSupervisor.terminate_child(ApplicationRunner.EnvManagers, app_manager_pid)
  end
end