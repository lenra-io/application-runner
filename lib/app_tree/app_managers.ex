defmodule ApplicationRunner.AppManagers do
  @moduledoc """
    This module manage all the applications.
    It can start/stop an `AppManager`, get the `AppManager` process, send a message to all the `AppManager`, etc..
  """
  use DynamicSupervisor

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
    case Swarm.whereis_name(swarm_id(app_id)) do
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
    If the app is already started, return `{:error, {:already_registered, <PID>}}`
  """
  @spec start_app(number()) :: {:error, {:already_registered, pid()}} | {:ok, pid()}
  def start_app(app_id) do
    with {:ok, pid} = res <-
           Swarm.register_name(
             swarm_id(app_id),
             ApplicationRunner.AppManagers,
             :handle_start_app,
             [[app_id: app_id]]
           ) do
      Swarm.join(:apps, pid)
      res
    end
  end

  @doc """
    Stop the `AppManager` with the given `app_id` and return `:ok`.
    If there is no `AppManager` for the given `app_id`, then return `{:error, :not_started}`
  """
  @spec stop_app(number()) :: :ok | {:error, :app_not_started}
  def stop_app(app_id) do
    with {:ok, pid} <- fetch_app_manager_pid(app_id) do
      GenServer.cast(pid, :stop)
    end
  end

  @doc """
  This broadcast the (async) message to all the `AppManager`. Does not wait for a response.
  The message will be handled by `handle_info/2` in the `AppManager`
  """
  @spec broadcast(any()) :: :ok
  def broadcast(message) do
    Swarm.publish(:apps, message)
  end

  @doc """
    This broadcast the sync message to all the `AppManager` and wait for all the responses.
    The message will be handled by `handle_call/2` in the `AppManager`
    Returns te list of responses.
  """
  @spec broadcast_call(term()) :: [term()]
  def broadcast_call(message) do
    Swarm.multi_call(:apps, message)
  end

  defp swarm_id(app_id) do
    {:app, app_id}
  end

  def terminate_app(app_manager_pid) do
    DynamicSupervisor.terminate_child(ApplicationRunner.AppManagers, app_manager_pid)
  end

  # This @doc false ensure that the function will not be in the doc.
  # this function should never be called directly. It is called by swarm to create the process. (see `start_app/1` above)
  @doc false
  @spec handle_start_app(number()) :: {:error, any} | {:ok, pid}
  def handle_start_app(opts) do
    DynamicSupervisor.start_child(
      ApplicationRunner.AppManagers,
      {ApplicationRunner.AppManager, opts}
    )
  end
end
