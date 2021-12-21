defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handle one application. This module is the entrypoint to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    EnvManagers,
    EnvSupervisor,
    EnvState,
    AdapterHandler,
    UiContext,
    WidgetContext,
    WidgetCache
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
    build_number = Keyword.fetch!(opts, :build_number)
    app_name = Keyword.fetch!(opts, :app_name)

    {:ok, env_supervisor_pid} = EnvSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The EnvManager should be restarted by the EnvManagers then it will restart the supervisor.
    Process.link(env_supervisor_pid)

    env_state = %EnvState{
      env_id: env_id,
      app_name: app_name,
      build_number: build_number,
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

  @spec fetch_module_pid(EnvState.t(), String.t()) :: {:ok, any}
  @doc """
    return the app-level module.
    This can be used to get module declared in the `EnvSupervisor` (like the cache module for example)
  """
  def fetch_module_pid(%EnvState{} = env_state, module_name) do
    Supervisor.which_children(env_state.env_supervisor_pid)
    |> Enum.find({:error, :no_such_module}, fn
      {name, _, _, _} -> module_name == name
    end)
    |> case do
      {_, pid, _, _} ->
        {:ok, pid}

      {:error, :no_such_module} ->
        raise "No such Module in EnvSupervisor. This should not happen."
    end
  end

  def fetch_supervisor_pid(env_manager_pid) when is_pid(env_manager_pid) do
    {:ok, GenServer.call(env_manager_pid, :get_env_supervisor_pid)}
  end

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

  def notify_data_changed(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.cast(pid, :notify_data_changed)
    end
  end

  @impl true
  def handle_call({:get_and_build_ui, entrypoint, data}, _from, env_state) do
    id = WidgetCache.generate_widget_id(entrypoint, data, %{})

    {:ok, ui_context} =
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

    res = {:ok, %{"entrypoint" => id, "widgets" => ui_context.widgets_map}}

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
  def handle_cast(:stop, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end

  @impl true
  def handle_cast(:notify_data_changed, %EnvState{} = env_state) do
    Swarm.publish({:sessions, env_state.env_id}, :data_changed)
    {:noreply, env_state, @inactivity_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end
end