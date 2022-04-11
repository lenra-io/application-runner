defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handles one application. This module is the root_widget to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManagers,
    EnvState,
    EnvSupervisor,
    ListenersCache,
    UiContext,
    WidgetCache,
    WidgetContext
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

  def get_and_build_ui(session_state, root_widget, data) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:get_and_build_ui, root_widget, data})
    end
  end

  def send_special_event(session_state, action, event) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:send_special_event, action, event})
    end
  end

  def fetch_listener(session_state, code) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(session_state.env_id) do
      GenServer.call(pid, {:fetch_listener, code})
    end
  end

  @impl true
  def handle_call({:get_and_build_ui, root_widget, data}, _from, env_state) do
    id = WidgetCache.generate_widget_id(root_widget, data, %{})

    WidgetCache.get_and_build_widget(
      env_state,
      %UiContext{
        widgets_map: %{},
        listeners_map: %{}
      },
      %WidgetContext{
        id: id,
        name: root_widget,
        prefix_path: "",
        data: data
      }
    )
    |> case do
      {:ok, ui_context} ->
        res = {:ok, %{"rootWidget" => id, "widgets" => ui_context.widgets_map}}
        {:reply, res, env_state, env_state.inactivity_timeout}

      {:error, reason} when is_atom(reason) ->
        {:reply, {:error, reason}, env_state, env_state.inactivity_timeout}

      {:error, ui_error_list} when is_list(ui_error_list) ->
        {:reply, {:error, :invalid_ui, ui_error_list}, env_state, env_state.inactivity_timeout}
    end
  end

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

  def handle_call({:fetch_listener, code}, _from, env_state) do
    ListenersCache.fetch_listener(env_state, code)
  end

  @impl true
  def handle_cast({:send_special_event, action, event}, env_state) do
    AdapterHandler.run_listener(env_state, action, %{}, event)
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

  @impl true
  def handle_info(:timeout, state) do
    EnvManagers.terminate_app(self())
    {:noreply, state}
  end
end
