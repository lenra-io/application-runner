defmodule ApplicationRunner.SessionManager do
  @moduledoc """
    This module is the Session supervisor that handles the SupervisorManager children modules.
  """
  use GenServer

  require Logger

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManager,
    EventHandler,
    SessionManagers,
    SessionState,
    SessionSupervisor,
    UiCache,
    UiContext,
    WidgetCache,
    WidgetContext,
    LenraView,
    JsonView
  }

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

  @spec listener_call(pid(), map()) :: :ok
  def listener_call(session_manager_pid, listener_call) do
    GenServer.cast(session_manager_pid, {:listener_call, listener_call})
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
    with {:ok, pid} <- SessionManagers.fetch_session_manager_pid(session_id) do
      send(pid, :data_changed)
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

    event_handler_pid = SessionSupervisor.fetch_module_pid!(session_supervisor_pid, EventHandler)
    EventHandler.subscribe(event_handler_pid)

    session_state = %SessionState{
      session_id: session_id,
      env_id: env_id,
      session_supervisor_pid: session_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :session_inactivity_timeout, 1000 * 60 * 10),
      assigns: assigns
    }

    first_time_user = AdapterHandler.first_time_user?(session_state)

    with :ok <- EnvManager.wait_until_ready(env_id),
         :ok <- create_user_data_if_needed(session_state, first_time_user),
         :ok <- send_on_session_start_event(session_state) do
      {:ok, session_state, session_state.inactivity_timeout}
    else
      {:error, reason} = err ->
        send_error(session_state, err)
        {:stop, reason}
    end
  end

  defp create_user_data_if_needed(session_state, true) do
    AdapterHandler.create_user_data(session_state)
    send_on_user_first_join_event(session_state)
  end

  defp create_user_data_if_needed(_session_state, false) do
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
        EnvManager.reload_all_ui(session_state.env_id)
        :ok

      {@on_session_start_action, _} ->
        reload_ui(session_state.session_id)
        :ok

      {_, :ok} ->
        EnvManager.reload_all_ui(session_state.env_id)
        :ok

      {a, :error404} when a in @optional_handler_actions ->
        :ok

      {a, :error404} when a not in @optional_handler_actions ->
        send_error(session_state, {:error, :listener_not_found})

      {_, err} ->
        send_error(session_state, err)
    end

    {:noreply, session_state}
  end

  def handle_info(:data_changed, %SessionState{} = session_state) do
    with manifest <- EnvManager.get_manifest(session_state.env_id),
         {:ok, ui} <- call_ui_view(session_state, manifest) do
      res = UiCache.diff_and_save(session_state, ui)
      AdapterHandler.on_ui_changed(session_state, res)
    else
      error ->
        send_error(session_state, error)
    end

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  defp call_ui_view(session_state, %{"rootWidget" => rootWidget, "view" => "json"}) do
    JsonView.get_and_build_ui(session_state, rootWidget)
  end

  defp call_ui_view(session_state, %{"rootWidget" => rootWidget}) do
    LenraView.get_and_build_ui(session_state, rootWidget)
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
  def handle_cast({:listener_call, listener_call}, session_state) do
    do_send_event(session_state, listener_call)

    {:noreply, session_state, session_state.inactivity_timeout}
  end

  defp send_on_user_first_join_event(session_state),
    do:
      do_send_event(session_state, %{
        "action" => @on_user_first_join_action,
        "props" => %{},
        "event" => %{}
      })

  defp send_on_user_quit_event(session_state),
    do:
      do_send_event(session_state, %{
        "action" => @on_user_quit_action,
        "props" => %{},
        "event" => %{}
      })

  defp send_on_session_start_event(session_state),
    do:
      do_send_event(session_state, %{
        "action" => @on_session_start_action,
        "props" => %{},
        "event" => %{}
      })

  defp send_on_session_stop_event(session_state),
    do:
      do_send_event(session_state, %{
        "action" => @on_session_stop_action,
        "props" => %{},
        "event" => %{}
      })

  defp do_send_event(session_state, listener_call) do
    event_handler_pid =
      SessionSupervisor.fetch_module_pid!(session_state.session_supervisor_pid, EventHandler)

    EventHandler.send_event(event_handler_pid, session_state, listener_call)
  end

  defp send_error(session_state, error) do
    AdapterHandler.on_ui_changed(session_state, {:error, error})
  end

  defp stop(session_state, from) do
    send_on_session_stop_event(session_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
    SessionManagers.terminate_session(self())
  end
end
