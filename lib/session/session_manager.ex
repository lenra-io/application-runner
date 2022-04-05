defmodule ApplicationRunner.SessionManager do
  @moduledoc """
    This module is the Session supervisor that handles the SupervisorManager children modules.
  """
  use GenServer

  require Logger

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManager,
    SessionManagers,
    SessionState,
    SessionSupervisor,
    UiCache
  }

  @doc """
    return the app-level module.
    This can be used to get module declared in the `SessionSupervisor` (like the cache module for example)
  """
  @spec fetch_module_pid!(SessionState.t(), atom()) :: pid()
  def fetch_module_pid!(
        %SessionState{session_supervisor_pid: session_supervisor_pid},
        module_name
      ) do
    Supervisor.which_children(session_supervisor_pid)
    |> Enum.find({:error, :no_such_module}, fn
      {name, _, _, _} -> module_name == name
    end)
    |> case do
      {_, pid, _, _} ->
        pid

      {:error, :no_such_module} ->
        raise "No such Module in SessionSupervisor. This should not happen."
    end
  end

  def run_listener(session_manager_pid, code, event) do
    GenServer.cast(session_manager_pid, {:run_listener, code, event})
  end

  def init_data(session_manager_pid) do
    GenServer.cast(session_manager_pid, :init_data)
  end

  def get_assigns(session_manager_pid) do
    GenServer.cast(session_manager_pid, :get_assigns)
  end

  def set_assigns(session_manager_pid, assigns) do
    GenServer.cast(session_manager_pid, {:set_assigns, assigns})
  end

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)

    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, {:session, session_id}}) do
      Swarm.join(:sessions, pid)
      Swarm.join({:sessions, env_id}, pid)
      {:ok, pid}
    end
  end

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)
    assigns = Keyword.fetch!(opts, :assigns)

    {:ok, session_supervisor_pid} = SessionSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The SessionManager should be restarted by the SessionManagers then it will restart the supervisor.
    Process.link(session_supervisor_pid)

    session_state = %SessionState{
      session_id: session_id,
      env_id: env_id,
      session_supervisor_pid: session_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :session_inactivity_timeout, 1000 * 60 * 10),
      assigns: assigns
    }

    ensure_user_data_created(session_state)

    {:ok, session_state, session_state.inactivity_timeout}
  end

  defp ensure_user_data_created(session_state) do
    # TODO: change this to get and save in Datastore "UserDatas" when request available
    if AdapterHandler.get_data(session_state) == {:ok, nil} do
      AdapterHandler.save_data(session_state, %{})
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    SessionManagers.terminate_session(self())
    {:noreply, state}
  end

  @impl true
  def handle_info(:data_changed, %SessionState{} = session_state) do
    with %{"rootWidget" => root_widget} <- EnvManager.get_manifest(session_state.env_id),
         {:ok, data} <- AdapterHandler.get_data(session_state),
         {:ok, ui} <- EnvManager.get_and_build_ui(session_state, root_widget, data) do
      transformed_ui = transform_ui(ui)
      res = UiCache.diff_and_save(session_state, transformed_ui)
      AdapterHandler.on_ui_changed(session_state, res)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  @impl true
  def handle_call(:get_session_supervisor_pid, _from, session_state) do
    case Map.fetch!(session_state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, session_state, session_state.inactivity_timeout}
    end
  end

  @doc """
    This callback is called when the `SessionManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct SessionManagers is called.
  """
  @impl true
  def handle_cast(:stop, state) do
    SessionManagers.terminate_session(self())
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_assigns, assigns}, session_state) do
    assigns = [assigns | session_state.assigns]
    {:noreply, Map.replace(session_state, :assigns, assigns)}
  end

  @impl true
  def handle_cast({:run_listener, code, event}, session_state) do
    with {:ok, data} <- AdapterHandler.get_data(session_state),
         {:ok, new_data} <-
           EnvManager.run_listener(session_state, code, data, event),
         :ok <- AdapterHandler.save_data(session_state, new_data) do
      EnvManager.notify_data_changed(session_state)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  @impl true
  def handle_cast(:init_data, session_state) do
    with {:ok, data} <- AdapterHandler.get_data(session_state),
         {:ok, new_data} <- EnvManager.init_data(session_state, data),
         :ok <- AdapterHandler.save_data(session_state, new_data) do
      EnvManager.notify_data_changed(session_state)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  @impl true
  def handle_cast(:get_assigns, session_state) do
    session_state.assigns
  end

  defp send_error(session_state, error) do
    AdapterHandler.on_ui_changed(session_state, {:error, error})
  end

  defp transform_ui(%{"rootWidget" => root_widget, "widgets" => widgets}) do
    transform(%{"root" => Map.fetch!(widgets, root_widget)}, widgets)
  end

  defp transform(%{"type" => "widget", "id" => id}, widgets) do
    transform(Map.fetch!(widgets, id), widgets)
  end

  defp transform(widget, widgets) when is_map(widget) do
    Enum.map(widget, fn
      {k, v} -> {k, transform(v, widgets)}
    end)
    |> Map.new()
  end

  defp transform(widget, widgets) when is_list(widget) do
    Enum.map(widget, &transform(&1, widgets))
  end

  defp transform(widget, _widgets) do
    widget
  end
end
