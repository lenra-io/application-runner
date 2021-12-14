defmodule ApplicationRunner.AppManagers do
  @moduledoc """
    This module manage all the applications.
    It can start/stop an `AppManager`, get the `AppManager` process, send a message to all the `AppManager`, etc..
  """
  use DynamicSupervisor

  alias ApplicationRunner.{AppManagers}

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
    Fetch the `AppManager` pid corresponding to the `app_id`.
  """
  @spec fetch_app_manager_pid(number()) :: {:error, :app_not_started} | {:ok, pid()}
  def fetch_app_manager_pid(app_id) do
    case Swarm.whereis_name({:app, app_id}) do
      :undefined -> {:error, :app_not_started}
      pid -> {:ok, pid}
    end
  end

  @doc """
    Ask swarm to start the `AppManager` with the given `app_id` and add it to the :apps group.
    This `AppManager` process will be started in one of the cluster node.
    If the node is closed, swarm will try to restart this `AppManager` on an other node.
    The children of this `AppManager` process are restarted from scratch. That means the Sessions process will be lost.
    The app cannot be started twice.
    If the app is not already started, it returns `{:ok, <PID>}`
    If the app is already started, return `{:error, {:already_started, <PID>}}`
  """
  @spec start_app(number()) :: {:error, {:already_started, pid()}} | {:ok, pid()}
  def start_app(app_id) do
    DynamicSupervisor.start_child(
      AppManagers,
      {ApplicationRunner.AppManager, [app_id: app_id]}
    )
  end

  @doc """
    Ensure that the app process is started. Start the app if not.
  """
  @spec ensure_app_started(number()) :: {:ok, pid}
  def ensure_app_started(app_id) do
    case AppManagers.start_app(app_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @doc """
    Stop the `AppManager` with the given `app_id` and return `:ok`.
    If there is no `AppManager` for the given `app_id`, then return `{:error, :not_started}`
  """
  @spec stop_app(number()) :: :ok | {:error, :app_not_started}
  def stop_app(app_id) do
    with {:ok, pid} <- fetch_app_manager_pid(app_id) do
      # Stop all the session node for the given app and stop the app.
      Swarm.publish({:sessions, app_id}, :stop)
      GenServer.cast(pid, :stop)
    end
  end

  def terminate_app(app_manager_pid) do
    DynamicSupervisor.terminate_child(ApplicationRunner.AppManagers, app_manager_pid)
  end
end
