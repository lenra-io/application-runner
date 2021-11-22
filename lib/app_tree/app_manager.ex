defmodule ApplicationRunner.AppManager do
  @moduledoc """
    This module handle one application. This module is the entrypoint to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{AppManagers, AppSupervisor}

  @inactivity_timeout Application.fetch_env!(:application_runner, :app_inactivity_timeout)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    app_id = Keyword.fetch!(opts, :app_id)
    {:ok, app_supervisor_pid} = AppSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The AppManager should be restarted by the AppManagers then it will restart the supervisor.
    Process.link(app_supervisor_pid)

    {
      :ok,
      [app_supervisor_pid: app_supervisor_pid, app_state: load_app_state(app_id)],
      @inactivity_timeout
    }
  end

  defdelegate load_app_state(app_id), to: Application.fetch_env!(:application_runner, :app_loader)

  @doc """
    return the app-level module.
    This can be used to get module declared in the `AppSupervisor` (like the cache module for example)
  """
  def fetch_module_pid(app_manager_pid, module_name) when is_pid(app_manager_pid) do
    with {:ok, pid} <- fetch_supervisor_pid(app_manager_pid) do
      Supervisor.which_children(pid)
      |> Enum.find({:error, :no_such_module}, fn
        {name, _, _, _} -> module_name == name
      end)
      |> case do
        {_, pid, _, _} -> {:ok, pid}
        :no_such_module -> raise "No such Module in AppSupervisor. This should not happen."
      end
    end
  end

  def fetch_supervisor_pid(app_manager_pid) when is_pid(app_manager_pid) do
    {:ok, GenServer.call(app_manager_pid, :get_app_supervisor_pid)}
  end

  @impl true
  def handle_call(:get_app_supervisor_pid, _from, state) do
    case Keyword.get(state, :app_supervisor_pid) do
      nil -> raise "No AppSupervisor. This should not happen."
      res -> {:reply, res, state, @inactivity_timeout}
    end
  end

  @doc """
    This callback is called when swarm wants to restart the process in an other node.
    This is NOT called when the node is killed.
  """
  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    {:reply, :restart, state}
  end

  @doc """
    This callback is called when the `AppManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct AppManager is called.
  """
  @impl true
  def handle_cast(:stop, state) do
    AppManagers.terminate_app(self())
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    AppManagers.terminate_app(self())
    {:noreply, state}
  end
end
