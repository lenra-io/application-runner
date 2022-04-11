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

  @spec send_client_event(pid(), String.t(), map()) :: :ok
  def send_client_event(session_manager_pid, code, event) do
    GenServer.cast(session_manager_pid, {:send_client_event, code, event})
  end

  def send_on_user_first_join_event(session_id),
    do: send_special_event(session_id, "onUserFirstJoin", %{})

  def send_on_user_quit_event(session_id),
    do: send_special_event(session_id, "onUserQuit", %{})

  def send_on_session_start_event(session_id),
    do: send_special_event(session_id, "onSessionStart", %{})

  def send_on_session_end_event(session_state),
    do: send_event(session_state, "onSessionEnd", %{}, %{})

  defp send_special_event(session_id, action, event) do
    with {:ok, session_manager_pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      GenServer.cast(session_manager_pid, {:send_special_event, action, event})
    end
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

    send_on_session_start_event(session_id)

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
  def handle_info(:timeout, session_state) do
    stop(session_state)
    {:noreply, session_state}
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
  def handle_cast(:stop, session_state) do
    stop(session_state)
    {:noreply, session_state}
  end

  def handle_cast({:send_client_event, code, event}, session_state) do
    with {:ok, listener} <- EnvManager.fetch_listener(session_state, code),
         {:ok, action} <- Map.fetch(listener, "action"),
         props <- Map.get(listener, "props", %{}) do
      send_event(session_state, action, props, event)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  def handle_cast({:send_special_event, action, event}, session_state) do
    send_event(session_state, action, %{}, event)
    {:noreply, session_state, session_state.inactivity_timeout}
  end

  def handle_cast(:data_changed, %SessionState{} = session_state) do
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

  defp send_event(session_state, action, props, event) do
    case AdapterHandler.run_listener(session_state, action, props, event) do
      :ok -> :ok
      err -> send_error(session_state, err)
    end
  end

  defp send_error(session_state, error) do
    AdapterHandler.on_ui_changed(session_state, {:error, error})
  end

  defp stop(session_state) do
    send_on_session_end_event(session_state)
    SessionManagers.terminate_session(self())
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
