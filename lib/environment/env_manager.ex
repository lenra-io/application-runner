defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handles one application. This module is the root_widget to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManagers,
    EnvState,
    EnvSupervisor
  }

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)

    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, {:env, env_id}}) do
      Swarm.join(:envs, pid)
      {:ok, pid}
    end
  end

  @impl true
  def init(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    assigns = Keyword.fetch!(opts, :assigns)

    {:ok, env_supervisor_pid} = EnvSupervisor.start_link(nil)
    # Link the process to kill the manager if the supervisor is killed.
    # The EnvManager should be restarted by the EnvManagers then it will restart the supervisor.
    Process.link(env_supervisor_pid)

    env_state = %EnvState{
      env_id: env_id,
      assigns: assigns,
      env_supervisor_pid: env_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60)
    }

    case AdapterHandler.get_manifest(env_state) do
      {:ok, manifest} ->
        {
          :ok,
          Map.put(env_state, :manifest, manifest),
          env_state.inactivity_timeout
        }

      {:error, reason} ->
        {:stop, reason}
    end
  end

  #  defdelegate load_env_state(env_id),
  #    to: Application.compile_env!(:application_runner, :app_loader)

  @doc """
    return the app-level module.
    This can be used to get module declared in the `EnvSupervisor` (like the cache module for example)
  """
  @spec fetch_module_pid!(EnvState.t(), atom()) :: pid()
  def fetch_module_pid!(%EnvState{} = env_state, module_name) do
    Supervisor.which_children(env_state.env_supervisor_pid)
    |> Enum.find({:error, :no_such_module}, fn
      {name, _, _, _} -> module_name == name
    end)
    |> case do
      {_, pid, _, _} ->
        pid

      {:error, :no_such_module} ->
        raise "No such Module in EnvSupervisor. This should not happen."
    end
  end

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :get_manifest)
    end
  end

  @spec fetch_assigns(number()) :: {:ok, any()} | {:error, :env_not_started}
  def fetch_assigns(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :fetch_assigns)
    end
  end

  @spec(set_assigns(number(), term()) :: :ok, {:error, :env_not_started})
  def set_assigns(env_id, assigns) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.cast(pid, {:set_assigns, assigns})
    end
  end

  def send_on_env_start_event(env_id), do: send_special_event(env_id, "onEnvStart", %{})
  def send_on_env_stop_event(env_id), do: send_special_event(env_id, "onEnvStop", %{})

  defp send_special_event(env_id, action, event) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.cast(pid, {:send_special_event, action, event})
    end
  end

  @impl true
  def handle_call(:get_manifest, _from, env_state) do
    {:reply, Map.get(env_state, :manifest), env_state, env_state.inactivity_timeout}
  end

  def handle_call(:get_env_supervisor_pid, _from, env_state) do
    case Map.get(env_state, :env_supervisor_pid) do
      nil -> raise "No EnvSupervisor. This should not happen."
      res -> {:reply, res, env_state, env_state.inactivity_timeout}
    end
  end

  @doc """
    This callback is called when swarm wants to restart the process in an other node.
    This is NOT called when the node is killed.
  """
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    {:reply, :restart, state}
  end

  def handle_call(:fetch_assigns, _from, env_state) do
    {:reply, {:ok, env_state.assigns}, env_state}
  end

  @impl true
  def handle_cast({:send_special_event, action, event}, env_state) do
    spawn(fn ->
      AdapterHandler.run_listener(env_state, action, %{}, event)
    end)

    {:noreply, env_state, env_state.inactivity_timeout}
  end

  @doc """
    This callback is called when the `EnvManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct EnvManager is called.
  """
  def handle_cast(:stop, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end

  def handle_cast({:set_assigns, assigns}, env_state) do
    {:noreply, Map.put(env_state, :assigns, assigns)}
  end

  @impl true
  def handle_info(:timeout, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end
end
