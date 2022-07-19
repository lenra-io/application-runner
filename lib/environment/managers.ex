defmodule ApplicationRunner.Environments.Managers do
  @moduledoc """
    This module manages all the applications.
    It can start/stop an `EnvManager`, get the `EnvManager` process, send a message to all the `EnvManager`, etc..
  """
  use DynamicSupervisor

  alias ApplicationRunner.Environments.Managers
  alias ApplicationRunner.Errors.BusinessError

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
  @spec fetch_env_manager_pid(number()) :: BusinessError.env_not_started_tuple() | {:ok, pid()}
  def fetch_env_manager_pid(env_id) do
    case Swarm.whereis_name({:env, env_id}) do
      :undefined -> BusinessError.env_not_started_tuple()
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
  @spec start_env(number(), term()) ::
          {:error, {:already_started, pid()}} | {:ok, pid()} | {:error, atom | bitstring}
  def start_env(env_id, env_state) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {ApplicationRunner.Environments.Manager, [env_id: env_id, env_state: env_state]}
    )
  end

  @doc """
    Ensure that the app env process is started. Start the app env if not.
  """
  @spec ensure_env_started(number(), term()) :: {:ok, pid} | {:error, atom | bitstring}
  def ensure_env_started(env_id, env_state) do
    case Managers.start_env(env_id, env_state) do
      {:ok, pid} -> {:ok, pid}
      {:error, message} when is_atom(message) or is_bitstring(message) -> {:error, message}
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
      GenServer.call(pid, :stop)
    end
  end

  def terminate_app(app_manager_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, app_manager_pid)
  end
end
