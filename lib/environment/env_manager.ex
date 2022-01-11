defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handle one application. This module is the entrypoint to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManagers,
    EnvState,
    EnvSupervisor,
    ListenersCache,
    SessionManagers,
    UiContext,
    WidgetCache,
    WidgetContext
  }

  @inactivity_timeout Application.compile_env!(:application_runner, :app_inactivity_timeout)

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

    {:ok, env_supervisor_pid} = EnvSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The EnvManager should be restarted by the EnvManagers then it will restart the supervisor.
    Process.link(env_supervisor_pid)

    env_state = %EnvState{
      env_id: env_id,
      assigns: assigns,
      env_supervisor_pid: env_supervisor_pid
    }

    {:ok, manifest} = AdapterHandler.get_manifest(env_state)

    {
      :ok,
      Map.put(env_state, :manifest, manifest),
      @inactivity_timeout
    }
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

  def get_and_build_ui(session_state, entrypoint, data) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:get_and_build_ui, entrypoint, data})
    end
  end

  def run_listener(session_state, code, data, event) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:run_listener, code, data, event})
    end
  end

  def init_data(session_state, data) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:init_data, data})
    end
  end

  def notify_data_changed(session_state) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.cast(pid, {:notify_data_changed, session_state.session_id})
    end
  end

  @impl true
  def handle_call({:get_and_build_ui, entrypoint, data}, _from, env_state) do
    id = WidgetCache.generate_widget_id(entrypoint, data, %{})

    WidgetCache.get_and_build_widget(
      env_state,
      %UiContext{
        widgets_map: %{},
        listeners_map: %{}
      },
      %WidgetContext{
        id: id,
        name: entrypoint,
        prefix_path: "",
        data: data
      }
    )
    |> case do
      {:ok, ui_context} ->
        res = {:ok, %{"entrypoint" => id, "widgets" => ui_context.widgets_map}}
        {:reply, res, env_state, @inactivity_timeout}

      error_res ->
        {:reply, error_res, env_state, @inactivity_timeout}
    end
  end

  @impl true
  def handle_call({:get_listener, code}, _from, env_state) do
    res = ListenersCache.get_listener(env_state, code)
    {:reply, res, env_state, @inactivity_timeout}
  end

  @impl true
  def handle_call({:run_listener, code, data, event}, _from, env_state) do
    listener = ListenersCache.get_listener(env_state, code)
    action = Map.fetch!(listener, "action")
    props = Map.get(listener, "props", %{})
    res = AdapterHandler.run_listener(env_state, action, data, props, event)

    {:reply, res, env_state, @inactivity_timeout}
  end

  @impl true
  def handle_call({:init_data, data}, _from, env_state) do
    res = AdapterHandler.run_listener(env_state, "InitData", data, %{}, %{})
    {:reply, res, env_state, @inactivity_timeout}
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, Map.get(state, :manifest), state, @inactivity_timeout}
  end

  @impl true
  def handle_call(:get_env_supervisor_pid, _from, state) do
    case Map.get(state, :env_supervisor_pid) do
      nil -> raise "No EnvSupervisor. This should not happen."
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
    This callback is called when the `EnvManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct EnvManager is called.
  """

  @impl true
  def handle_cast({:notify_data_changed, session_id}, %EnvState{} = env_state) do
    with {:ok, pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      send(pid, :data_changed)
    end

    {:noreply, env_state, @inactivity_timeout}
  end

  @impl true
  def handle_cast(:stop, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end
end
