defmodule ApplicationRunner.Environment.DynamicSupervisor do
  @moduledoc """
    This module manages all the applications.
    It can start/stop an `EnvManager`, get the `EnvManager` process, send a message to all the `EnvManager`, etc..
  """
  use DynamicSupervisor

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Session
  alias LenraCommon.Errors, as: LC

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
    Ask swarm to start the `EnvManager` with the given `env_id` and add it to the :apps group.
    This `EnvManager` process will be started in one of the cluster node.
    If the node is closed, swarm will try to restart this `EnvManager` on an other node.
    The children of this `EnvManager` process are restarted from scratch. That means the Sessions process will be lost.
    The app cannot be started twice.
    If the app is not already started, it returns `{:ok, <PID>}`
    If the app is already started, return `{:error, {:already_started, <PID>}}`
  """
  @spec start_env(term()) ::
          {:error, {:already_started, pid()}} | {:ok, pid()} | {:error, term()}
  def start_env(env_metadata) do
    case DynamicSupervisor.start_child(
           __MODULE__,
           {ApplicationRunner.Environment.Supervisor, env_metadata}
         ) do
      {:error, {:shutdown, {:failed_to_start_child, _module, reason}}} ->
        {:error, reason}

      res ->
        res
    end
  end

  @doc """
    Ensure that the app env process is started. Start the app env if not.
  """

  @spec ensure_env_started(term()) :: {:ok, pid} | {:error, term()}
  def ensure_env_started(env_metadata) do
    case start_env(env_metadata) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
    Stop the `EnvManager` with the given `env_id` and return `:ok`.
    If there is no `EnvManager` for the given `env_id`, then return `{:error, :not_started}`
  """
  @spec stop_env(number()) :: :ok | {:error, LC.BusinessError.t()}
  def stop_env(env_id) do
    name = Environment.Supervisor.get_name(env_id)

    case Swarm.whereis_name(name) do
      :undefined ->
        BusinessError.env_not_started_tuple()

      pid ->
        Supervisor.stop(pid)
    end
  end

  def session_stopped(env_id) do
    Swarm.whereis_name(Session.DynamicSupervisor.get_name(env_id))
    |> DynamicSupervisor.count_children()
    |> case do
      %{supervisors: 0} -> stop_env(env_id)
      _any -> :ok
    end
  end
end
