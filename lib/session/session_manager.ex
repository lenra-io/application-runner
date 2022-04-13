defmodule ApplicationRunner.SessionManager do
  @moduledoc """
    This module is the Session supervisor that handles the SupervisorManager children modules.
  """
  use GenServer

  require Logger

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManager,
    ListenersCache,
    SessionManagers,
    SessionState,
    SessionSupervisor,
    UiCache,
    UiContext,
    WidgetCache,
    WidgetContext
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

  def send_on_user_first_join_event(session_state),
    do: do_send_event(session_state, "onUserFirstJoin", %{}, %{})

  def send_on_user_quit_event(session_state),
    do: do_send_event(session_state, "onUserQuit", %{}, %{})

  def send_on_session_start_event(session_state),
    do: do_send_event(session_state, "onSessionStart", %{}, %{})

  def send_on_session_stop_event(session_state),
    do: do_send_event(session_state, "onSessionStop", %{}, %{})

  @spec fetch_assigns(number()) :: {:ok, any()} | {:error, :session_not_started}
  def fetch_assigns(session_id) do
    with {:ok, pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      GenServer.call(pid, :fetch_assigns)
    end
  end

  @spec set_assigns(number(), any()) :: :ok | {:error, :session_not_started}
  def set_assigns(session_id, assigns) do
    with {:ok, pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      GenServer.cast(pid, {:set_assigns, assigns})
    end
  end

  @spec reload_ui(number()) :: :ok | {:error, :session_not_started}
  def reload_ui(session_id) do
    with {:ok, pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      GenServer.cast(pid, :data_changed)
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

    with :ok <- AdapterHandler.ensure_user_data_created(session_state),
         :ok <- send_on_session_start_event(session_state) do
      {:ok, session_state, session_state.inactivity_timeout}
    else
      {:error, reason} = err ->
        send_error(session_state, err)
        {:stop, reason}
    end
  end

  @impl true

  def handle_info(:timeout, session_state) do
    stop(session_state, nil)
    {:noreply, session_state}
  end

  @impl true
  def handle_call(:get_session_supervisor_pid, _from, session_state) do
    case Map.fetch!(session_state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, session_state, session_state.inactivity_timeout}
    end
  end

  def handle_call(:fetch_assigns, _from, session_state) do
    {:reply, {:ok, session_state.assigns}, session_state}
  end

  def handle_call(:stop, from, session_state) do
    stop(session_state, from)
    {:noreply, session_state}
  end

  @doc """
    This callback is called when the `SessionManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct SessionManagers is called.
  """
  @impl true
  def handle_cast({:send_client_event, code, event}, session_state) do
    with {:ok, listener} <- ListenersCache.fetch_listener(session_state, code),
         {:ok, action} <- Map.fetch(listener, "action"),
         props <- Map.get(listener, "props", %{}),
         :ok <- do_send_event(session_state, action, props, event) do
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  def handle_cast({:send_special_event, action, event}, session_state) do
    case do_send_event(session_state, action, %{}, event) do
      :ok ->
        :ok

      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  def handle_cast(:data_changed, %SessionState{} = session_state) do
    with %{"rootWidget" => root_widget} <- EnvManager.get_manifest(session_state.env_id),
         :ok <- WidgetCache.clear_cache(session_state),
         {:ok, ui} <- get_and_build_ui(session_state, root_widget) do
      transformed_ui = transform_ui(ui)
      res = UiCache.diff_and_save(session_state, transformed_ui)
      AdapterHandler.on_ui_changed(session_state, res)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  def handle_cast({:set_assigns, assigns}, session_state) do
    {:noreply, Map.put(session_state, :assigns, assigns), session_state.inactivity_timeout}
  end

  @spec get_and_build_ui(SessionState.t(), String.t()) ::
          {:ok, map()} | {:error, any()}
  def get_and_build_ui(session_state, root_widget) do
    props = %{}
    query = nil
    data = []
    id = WidgetCache.generate_widget_id(root_widget, query, props)

    WidgetCache.get_and_build_widget(
      session_state,
      %UiContext{
        widgets_map: %{},
        listeners_map: %{}
      },
      %WidgetContext{
        id: id,
        name: root_widget,
        prefix_path: "",
        query: query,
        data: data,
        props: props
      }
    )
    |> case do
      {:ok, ui_context} ->
        {:ok, %{"rootWidget" => id, "widgets" => ui_context.widgets_map}}

      {:error, reason} when is_atom(reason) ->
        {:error, reason}

      {:error, ui_error_list} when is_list(ui_error_list) ->
        {:error, :invalid_ui, ui_error_list}
    end
  end

  defp do_send_event(session_state, action, props, event) do
    AdapterHandler.run_listener(session_state, action, props, event)
  end

  defp send_error(session_state, error) do
    AdapterHandler.on_ui_changed(session_state, {:error, error})
  end

  defp stop(session_state, from) do
    send_on_session_stop_event(session_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
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
