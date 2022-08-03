defmodule ApplicationRunner.Session.Manager do
  @moduledoc """
    This module is the Session supervisor that handles the SupervisorManager children modules.
  """
  use GenServer

  require Logger

  alias ApplicationRunner.{
    Environments,
    EventHandler,
    JsonStorage,
    ListenersCache,
    Session,
    Ui,
    Widget
  }

  alias ApplicationRunner.Session.{
    Managers,
    Supervisor
  }

  alias ApplicationRunner.Errors.TechnicalError

  @on_user_first_join_action "onUserFirstJoin"
  @on_user_quit_action "onUserQuit"
  @on_session_start_action "onSessionStart"
  @on_session_stop_action "onSessionStop"

  @optional_handler_actions [
    @on_user_first_join_action,
    @on_user_quit_action,
    @on_session_start_action,
    @on_session_stop_action
  ]

  @spec send_client_event(pid(), String.t(), map()) :: :ok
  def send_client_event(session_manager_pid, code, event) do
    GenServer.cast(session_manager_pid, {:send_client_event, code, event})
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

  @spec reload_ui(number()) :: :ok
  def reload_ui(session_id) do
    with {:ok, pid} <- Managers.fetch_session_manager_pid(session_id) do
      send(pid, :data_changed)
    end
  end

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)
    session_state = Keyword.fetch!(opts, :session_state)
    user_id = Map.fetch!(session_state, :user_id)
    function_name = Map.fetch!(session_state, :function_name)
    assigns = Map.fetch!(session_state, :assigns)
    context = Map.get(session_state, :context, %{})

    {:ok, session_supervisor_pid} = Supervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The SessionManager should be restarted by the SessionManagers then it will restart the supervisor.
    Process.link(session_supervisor_pid)

    event_handler_pid = Supervisor.fetch_module_pid!(session_supervisor_pid, EventHandler)
    EventHandler.subscribe(event_handler_pid)

    session_state = %Session.State{
      session_id: session_id,
      user_id: user_id,
      env_id: env_id,
      function_name: function_name,
      session_supervisor_pid: session_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :session_inactivity_timeout, 1000 * 60 * 10),
      assigns: assigns,
      context: context
    }

    first_time_user = JsonStorage.has_user_data?(env_id, user_id)

    with :ok <- create_user_data_if_needed(session_state, first_time_user),
         :ok <- send_on_session_start_event(session_state) do
      {:ok, session_state, session_state.inactivity_timeout}
    else
      {:error, reason} = err ->
        send_error(session_state, err)
        {:stop, reason}
    end
  end

  defp create_user_data_if_needed(
         session_state,
         false
       ) do
    JsonStorage.create_user_data_with_data(session_state.env_id, session_state.user_id)
    send_on_user_first_join_event(session_state)
  end

  defp create_user_data_if_needed(_session_state, true) do
    :ok
  end

  @impl true

  def handle_info(:timeout, session_state) do
    stop(session_state, nil)
    {:noreply, session_state}
  end

  def handle_info({:event_finished, action, result}, session_state) do
    case {action, result} do
      {@on_session_start_action, :ok} ->
        Environments.reload_all_ui(session_state.env_id)
        :ok

      {@on_session_start_action, _} ->
        reload_ui(session_state.session_id)
        :ok

      {_, :ok} ->
        Environments.reload_all_ui(session_state.env_id)
        :ok

      {a, :error404} when a in @optional_handler_actions ->
        :ok

      {a, :error404} when a not in @optional_handler_actions ->
        send_error(session_state, TechnicalError.listener_not_found_tuple())

      {_, err} ->
        send_error(session_state, err)
    end

    {:noreply, session_state}
  end

  def handle_info(:data_changed, %Session.State{} = session_state) do
    with %{"rootWidget" => root_widget} <-
           Environments.get_manifest(session_state.env_id),
         {:ok, ui} <- get_and_build_ui(session_state, root_widget) do
      transformed_ui = transform_ui(ui)
      res = Ui.Cache.diff_and_save(session_state, transformed_ui)
      send_res(session_state, res)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  defp send_res(
         %Session.State{
           assigns: %{
             socket_pid: socket_pid
           }
         },
         {atom, ui_or_patches}
       ) do
    send(socket_pid, {:send, atom, ui_or_patches})
  end

  @impl true
  def handle_call(:fetch_session_supervisor_pid!, _from, session_state) do
    case Map.fetch!(session_state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, session_state, session_state.inactivity_timeout}
    end
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
         props <- Map.get(listener, "props", %{}) do
      do_send_event(session_state, action, props, event)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  @spec get_and_build_ui(Session.State.t(), String.t()) ::
          {:ok, map()} | {:error, any()}
  def get_and_build_ui(session_state, root_widget) do
    props = %{}
    query = nil
    data = []
    context = %{}
    id = Widget.Cache.generate_widget_id(root_widget, query, props, context)

    Widget.Cache.get_and_build_widget(
      session_state,
      %Ui.Context{
        widgets_map: %{},
        listeners_map: %{}
      },
      %Widget.Context{
        context: context,
        id: id,
        name: root_widget,
        prefix_path: "",
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

  defp send_on_user_first_join_event(session_state),
    do: do_send_event(session_state, @on_user_first_join_action, %{}, %{})

  defp send_on_user_quit_event(session_state),
    do: do_send_event(session_state, @on_user_quit_action, %{}, %{})

  defp send_on_session_start_event(session_state),
    do: do_send_event(session_state, @on_session_start_action, %{}, %{})

  defp send_on_session_stop_event(session_state),
    do: do_send_event(session_state, @on_session_stop_action, %{}, %{})

  defp do_send_event(session_state, action, props, event) do
    event_handler_pid =
      Supervisor.fetch_module_pid!(session_state.session_supervisor_pid, EventHandler)

    EventHandler.send_event(event_handler_pid, session_state, action, props, event)
  end

  defp send_error(
         %Session.State{
           assigns: %{
             socket_pid: socket_pid
           }
         },
         error
       ) do
    send(socket_pid, {:send, :error, error})
  end

  defp stop(session_state, from) do
    send_on_session_stop_event(session_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
    Managers.terminate_session(self())
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
